#!/bin/zsh
set -euo pipefail

PORT="4319"
LABEL="not-claude-code-emulator"
ROOT="$HOME/.npm-global/lib/node_modules/not-claude-code-emulator"
PLIST="$HOME/Library/LaunchAgents/${LABEL}.plist"

if ! command -v bun >/dev/null 2>&1; then
  echo "bun is required" >&2
  exit 1
fi

if ! command -v hermes >/dev/null 2>&1; then
  echo "hermes CLI not found; install before running bootstrap" >&2
  exit 1
fi

if ! command -v opencode >/dev/null 2>&1; then
  echo "opencode CLI not found; install before running bootstrap" >&2
  exit 1
fi

cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${HOME}/.bun/bin/bun</string>
    <string>run</string>
    <string>${ROOT}/src/index.ts</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>HOST</key>
    <string>127.0.0.1</string>
    <key>PORT</key>
    <string>${PORT}</string>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>WorkingDirectory</key>
  <string>${ROOT}</string>
  <key>StandardOutPath</key>
  <string>/tmp/not-claude-code-emulator.stdout.log</string>
  <key>StandardErrorPath</key>
  <string>/tmp/not-claude-code-emulator.stderr.log</string>
</dict>
</plist>
EOF

mkdir -p "$HOME/bin"

cat > "$HOME/bin/madani-proxy" <<'EOF'
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
EOF

cat > "$HOME/bin/hermes-proxy" <<'EOF'
#!/bin/zsh
set -euo pipefail
CFG="$HOME/.hermes/config.yaml"
grep -q '^  provider: "custom"' "$CFG" || { echo "config.yaml provider must be custom" >&2; exit 1; }
grep -q '^  base_url: "http://127.0.0.1:4319"' "$CFG" || { echo "config.yaml base_url must be 127.0.0.1:4319" >&2; exit 1; }
exec hermes chat "$@"
EOF

chmod +x "$HOME/bin/madani-proxy" "$HOME/bin/hermes-proxy"

python3 - <<'PY'
import json, os, pathlib
p = pathlib.Path.home() / '.config' / 'opencode' / 'opencode.json'
cfg = json.loads(p.read_text())
cfg.setdefault('provider', {}).setdefault('anthropic', {}).setdefault('options', {})['baseURL'] = 'http://127.0.0.1:4319/v1'
p.write_text(json.dumps(cfg, indent=2) + '\n')
print(f'updated {p}')
PY

if [ -f "$HOME/.hermes/config.yaml" ]; then
  python3 - <<'PY'
from pathlib import Path
p = Path.home() / '.hermes' / 'config.yaml'
t = p.read_text()
t = t.replace('base_url: "http://127.0.0.1:3000"', 'base_url: "http://127.0.0.1:4319"')
p.write_text(t)
print(f'updated {p}')
PY
fi

if [ -f "$HOME/.hermes/.env" ]; then
  python3 - <<'PY'
from pathlib import Path
p = Path.home() / '.hermes' / '.env'
lines = p.read_text().splitlines()
out = []
found = False
for line in lines:
  if line.startswith('ANTHROPIC_API_KEY='):
    out.append('ANTHROPIC_API_KEY=')
    found = True
  else:
    out.append(line)
if not found:
  out.insert(0, 'ANTHROPIC_API_KEY=')
p.write_text('\n'.join(out) + '\n')
print(f'updated {p}')
PY
fi

launchctl bootstrap "gui/$(id -u)" "$PLIST" 2>/dev/null || true
launchctl enable "gui/$(id -u)/${LABEL}" 2>/dev/null || true
launchctl kickstart -k "gui/$(id -u)/${LABEL}"

echo "-- proxy status --"
"$HOME/bin/madani-proxy" status || true
echo "-- proxy test --"
"$HOME/bin/madani-proxy" test || true

echo "Bootstrap complete"
