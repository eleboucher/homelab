# CLIProxyAPI

The gateway serves `http://cliproxyapi.ai:8317/v1` inside the cluster and
`https://cliproxyapi.erwanleboucher.dev/v1` externally. The previous
`http://litellm.ai:4000/v1` and `https://litellm.erwanleboucher.dev/v1` addresses
remain compatible aliases for chat and Responses requests.

OpenClaw and Hermes retain the `litellm` provider identifier for saved sessions
and scheduled jobs, but send requests to CLIProxyAPI. They use these model aliases:

| Alias                   | Default reasoning effort |
| ----------------------- | ------------------------ |
| `chatgpt/gpt-5.6-luna`  | low                      |
| `chatgpt/gpt-5.6-terra` | medium                   |

The downstream API key still comes from the existing 1Password `litellm` item's
`LITELLM_MASTER_KEY` field. External Secrets exposes it as `CLIPROXY_API_KEY`;
clients retain their existing key value.

Context7 connects directly from OpenClaw and Hermes, with its API key supplied
through External Secrets. Memini's embedding and reranking endpoints continue to
use the LLMKube services directly. These endpoints are not served by CLIProxyAPI.
LiteLLM's Redis response cache and its request metrics are not provided by this
replacement. Gateway health is monitored through Gatus at `/healthz`; Kubernetes
continues to collect pod resource metrics. The llama-server dashboard lives with
LLMKube's models.

## Authentication

Credentials live in `/auth` on a separate `miroir-replicated` volume. The proxy
renews its independent OAuth credential automatically. Management endpoints,
the management UI, and request logging are disabled.

To recover an expired or revoked login:

```sh
kubectl --context admin@homelab -n ai exec -it deploy/cliproxyapi -c app -- \
  /CLIProxyAPI/CLIProxyAPI --config /etc/cliproxyapi/config.yaml \
  --codex-device-login --no-browser
```

Complete the displayed device login and wait for the success message. The file
watcher loads the new credential without restarting the proxy. Do not copy a
refresh token from another running application: both would rotate the same
credential without coordinating their writes.

The old `litellm-chatgpt` PVC is retained for rollback and protected from pruning.
It is not mounted by CLIProxyAPI. The LiteLLM workload and operator are removed.

## Compatibility checks

```sh
kubectl --context admin@homelab -n ai port-forward svc/cliproxyapi 18317:8317
```

In another terminal, set `CLIPROXY_API_KEY` to the existing downstream key and run:

```sh
python3 kubernetes/apps/ai/cliproxyapi/smoke.py
```

The checks cover authentication, model aliases, and both models with Chat
Completions and Responses, streaming and non-streaming, including tool round
trips. They use synthetic prompts and do not print credentials or HTTP error
bodies. Token renewal was also verified during migration using the independent
login; the smoke suite does not force a credential refresh.

Check resource use and readiness with:

```sh
kubectl --context admin@homelab -n ai top pods --containers
kubectl --context admin@homelab -n ai get helmrelease cliproxyapi
```
