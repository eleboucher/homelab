"""Run in the pinned LiteLLM image: python test_chatgpt_token_recovery.py -v."""

import asyncio
import base64
import importlib.util
import json
import multiprocessing
import os
import stat
import tempfile
import time
import unittest
from pathlib import Path
from unittest.mock import patch

import httpx
import litellm
from litellm.llms.chatgpt.authenticator import Authenticator
from litellm.llms.custom_httpx.http_handler import AsyncHTTPHandler, HTTPHandler


BASE = "https://chatgpt.com/backend-api/codex"
ORIGINAL_POST = HTTPHandler.post
spec = importlib.util.spec_from_file_location(
    "chatgpt_token_recovery", Path(__file__).with_name("chatgpt_token_recovery.py")
)
recovery = importlib.util.module_from_spec(spec)
spec.loader.exec_module(recovery)


def token(label, expires=None):
    claims = {
        "exp": time.time() + 3600 if expires is None else expires,
        "jti": label,
        "https://api.openai.com/auth": {"chatgpt_account_id": "test-account"},
    }
    encoded = base64.urlsafe_b64encode(json.dumps(claims).encode()).decode().rstrip("=")
    return "header." + encoded + ".signature"


def refresh_worker(directory, old, new, forced, refreshes, barrier, results):
    """Independent proxy workers sharing only the token directory and test counters."""
    with patch.dict(os.environ, {"CHATGPT_TOKEN_DIR": directory, "CHATGPT_API_BASE": BASE}):
        def refresh(request):
            with refreshes.get_lock():
                refreshes.value += 1
            time.sleep(0.05)
            return httpx.Response(200, json={
                "access_token": new, "refresh_token": "refresh-new", "id_token": new,
            })

        def upstream(request):
            if request.headers["authorization"] == "Bearer " + old:
                return httpx.Response(401, json={"error": {"code": "token_expired"}})
            return httpx.Response(200)

        try:
            with httpx.Client(transport=httpx.MockTransport(refresh)) as oauth:
                with patch("litellm.llms.chatgpt.authenticator.get_httpx_client", return_value=oauth):
                    barrier.wait(timeout=15)
                    if forced:
                        with httpx.Client(transport=httpx.MockTransport(upstream)) as http:
                            result = HTTPHandler(client=http).post(
                                BASE + "/responses", headers={"Authorization": "Bearer " + old},
                            )
                        results.put(result.status_code == 200)
                    else:
                        results.put(Authenticator().get_access_token() == new)
        except Exception as exc:
            results.put(type(exc).__name__)


class TokenRecoveryTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory()
        self.addCleanup(self.directory.cleanup)
        env = patch.dict(os.environ, {"CHATGPT_TOKEN_DIR": self.directory.name, "CHATGPT_API_BASE": BASE})
        env.start()
        self.addCleanup(env.stop)
        # Catch any provider path that bypasses the supplied mock client.
        for method in ["httpx.HTTPTransport.handle_request", "httpx.AsyncHTTPTransport.handle_async_request"]:
            network = patch(method, side_effect=AssertionError("Tests must not make network requests"))
            network.start()
            self.addCleanup(network.stop)
        self.auth = Authenticator()
        self.old = token("old")
        self.new = token("new")
        self.seed(self.old)
        self.context = multiprocessing.get_context("spawn")
        self.refreshes = self.context.Value("i", 0)
        self.oauth_status = 200

        def refresh(request):
            with self.refreshes.get_lock():
                self.refreshes.value += 1
            body = json.loads(request.content)
            self.assertEqual(body["refresh_token"], "refresh-old")
            time.sleep(0.05)
            if self.oauth_status != 200:
                return httpx.Response(self.oauth_status, json={"error": "invalid_grant"})
            return httpx.Response(200, json={
                "access_token": self.new, "refresh_token": "refresh-new", "id_token": self.new,
            })

        self.oauth = HTTPHandler(client=httpx.Client(transport=httpx.MockTransport(refresh)))
        self.addCleanup(self.oauth.client.close)
        oauth = patch("litellm.llms.chatgpt.authenticator.get_httpx_client", return_value=self.oauth)
        oauth.start()
        self.addCleanup(oauth.stop)
        self.headers = {"Authorization": "Bearer " + self.old, "ChatGPT-Account-Id": "test-account"}
        self.requests = []

    def seed(self, access):
        self.auth._write_auth_file(self.auth._build_auth_record({
            "access_token": access, "refresh_token": "refresh-old", "id_token": access,
        }))

    def upstream(self, request):
        self.requests.append(request)
        if request.headers["authorization"] == "Bearer " + self.old:
            return httpx.Response(401, json={"error": {"code": "token_expired"}})
        self.assertEqual(request.headers["authorization"], "Bearer " + self.new)
        self.assertEqual(request.headers["chatgpt-account-id"], "test-account")
        self.assertEqual(json.loads(request.content), {"input": "test"})
        saved = json.loads(Path(self.auth.auth_file).read_text())
        self.assertEqual(saved["refresh_token"], "refresh-new")
        return httpx.Response(200, json={"output": "OK"})

    def client(self, handler=None):
        client = HTTPHandler(client=httpx.Client(transport=httpx.MockTransport(handler or self.upstream)))
        self.addCleanup(client.client.close)
        return client

    def test_unpatched_post_preserves_the_failure(self):
        with self.assertRaises(httpx.HTTPStatusError):
            ORIGINAL_POST(self.client(), BASE + "/responses", headers=self.headers, json={"input": "test"})
        self.assertEqual(self.refreshes.value, 0)

    def test_sync_refreshes_and_replays_once_before_streaming(self):
        for stream in [False, True]:
            with self.subTest(stream=stream):
                self.seed(self.old)
                self.requests.clear()
                self.refreshes.value = 0
                response = self.client().post(
                    BASE + "/responses", headers=self.headers, json={"input": "test"}, stream=stream,
                )
                self.assertEqual(response.status_code, 200)
                self.assertEqual(len(self.requests), 2)
                self.assertEqual(self.refreshes.value, 1)
                self.assertEqual(self.headers["Authorization"], "Bearer " + self.old)
                response.close()

    def test_second_rejection_is_returned_without_another_refresh(self):
        def rejected(request):
            self.requests.append(request)
            return httpx.Response(401, json={"error": {"code": "token_expired"}})

        with self.assertRaises(httpx.HTTPStatusError):
            self.client(rejected).post(BASE + "/responses", headers=self.headers)
        self.assertEqual(len(self.requests), 2)
        self.assertEqual(self.refreshes.value, 1)

    def test_other_errors_and_other_providers_are_unchanged(self):
        cases = [
            (403, "token_expired", BASE + "/responses"),
            (401, "invalid_token", BASE + "/responses"),
            (429, "rate_limit_exceeded", BASE + "/responses"),
            (401, "token_expired", "https://api.openai.com/v1/responses"),
            (401, "token_expired", BASE + "/other"),
            (401, None, BASE + "/responses"),
        ]
        for status, code, url in cases:
            with self.subTest(status=status, code=code, url=url):
                def reject(request):
                    return httpx.Response(status, json={"error": {"code": code}})
                with self.assertRaises(httpx.HTTPStatusError):
                    self.client(reject).post(url, headers=self.headers)
        self.assertEqual(self.refreshes.value, 0)

    def test_refused_refresh_preserves_original_error_without_device_login(self):
        self.oauth_status = 401
        with patch.object(Authenticator, "_login_device_code") as login:
            with self.assertLogs(recovery.logger, level="WARNING") as logs:
                with self.assertRaises(httpx.HTTPStatusError) as result:
                    self.client().post(BASE + "/responses", headers=self.headers)
            login.assert_not_called()
        self.assertEqual(result.exception.response.json()["error"]["code"], "token_expired")
        self.assertEqual(len(self.requests), 1)
        self.assertEqual(self.refreshes.value, 1)
        self.assertNotIn(self.old, "".join(logs.output))
        self.assertNotIn("refresh-old", "".join(logs.output))

    def test_reuses_credentials_already_rotated_by_another_worker(self):
        def changed(request):
            if not self.requests:
                self.auth._write_auth_file(self.auth._build_auth_record({
                    "access_token": self.new, "refresh_token": "refresh-new", "id_token": self.new,
                }))
            return self.upstream(request)

        response = self.client(changed).post(BASE + "/responses", headers=self.headers, json={"input": "test"})
        self.assertEqual(response.status_code, 200)
        self.assertEqual(self.refreshes.value, 0)

    def test_async_recovery_keeps_event_loop_responsive(self):
        async def run():
            client = AsyncHTTPHandler(transport=httpx.MockTransport(self.upstream))
            ticks = []
            async def ticker():
                for _ in range(5):
                    await asyncio.sleep(0.005)
                    ticks.append(self.refreshes.value)
            try:
                response, _ = await asyncio.gather(
                    client.post(BASE + "/responses", headers=self.headers, json={"input": "test"}, stream=True),
                    ticker(),
                )
                self.assertEqual(response.status_code, 200)
                self.assertEqual(ticks, [1] * 5)
                await response.aclose()
            finally:
                await client.client.aclose()
        asyncio.run(run())
        self.assertEqual(self.refreshes.value, 1)

    def test_litellm_responses_and_chat_completions_recover_end_to_end(self):
        completed = {
            "id": "resp_test", "object": "response", "created_at": 0,
            "status": "completed", "model": "gpt-5.6-luna",
            "output": [{
                "id": "msg_test", "type": "message", "role": "assistant", "status": "completed",
                "content": [{"type": "output_text", "text": "OK", "annotations": []}],
            }],
            "usage": {"input_tokens": 1, "output_tokens": 1, "total_tokens": 2},
        }

        def upstream(request):
            self.requests.append(request)
            if request.headers["authorization"] == "Bearer " + self.old:
                return httpx.Response(401, json={"error": {"code": "token_expired"}})
            self.assertEqual(request.headers["authorization"], "Bearer " + self.new)
            event = {"type": "response.completed", "response": completed}
            return httpx.Response(200, headers={"content-type": "text/event-stream"},
                                  text="data: " + json.dumps(event) + "\n\n")

        async def run(chat):
            client = AsyncHTTPHandler(transport=httpx.MockTransport(upstream))
            client_factory = patch(
                "litellm.llms.custom_httpx.llm_http_handler.get_async_httpx_client", return_value=client,
            )
            client_factory.start()
            try:
                if chat:
                    response = await litellm.acompletion(
                        model="chatgpt/gpt-5.6-luna", messages=[{"role": "user", "content": "test"}],
                        client=client, stream=False,
                    )
                    self.assertEqual(response.choices[0].message.content, "OK")
                else:
                    response = await litellm.aresponses(
                        model="chatgpt/gpt-5.6-luna", input="test", client=client, stream=False,
                    )
                    self.assertEqual(response.output[0].content[0].text, "OK")
            finally:
                client_factory.stop()
                await client.client.aclose()

        for chat in [False, True]:
            with self.subTest(chat=chat):
                self.seed(self.old)
                self.refreshes.value = 0
                self.requests.clear()
                asyncio.run(run(chat))
                self.assertEqual(self.refreshes.value, 1)
                self.assertEqual(len(self.requests), 2)

    def test_workers_serialize_forced_and_normal_expiry_refreshes(self):
        for forced in [True, False]:
            with self.subTest(forced=forced):
                self.seed(self.old if forced else token("expired", expires=0))
                self.refreshes.value = 0
                barrier = self.context.Barrier(2)
                results = self.context.Queue()

                processes = [self.context.Process(
                    target=refresh_worker,
                    args=(self.directory.name, self.old, self.new, forced, self.refreshes, barrier, results),
                ) for _ in range(2)]
                try:
                    for process in processes:
                        process.start()
                    for process in processes:
                        process.join(timeout=25)
                        self.assertEqual(process.exitcode, 0)
                    self.assertEqual([results.get(timeout=1) for _ in processes], [True, True])
                    self.assertEqual(self.refreshes.value, 1)
                finally:
                    for process in processes:
                        if process.is_alive():
                            process.terminate()
                            process.join()
                    results.close()
                    results.join_thread()

    def test_failed_atomic_write_preserves_credentials_and_cleans_temporary_file(self):
        path = Path(self.auth.auth_file)
        before = path.read_bytes()
        with patch.object(recovery.os, "replace", side_effect=OSError("write failed")):
            with self.assertRaises(OSError):
                self.seed(self.new)
        self.assertEqual(path.read_bytes(), before)
        self.assertEqual(list(path.parent.iterdir()), [path])
        self.assertEqual(stat.S_IMODE(path.stat().st_mode), 0o600)

    def test_patch_install_is_idempotent(self):
        functions = (HTTPHandler.post, AsyncHTTPHandler.post, Authenticator.get_access_token)
        recovery.patch_install()
        self.assertEqual(functions, (HTTPHandler.post, AsyncHTTPHandler.post, Authenticator.get_access_token))


if __name__ == "__main__":
    unittest.main()
