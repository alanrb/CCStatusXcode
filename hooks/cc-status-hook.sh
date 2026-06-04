#!/bin/bash
# cc-status-hook.sh
# Called by Claude Code hooks. Reads the event JSON from stdin and writes
# a per-session OR per-subagent state file that the CC Status app reads.
#
# Install to: ~/.claude/hooks/cc-status-hook.sh   (chmod +x)
# Usage in settings.json:  cc-status-hook.sh <state>
#   states: working | idle | attention | remove
#
# Files: <session_id>.json              (main thread)
#        <session_id>__<agent_id>.json  (subagent; carries agent_type)

STATE_DIR="${CC_STATUS_DIR:-$HOME/.claude/cc-status}"
mkdir -p "$STATE_DIR"

STATE="$1" STATE_DIR="$STATE_DIR" python3 -c '
import json, os, sys, time, glob

data = json.load(sys.stdin)
state = os.environ.get("STATE") or "idle"
state_dir = os.environ["STATE_DIR"]

session_id = data.get("session_id")
if not session_id:
    sys.exit(0)

agent_id = data.get("agent_id")
agent_type = data.get("agent_type") or "agent"

session_path = os.path.join(state_dir, session_id + ".json")
def agent_path(aid):
    return os.path.join(state_dir, session_id + "__" + aid + ".json")

if state == "remove":
    if agent_id:
        try: os.remove(agent_path(agent_id))
        except FileNotFoundError: pass
    else:
        try: os.remove(session_path)
        except FileNotFoundError: pass
        for p in glob.glob(os.path.join(state_dir, session_id + "__*.json")):
            try: os.remove(p)
            except FileNotFoundError: pass
    sys.exit(0)

cwd = data.get("cwd", "")
out = {
    "state": state,
    "project": os.path.basename(cwd) or "unknown",
    "cwd": cwd,
    "ts": int(time.time()),
}
if agent_id:
    out["agent_id"] = agent_id
    out["agent_type"] = agent_type
    path = agent_path(agent_id)
else:
    path = session_path

with open(path, "w") as f:
    json.dump(out, f)
'
exit 0
