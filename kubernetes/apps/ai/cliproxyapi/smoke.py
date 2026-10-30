#!/usr/bin/env python3
"""Check the gateway contracts used by OpenClaw and Hermes with synthetic prompts."""

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.request


MODELS = ("chatgpt/gpt-5.6-luna", "chatgpt/gpt-5.6-terra")
MARKER = "TRIAL_OK"
FUNCTION = {
    "name": "emit_status",
    "description": "Report the requested status marker.",
    "parameters": {
        "type": "object",
        "properties": {"marker": {"type": "string"}},
        "required": ["marker"],
        "additionalProperties": False,
    },
}


def request(base, key, path, body=None):
    headers = {"Content-Type": "application/json"}
    if key:
        headers["Authorization"] = "Bearer " + key
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(base + path, data=data, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=180) as response:
            if body and body.get("stream"):
                events = []
                for line in response:
                    line = line.decode().strip()
                    if line.startswith("data:"):
                        payload = line[5:].strip()
                        if payload and payload != "[DONE]":
                            event = json.loads(payload)
                            assert "error" not in event, "stream returned an error"
                            assert event.get("type") != "response.failed", "response failed"
                            events.append(event)
                assert events, "empty stream"
                return events
            return json.load(response)
    except urllib.error.HTTPError as error:
        # Do not print response bodies: a gateway can include credentials in errors.
        raise RuntimeError(f"{path}: HTTP {error.code}") from None


def response_items(result, streaming):
    if not streaming:
        assert result.get("status") == "completed", "incomplete response"
        return result.get("output", [])
    completed = [e for e in result if e.get("type") == "response.completed"]
    assert completed, "stream has no response.completed event"
    output = completed[-1].get("response", {}).get("output", [])
    return output or [e["item"] for e in result if e.get("type") == "response.output_item.done"]


def run_case(base, key, model, api, streaming, tools):
    prompt = (
        f"Call emit_status with marker {MARKER}. After receiving its result, reply with exactly {MARKER}."
        if tools
        else f"Reply with exactly {MARKER}."
    )
    body = {"model": model, "stream": streaming}
    if api == "chat/completions":
        body["messages"] = [{"role": "user", "content": prompt}]
        if tools:
            body["tools"] = [{"type": "function", "function": FUNCTION}]
            body["tool_choice"] = {"type": "function", "function": {"name": FUNCTION["name"]}}
    else:
        body["input"] = [{"role": "user", "content": [{"type": "input_text", "text": prompt}]}]
        if tools:
            body["tools"] = [{"type": "function", **FUNCTION}]
            body["tool_choice"] = {"type": "function", "name": FUNCTION["name"]}

    result = request(base, key, "/" + api, body)
    if api == "responses":
        items = response_items(result, streaming)
        if not tools:
            text = "".join(c.get("text", "") for i in items for c in i.get("content", []))
            assert MARKER in text, "response text missing"
            return
        calls = [i for i in items if i.get("type") == "function_call"]
        assert len(calls) == 1, "expected one function call"
        call = calls[0]
        assert call["name"] == FUNCTION["name"], "wrong function"
        assert json.loads(call["arguments"]) == {"marker": MARKER}, "wrong arguments"
        body["input"] += items + [{"type": "function_call_output", "call_id": call["call_id"], "output": MARKER}]
    else:
        if streaming:
            choices = [c for e in result for c in e.get("choices", [])]
            assert any(c.get("finish_reason") for c in choices), "stream has no finish reason"
            text = "".join(c.get("delta", {}).get("content") or "" for c in choices)
            calls_by_index = {}
            for choice in choices:
                for delta in choice.get("delta", {}).get("tool_calls", []):
                    call = calls_by_index.setdefault(delta["index"], {"id": "", "type": "function", "function": {"name": "", "arguments": ""}})
                    if delta.get("id"):
                        call["id"] = delta["id"]
                    for field in ("name", "arguments"):
                        call["function"][field] += delta.get("function", {}).get(field) or ""
            calls = list(calls_by_index.values())
        else:
            message = result["choices"][0]["message"]
            text = message.get("content") or ""
            calls = message.get("tool_calls", [])
        if not tools:
            assert MARKER in text, "chat text missing"
            return
        assert len(calls) == 1, "expected one tool call"
        call = calls[0]
        assert call["function"]["name"] == FUNCTION["name"], "wrong function"
        assert json.loads(call["function"]["arguments"]) == {"marker": MARKER}, "wrong arguments"
        body["messages"] += [
            {"role": "assistant", "content": None, "tool_calls": calls},
            {"role": "tool", "tool_call_id": call["id"], "content": MARKER},
        ]

    body.pop("tool_choice")
    body["stream"] = False
    followup = request(base, key, "/" + api, body)
    if api == "responses":
        text = "".join(c.get("text", "") for i in response_items(followup, False) for c in i.get("content", []))
    else:
        text = followup["choices"][0]["message"].get("content") or ""
    assert MARKER in text, "tool round trip produced no final answer"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--base-url", default="http://127.0.0.1:18317/v1")
    args = parser.parse_args()
    base = args.base_url.rstrip("/")
    key = os.environ.get("CLIPROXY_API_KEY")
    if not key:
        parser.error("set CLIPROXY_API_KEY")
    try:
        request(base, "", "/models")
    except RuntimeError as error:
        assert "HTTP 401" in str(error), "unexpected unauthenticated response"
    else:
        raise AssertionError("unauthenticated access was accepted")
    print("PASS authentication", flush=True)
    available = {m["id"] for m in request(base, key, "/models")["data"]}
    assert set(MODELS) <= available, "configured model aliases missing"
    print("PASS model aliases", flush=True)
    failures = 0
    for model in MODELS:
        for api in ("responses", "chat/completions"):
            for streaming in (False, True):
                for tools in (False, True):
                    label = f"{model} {api} stream={streaming} tools={tools}"
                    started = time.monotonic()
                    try:
                        run_case(base, key, model, api, streaming, tools)
                        print(f"PASS {label} ({time.monotonic() - started:.1f}s)", flush=True)
                    except (AssertionError, RuntimeError, OSError, ValueError, KeyError, IndexError) as error:
                        failures += 1
                        print(f"FAIL {label}: {error}", flush=True)
    return int(failures > 0)


if __name__ == "__main__":
    sys.exit(main())
