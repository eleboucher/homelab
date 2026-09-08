# LiteLLM ChatGPT authentication

LiteLLM uses the ChatGPT subscription provider's OAuth device flow. This deployment sets `CHATGPT_TOKEN_DIR=/app/chatgpt_tokens`, so its credentials are stored in `/app/chatgpt_tokens/auth.json` on the `litellm-chatgpt` PVC and survive proxy restarts.

## Bootstrap or recovery

Do not run the device flow with `kubectl exec deploy/litellm`. On a fresh PVC, LiteLLM requests a device code during proxy startup. Its liveness probe can then restart the Pod before the flow finishes, and `exec deploy/litellm` can select that CrashLooping Pod. Repeated starts also share the PVC's five-minute device-code cooldown.

Instead, run the device flow in this one-off Pod. It uses the proxy's pinned image and the same PVC, but has no probes. Apply it, follow the URL and enter the code shown in its logs, then wait for the success message.

```sh
kubectl apply -f - <<'EOF'
apiVersion: v1
kind: Pod
metadata:
  name: litellm-chatgpt-login
  namespace: ai
spec:
  containers:
    - name: login
      image: ghcr.io/berriai/litellm:v1.95.0-rc.2@sha256:210eda4b9e56beca0e31007b4b507ac77c05b48cd3526711b2f7baba2ac6ff73
      command:
        - python
        - -u
        - -c
        - "from litellm.llms.chatgpt.authenticator import Authenticator; Authenticator().get_access_token(); print('ChatGPT authentication saved successfully', flush=True)"
      env:
        - name: CHATGPT_TOKEN_DIR
          value: /app/chatgpt_tokens
      resources:
        requests:
          cpu: 100m
          memory: 256Mi
        limits:
          memory: 1Gi
      volumeMounts:
        - name: chatgpt-tokens
          mountPath: /app/chatgpt_tokens
  restartPolicy: Never
  volumes:
    - name: chatgpt-tokens
      persistentVolumeClaim:
        claimName: litellm-chatgpt
EOF

kubectl -n ai logs -f pod/litellm-chatgpt-login
```

After `ChatGPT authentication saved successfully` appears, remove the one-off Pod and wait for the `litellm` Deployment to become ready:

```sh
kubectl -n ai delete pod litellm-chatgpt-login
kubectl -n ai rollout status deployment/litellm
```

If an earlier proxy Pod still has credentials at the default `/root/.config/litellm/chatgpt/auth.json`, securely transfer that file to `/app/chatgpt_tokens/auth.json` on the PVC before removing the old Pod. Do not print, commit, or paste the file: it contains the refresh token.

## Non-streaming response compatibility

The pinned LiteLLM version discards streamed output when ChatGPT sends a final `response.completed` event with an empty `output` array. Non-streaming Chat Completions then fail with `Unknown items in responses API response: []`, including Hermes cron and summary requests.

`compat/chatgpt_stream_recovery.py` loads through LiteLLM's custom callback mechanism and repairs its synchronous and asynchronous stream collectors. It retains completed message and tool-call events, using them only when a successful final response has no output. Existing final output and error responses retain their normal handling. Luna remains the summary model.

Run `python test_chatgpt_stream_recovery.py -v` from the `compat` directory in an environment with the pinned LiteLLM dependencies. The tests reproduce the unpatched failure and check text, tool calls, ordering, and failure handling. Retest on LiteLLM upgrades, and remove the helper once upstream retains these events itself.

After changing the compatibility ConfigMap on an existing deployment, restart LiteLLM to reload the Python module. The initial rollout adds a volume and callback, which already triggers a new Pod.
