#!/bin/bash
# Test harness for cc-status-hook.sh using a throwaway state dir.
set -e
HOOK="$(cd "$(dirname "$0")" && pwd)/cc-status-hook.sh"
export CC_STATUS_DIR="$(mktemp -d)"
trap 'rm -rf "$CC_STATUS_DIR"' EXIT

fail() { echo "FAIL: $1"; exit 1; }

# main session writes <sid>.json
echo '{"session_id":"S1","cwd":"/proj/A"}' | "$HOOK" working
[ -f "$CC_STATUS_DIR/S1.json" ] || fail "main file not written"

# subagent writes <sid>__<aid>.json including agent_type
echo '{"session_id":"S1","cwd":"/proj/A","agent_id":"AG1","agent_type":"Explore"}' | "$HOOK" working
[ -f "$CC_STATUS_DIR/S1__AG1.json" ] || fail "agent file not written"
grep -q '"agent_type": "Explore"' "$CC_STATUS_DIR/S1__AG1.json" || fail "agent_type not stored"

# remove with agent_id removes only that agent file
echo '{"session_id":"S1","cwd":"/proj/A","agent_id":"AG1"}' | "$HOOK" remove
[ -f "$CC_STATUS_DIR/S1__AG1.json" ] && fail "agent file not removed"
[ -f "$CC_STATUS_DIR/S1.json" ] || fail "main file wrongly removed"

# session end (no agent_id) removes main + all its agents
echo '{"session_id":"S1","cwd":"/proj/A","agent_id":"AG2","agent_type":"x"}' | "$HOOK" working
echo '{"session_id":"S1","cwd":"/proj/A"}' | "$HOOK" remove
[ -f "$CC_STATUS_DIR/S1.json" ] && fail "main file not removed on session end"
[ -f "$CC_STATUS_DIR/S1__AG2.json" ] && fail "agent file not removed on session end"

echo "ALL PASS"
