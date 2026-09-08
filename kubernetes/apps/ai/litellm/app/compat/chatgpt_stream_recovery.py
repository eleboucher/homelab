"""Work around LiteLLM's Responses-to-Chat-Completions bridge losing SSE output.

The pinned collector exhausts the stream without retaining its events:
https://github.com/BerriAI/litellm/blob/v1.95.0-rc.2/litellm/completion_extras/litellm_responses_transformation/handler.py
Remove this when ``ResponsesToCompletionBridgeHandler`` retains SSE output items
while collecting a non-streaming Responses API request.
"""

from typing import Any

from litellm.integrations.custom_logger import CustomLogger
from pydantic import BaseModel


def _plain(value: Any) -> Any:
    # Iterate fields to retain subclass data without invoking incomplete serializers.
    if isinstance(value, BaseModel):
        value = dict(value)
    if isinstance(value, dict):
        return {key: _plain(item) for key, item in value.items()}
    if isinstance(value, list):
        return [_plain(item) for item in value]
    return value


def _record(chunk: Any, items: dict[int, dict], text: dict[int, dict]) -> None:
    from litellm.responses.sse_output_recovery import (
        record_output_item_chunk,
        record_output_text_chunk,
    )

    kind = chunk.get("type") if isinstance(chunk, dict) else getattr(chunk, "type", None)
    if kind not in ("response.output_item.done", "response.output_text.done"):
        return
    event = _plain(chunk)
    if kind == "response.output_item.done":
        record_output_item_chunk(event, items)
    else:
        record_output_text_chunk(event, items, text)


def _repair(response: Any, items: dict[int, dict], text: dict[int, dict]) -> Any:
    merged = {**text, **items}
    # A failed/incomplete response must follow LiteLLM's normal error path.
    if (
        getattr(response, "status", None) == "completed"
        and not getattr(response, "output", None)
        and getattr(response, "error", None) is None
    ):
        output = [item for _, item in sorted(merged.items())]
        if output:
            response.output = output
    return response


def patch_install() -> None:
    """Install once; custom callback modules can be imported more than once."""
    from litellm.completion_extras.litellm_responses_transformation.handler import (
        ResponsesToCompletionBridgeHandler,
    )

    if getattr(ResponsesToCompletionBridgeHandler, "_chatgpt_stream_recovery", False):
        return

    def collect(self: Any, stream_iter: Any) -> Any:
        items, text = {}, {}
        for chunk in stream_iter:
            _record(chunk, items, text)
        completed = getattr(stream_iter, "completed_response", None)
        response_obj = getattr(completed, "response", None) if completed else None
        if response_obj is None:
            raise ValueError("Stream ended without a completed response")
        response = self._coerce_response_object(response_obj, getattr(stream_iter, "_hidden_params", None))
        return _repair(response, items, text)

    async def collect_async(self: Any, stream_iter: Any) -> Any:
        items, text = {}, {}
        async for chunk in stream_iter:
            _record(chunk, items, text)
        completed = getattr(stream_iter, "completed_response", None)
        response_obj = getattr(completed, "response", None) if completed else None
        if response_obj is None:
            raise ValueError("Stream ended without a completed response")
        response = self._coerce_response_object(response_obj, getattr(stream_iter, "_hidden_params", None))
        return _repair(response, items, text)

    ResponsesToCompletionBridgeHandler._collect_response_from_stream = collect
    ResponsesToCompletionBridgeHandler._collect_response_from_stream_async = collect_async
    ResponsesToCompletionBridgeHandler._chatgpt_stream_recovery = True


proxy_handler_instance = CustomLogger()
patch_install()
