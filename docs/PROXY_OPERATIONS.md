# Proxy operations runbook (OpenCode + Hermes)

## Why sessions looked unstable

Two separate failure modes can look like random shutdowns:

1. Client/provider drift: Hermes can switch to direct Anthropic in-session. When that happens, requests go to `https://api.anthropic.com` instead of local proxy and fail with `401 invalid x-api-key`.
2. Startup auth/network flakiness: startup token verification can fail during transient network issues.

This fork hardens both paths:

- startup auth check is non-fatal
- 401 upstream retries once with refreshed stored OAuth token
- Sonnet alias normalization maps known invalid Sonnet variants to `claude-sonnet-4-6`

## Required local endpoint

- Proxy host: `127.0.0.1`
- Proxy port: `4319`
- API base: `http://127.0.0.1:4319/v1`

## Quick health commands

```bash
~/bin/madani-proxy status
~/bin/madani-proxy restart
~/bin/madani-proxy test
```

Expected test output contains `PROXY_OK`.

## OpenCode config

`~/.config/opencode/opencode.json`:

```json
"provider": {
  "anthropic": {
    "options": {
      "baseURL": "http://127.0.0.1:4319/v1"
    }
  }
}
```

## Hermes config

`~/.hermes/config.yaml`:

```yaml
model:
  provider: "custom"
  base_url: "http://127.0.0.1:4319"
  api_mode: "anthropic_messages"
```

`~/.hermes/.env` should not contain a direct Anthropic key for this flow:

```dotenv
ANTHROPIC_API_KEY=
```

Use the wrapper to ensure config stays pinned:

```bash
~/bin/hermes-proxy -Q -m "claude-opus-4-6" -q "Reply with OK"
```

## Troubleshooting map

- Error shows endpoint `https://api.anthropic.com` + 401 invalid key:
  - Hermes drifted to direct provider path. Return to proxy-pinned config.
- Error `Upstream request failed` with Sonnet date variant:
  - Use canonical model or rely on alias normalization in this fork.
- Health fails on `127.0.0.1:4319`:
  - restart with `~/bin/madani-proxy restart` and re-test.
