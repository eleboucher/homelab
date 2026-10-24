"""Refresh ChatGPT credentials once when the backend rejects an unexpired token.

Remove when LiteLLM handles token_expired responses and coordinates token rotation:
https://docs.litellm.ai/docs/providers/chatgpt#refresh-failures-and-revocation
"""

import asyncio
import fcntl
import inspect
import json
import logging
import os
import tempfile
from contextlib import contextmanager
from functools import wraps
from pathlib import Path

import httpx
from litellm.integrations.custom_logger import CustomLogger
from litellm.llms.chatgpt.authenticator import Authenticator
from litellm.llms.custom_httpx.http_handler import AsyncHTTPHandler, HTTPHandler

logger = logging.getLogger(__name__)


@contextmanager
def _auth_lock(auth):
    # Lock a separate inode: auth.json is replaced atomically on every write.
    fd = os.open(auth.auth_file + ".lock", os.O_CREAT | os.O_RDWR, 0o600)
    with os.fdopen(fd, "w") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            yield
        finally:
            fcntl.flock(lock, fcntl.LOCK_UN)


def _write_auth_file(self, data):
    path = Path(self.auth_file)
    fd, temporary = tempfile.mkstemp(prefix=path.name + ".", dir=path.parent)
    try:
        with os.fdopen(fd, "w") as output:
            json.dump(data, output)
            output.flush()
            os.fsync(output.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def _is_expired_response(error):
    if error.response.status_code != 401:
        return False
    auth = Authenticator()
    if str(error.request.url) != auth.get_api_base().rstrip("/") + "/responses":
        return False
    try:
        body = error.response.json()
    except (ValueError, httpx.ResponseNotRead):
        return False
    return (
        isinstance(body, dict)
        and isinstance(body.get("error"), dict)
        and body["error"].get("code") == "token_expired"
    )


def _refresh_headers(request):
    auth = Authenticator()
    with _auth_lock(auth):
        data = auth._read_auth_file() or {}
        token = data.get("access_token")
        # Another worker may already have replaced the rejected credential.
        if (
            not token
            or request.headers.get("authorization") == "Bearer " + token
            or auth._is_token_expired(data, token)
        ):
            refresh_token = data.get("refresh_token")
            if not refresh_token:
                raise ValueError("ChatGPT refresh token is missing")
            auth._refresh_tokens(refresh_token)
            data = auth._read_auth_file() or {}
            token = data.get("access_token")
            logger.info("Refreshed ChatGPT credential after token_expired")
        if not token:
            raise ValueError("ChatGPT access token is missing after refresh")
        headers = httpx.Headers(request.headers)
        headers["authorization"] = "Bearer " + token
        if data.get("account_id"):
            headers["chatgpt-account-id"] = data["account_id"]
        return dict(headers)


def patch_install():
    """Install once, including when callback modules are loaded repeatedly."""
    if getattr(Authenticator, "_chatgpt_token_recovery", False):
        return

    original_get = Authenticator.get_access_token

    @wraps(original_get)
    def get_access_token(self):
        data = self._read_auth_file() or {}
        token = data.get("access_token")
        if token and not self._is_token_expired(data, token):
            return token
        # Also serialize LiteLLM's normal expiry-driven refreshes.
        with _auth_lock(self):
            return original_get(self)

    original_post = HTTPHandler.post
    original_async_post = AsyncHTTPHandler.post
    sync_signature = inspect.signature(original_post)
    async_signature = inspect.signature(original_async_post)

    @wraps(original_post)
    def post(self, *args, **kwargs):
        try:
            return original_post(self, *args, **kwargs)
        except httpx.HTTPStatusError as error:
            if not _is_expired_response(error):
                raise
            try:
                headers = _refresh_headers(error.request)
            except Exception:
                logger.warning("ChatGPT token refresh failed; check authentication and sign in again if required")
                raise error from None
            call = sync_signature.bind(self, *args, **kwargs)
            call.arguments["headers"] = headers
        # A second rejection is returned normally; never replay an active stream.
        return original_post(*call.args, **call.kwargs)

    @wraps(original_async_post)
    async def async_post(self, *args, **kwargs):
        try:
            return await original_async_post(self, *args, **kwargs)
        except httpx.HTTPStatusError as error:
            if not _is_expired_response(error):
                raise
            try:
                headers = await asyncio.to_thread(_refresh_headers, error.request)
            except Exception:
                logger.warning("ChatGPT token refresh failed; check authentication and sign in again if required")
                raise error from None
            call = async_signature.bind(self, *args, **kwargs)
            call.arguments["headers"] = headers
        return await original_async_post(*call.args, **call.kwargs)

    Authenticator._write_auth_file = _write_auth_file
    Authenticator.get_access_token = get_access_token
    HTTPHandler.post = post
    AsyncHTTPHandler.post = async_post
    Authenticator._chatgpt_token_recovery = True


proxy_handler_instance = CustomLogger()
patch_install()
