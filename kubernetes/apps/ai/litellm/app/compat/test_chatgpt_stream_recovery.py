"""Run in the pinned LiteLLM image: python test_chatgpt_stream_recovery.py."""

import asyncio
import importlib.util
import unittest
from pathlib import Path

from litellm.completion_extras.litellm_responses_transformation.handler import (
    ResponsesToCompletionBridgeHandler,
)
from litellm.types.llms.openai import OutputItemDoneEvent, ResponsesAPIResponse
from litellm.types.responses.main import GenericResponseOutputItem, OutputText


class Completed:
    def __init__(self, response):
        self.response = response


class Stream:
    def __init__(self, events, response):
        self.events, self.response = events, response
        self.completed_response = None
        self._hidden_params = {"headers": {"x-test": "1"}}

    def __iter__(self):
        for event in self.events:
            yield event
        self.completed_response = Completed(self.response)


class AsyncStream(Stream):
    def __aiter__(self):
        return self

    async def __anext__(self):
        if self.events:
            return self.events.pop(0)
        self.completed_response = Completed(self.response)
        raise StopAsyncIteration


def response(output=None, status="completed", error=None):
    return ResponsesAPIResponse.model_construct(
        id="resp_1", created_at=0, model="chatgpt", object="response",
        output=[] if output is None else output, status=status, error=error,
    )


def choices(raw):
    bridge = ResponsesToCompletionBridgeHandler()
    transform = bridge.transformation_handler
    return transform._convert_response_output_to_choices(raw.output, transform._handle_raw_dict_response_item)


class StreamRecoveryTest(unittest.TestCase):
    def test_00_unpatched_bridge_loses_done_items(self):
        raw = ResponsesToCompletionBridgeHandler()._collect_response_from_stream(
            Stream([{"type": "response.output_text.done", "text": "OK", "output_index": 0}], response())
        )
        self.assertEqual(raw.output, [])

    def test_10_recovers_text_and_real_downstream_choice(self):
        _load_patch()
        raw = ResponsesToCompletionBridgeHandler()._collect_response_from_stream(
            Stream([{"type": "response.output_text.done", "text": "OK", "output_index": 0}], response())
        )
        self.assertEqual(raw._hidden_params["headers"], {"x-test": "1"})
        self.assertEqual(choices(raw)[0].message.content, "OK")

    def test_20_preserves_order_and_function_arguments(self):
        _load_patch()
        raw = ResponsesToCompletionBridgeHandler()._collect_response_from_stream(Stream([
            {"type": "response.output_item.done", "output_index": 1,
             "item": {"type": "function_call", "id": "fc", "call_id": "call_1", "name": "weather", "arguments": '{"city":"Paris"}'}},
            {"type": "response.output_item.done", "output_index": 0,
             "item": {"type": "message", "role": "assistant", "content": [{"type": "output_text", "text": "first"}]}},
        ], response()))
        result = choices(raw)
        self.assertEqual(result[0].message.content, "first")
        self.assertEqual(result[1].message.tool_calls[0]["function"]["arguments"], '{"city":"Paris"}')

    def test_30_keeps_complete_output_and_missing_or_failed_terminal_errors(self):
        _load_patch()
        original = [{"type": "message", "role": "assistant", "content": [{"type": "output_text", "text": "kept"}]}]
        raw = ResponsesToCompletionBridgeHandler()._collect_response_from_stream(Stream([
            {"type": "response.output_text.done", "text": "replaced", "output_index": 0},
        ], response(original)))
        self.assertEqual(raw.output, original)
        failed = ResponsesToCompletionBridgeHandler()._collect_response_from_stream(Stream([
            {"type": "response.output_text.done", "text": "ignored", "output_index": 0},
        ], response(status="failed", error={"message": "nope"})))
        self.assertEqual(failed.output, [])
        incomplete = ResponsesToCompletionBridgeHandler()._collect_response_from_stream(Stream([
            {"type": "response.output_text.done", "text": "ignored", "output_index": 0},
        ], response(status="incomplete")))
        self.assertEqual(incomplete.output, [])
        empty = ResponsesToCompletionBridgeHandler()._collect_response_from_stream(Stream([], response()))
        self.assertEqual(empty.output, [])
        with self.assertRaisesRegex(ValueError, "without a completed response"):
            ResponsesToCompletionBridgeHandler()._collect_response_from_stream(Stream([], None))

    def test_40_recovers_async(self):
        _load_patch()
        raw = asyncio.run(ResponsesToCompletionBridgeHandler()._collect_response_from_stream_async(
            AsyncStream([OutputItemDoneEvent.model_construct(
                type="response.output_item.done", output_index=0,
                item=GenericResponseOutputItem(
                    type="message", id="msg_1", status="completed", role="assistant",
                    content=[OutputText(type="output_text", text="async", annotations=[])],
                ),
            )], response())
        ))
        self.assertEqual(choices(raw)[0].message.content, "async")


def _load_patch():
    path = Path(__file__).with_name("chatgpt_stream_recovery.py")
    spec = importlib.util.spec_from_file_location("chatgpt_stream_recovery", path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


if __name__ == "__main__":
    unittest.main()
