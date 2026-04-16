# Team setup guide (OpenCode + Hermes) + AI handoff

This document is the canonical onboarding path for Madani team members.

It covers:

1. Installing the proxy
2. Running it permanently on a dedicated port (`4319`)
3. Wiring OpenCode + Hermes to the proxy
4. Adding health-check helpers
5. Validating end-to-end

---

## Prerequisites

- macOS
- Bun installed (`bun --version`)
- Node/npm installed (`npm -v`)
- GitHub CLI installed and authenticated (`gh auth status`)

---

## 1) Install proxy and OAuth token

```bash
npm install -g not-claude-code-emulator
not-claude-code-emulator install
not-claude-code-emulator verify-token
```

Expected last command: `Token is valid and working`.

---

## 2) Run permanently via launchd on port 4319

Create `~/Library/LaunchAgents/not-claude-code-emulator.plist` with:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>not-claude-code-emulator</string>
  <key>ProgramArguments</key>
  <array>
    <string>/Users/<your-user>/.bun/bin/bun</string>
    <string>run</string>
    <string>/Users/<your-user>/.npm-global/lib/node_modules/not-claude-code-emulator/src/index.ts</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>HOST</key>
    <string>127.0.0.1</string>
    <key>PORT</key>
    <string>4319</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>WorkingDirectory</key>
  <string>/Users/<your-user>/.npm-global/lib/node_modules/not-claude-code-emulator</string>
  <key>StandardOutPath</key>
  <string>/tmp/not-claude-code-emulator.stdout.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/not-claude-code-emulator.stderr.log</string>
</dict>
</plist>
```

Load/start it:

```bash
launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/not-claude-code-emulator.plist" 2>/dev/null || true
launchctl enable "gui/$(id -u)/not-claude-code-emulator" 2>/dev/null || true
launchctl kickstart -k "gui/$(id -u)/not-claude-code-emulator"
```

Health check:

```bash
curl -fsS http://127.0.0.1:4319/health
```

---

## 3) Configure OpenCode

File: `~/.config/opencode/opencode.json`

Ensure:

```json
"provider": {
  "anthropic": {
    "options": {
      "baseURL": "http://127.0.0.1:4319/v1"
    }
  }
}
```

---

## 4) Configure Hermes

File: `~/.hermes/config.yaml`

```yaml
model:
  default: "claude-sonnet-4-6"
  provider: "custom"
  base_url: "http://127.0.0.1:4319"
  api_mode: "anthropic_messages"
```

File: `~/.hermes/.env`

```dotenv
ANTHROPIC_API_KEY=
```

Why: if `ANTHROPIC_API_KEY` is set and Hermes/provider drifts, it may hit `https://api.anthropic.com` directly and fail with `401 invalid x-api-key`.

---

## 5) Install helper commands (recommended)

Create `~/bin/madani-proxy`:

```bash
#!/bin/zsh
set -euo pipefail

LABEL="not-claude-code-emulator"
PORT="4319"
BASE_URL="http://127.0.0.1:${PORT}"

status() {
  echo "== launchd =="; launchctl list | grep "$LABEL" || true
  echo "== listener =="; lsof -nP -iTCP:"$PORT" -sTCP:LISTEN || true
  echo "== health =="; curl -fsS "${BASE_URL}/health" || true; echo
}
start() {
  launchctl bootstrap "gui/$(id -u)" "$HOME/Library/LaunchAgents/${LABEL}.plist" 2>/dev/null || true
  launchctl enable "gui/$(id -u)/${LABEL}" 2>/dev/null || true
  launchctl kickstart -k "gui/$(id -u)/${LABEL}"
  sleep 1; status
}
stop() { launchctl bootout "gui/$(id -u)/${LABEL}" 2>/dev/null || true; sleep 1; status; }
restart() { stop; start; }
test_call() {
  curl -fsS -X POST "${BASE_URL}/v1/messages" -H "Content-Type: application/json" \
    -d '{"model":"claude-opus-4-6","max_tokens":20,"messages":[{"role":"user","content":"Reply with PROXY_OK"}]}'
  echo
}
case "${1:-status}" in
  status) status ;;
  start) start ;;
  stop) stop ;;
  restart) restart ;;
  test) test_call ;;
  *) echo "Usage: madani-proxy {status|start|stop|restart|test}" >&2; exit 1 ;;
esac
```

Create `~/bin/hermes-proxy`:

```bash
#!/bin/zsh
set -euo pipefail
CFG="$HOME/.hermes/config.yaml"

grep -q '^  provider: "custom"' "$CFG" || { echo "config.yaml provider must be custom" >&2; exit 1; }
grep -q '^  base_url: "http://127.0.0.1:4319"' "$CFG" || { echo "config.yaml base_url must be 127.0.0.1:4319" >&2; exit 1; }

exec hermes chat "$@"
```

Make executable:

```bash
chmod +x ~/bin/madani-proxy ~/bin/hermes-proxy
```

---

## 6) Validation checklist

```bash
~/bin/madani-proxy status
~/bin/madani-proxy test
~/bin/hermes-proxy -Q -m "claude-sonnet-4-6" -q "Reply with HERMES_OK"
~/bin/hermes-proxy -Q -m "claude-opus-4-6" -q "Reply with HERMES_OPUS_OK"
```

Expected outputs include `PROXY_OK`, `HERMES_OK`, `HERMES_OPUS_OK`.

---

## Common failures and exact fixes

- `Cannot connect to API`:
  - Run `~/bin/madani-proxy restart`
  - Re-check `curl http://127.0.0.1:4319/health`

- Hermes error shows endpoint `https://api.anthropic.com` + `401 invalid x-api-key`:
  - Hermes drifted from proxy mode
  - Ensure `~/.hermes/config.yaml` uses `provider: custom`, `base_url: http://127.0.0.1:4319`
  - Ensure `ANTHROPIC_API_KEY=` (empty) in `~/.hermes/.env`
  - Relaunch with `~/bin/hermes-proxy ...`

- `Upstream request failed` when using a Sonnet date variant:
  - Use canonical `claude-sonnet-4-6`
  - This fork also normalizes known aliases.

---

## AI handoff prompt (copy/paste)

Use this prompt with any coding agent to perform setup automatically:

```text
Set up Madani proxy for OpenCode and Hermes on macOS with stable launchd service.

Requirements:
1) Proxy endpoint must be 127.0.0.1:4319 (not 3000).
2) Ensure launchd KeepAlive + RunAtLoad and verify health endpoint works.
3) Configure OpenCode anthropic baseURL to http://127.0.0.1:4319/v1.
4) Configure Hermes to provider custom, base_url http://127.0.0.1:4319, api_mode anthropic_messages.
5) Clear direct ANTHROPIC_API_KEY in ~/.hermes/.env to prevent provider drift.
6) Create helper scripts ~/bin/madani-proxy and ~/bin/hermes-proxy.
7) Run validation commands and show outputs:
   - madani-proxy status
   - madani-proxy test
   - hermes-proxy one-shot sonnet
   - hermes-proxy one-shot opus

Do not stop until all checks pass.
```
