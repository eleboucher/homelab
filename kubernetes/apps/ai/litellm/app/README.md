# LiteLLM ChatGPT authentication

LiteLLM uses the ChatGPT subscription provider's OAuth device flow. The refresh token is stored in the `litellm-chatgpt` PVC at `/app/chatgpt_tokens/auth.json`, so it survives proxy restarts.

Run this once after the proxy is available, then follow the verification URL and enter the displayed device code:

```sh
kubectl -n ai exec deploy/litellm -- python -c 'from litellm.llms.chatgpt.authenticator import Authenticator; Authenticator().get_access_token()'
```

The command does not send a model request or print the token. If the refresh token later expires or is revoked, run the same command again to start a new device flow.
