#!/bin/bash
set -euo pipefail

REPO="${REPO:-sam55silver/context-engineering-exercise}"
POLL_SECONDS="${POLL_SECONDS:-30}"
MAX_ITERATIONS="${MAX_ITERATIONS:-0}"   # 0 = run forever
HANDLED_FILE="${HANDLED_FILE:-.handled-issues}"
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"

echo "=== Issue Loop — GitHub Issue Monitor ==="
echo "Watching: $REPO"
echo "Poll interval: ${POLL_SECONDS}s"
echo ""

# Track which issues we've already dispatched so we don't re-run them
touch "$HANDLED_FILE"

iteration=0

while true; do
  iteration=$((iteration + 1))

  if [ "$MAX_ITERATIONS" -gt 0 ] && [ "$iteration" -gt "$MAX_ITERATIONS" ]; then
    echo "Reached MAX_ITERATIONS ($MAX_ITERATIONS). Exiting."
    break
  fi

  echo "--- Poll #$iteration @ $(date '+%H:%M:%S') ---"

  # Fetch all open issues (not PRs) as a JSON file per issue
  ISSUES_JSON=$(gh issue list \
    --repo "$REPO" \
    --state open \
    --json number,title,body \
    --limit 50 \
    2>/dev/null || echo "[]")

  ISSUE_COUNT=$(echo "$ISSUES_JSON" | python3 -c "import sys,json; print(len(json.load(sys.stdin)))" 2>/dev/null || echo "0")

  if [ "$ISSUE_COUNT" = "0" ]; then
    echo "No open issues."
  else
    echo "$ISSUE_COUNT open issue(s) found."

    # Write issues JSON to a temp file and dispatch an agent per issue
    ISSUES_TMP=$(mktemp)
    echo "$ISSUES_JSON" > "$ISSUES_TMP"

    python3 - "$ISSUES_TMP" <<'PYEOF'
import sys, json, os, subprocess, tempfile

with open(sys.argv[1]) as f:
    issues = json.load(f)
repo_root = os.environ.get("REPO_ROOT", ".")
handled_file = os.path.join(repo_root, os.environ.get("HANDLED_FILE", ".handled-issues"))

# Load already-handled issue numbers
handled = set()
if os.path.exists(handled_file):
    with open(handled_file) as f:
        handled = set(line.strip() for line in f if line.strip())

for issue in issues:
    num = str(issue["number"])
    title = issue.get("title") or "(no title)"
    body = issue.get("body") or "(no body)"

    if num in handled:
        print(f"  Issue #{num} already dispatched — skipping.")
        continue

    print(f"  -> Dispatching agent for issue #{num}: {title}", flush=True)

    # Mark handled immediately
    with open(handled_file, "a") as f:
        f.write(num + "\n")

    # Build the prompt that injects issue context
    prompt = f"""@issue-worker

ISSUE_NUMBER: {num}
ISSUE_TITLE: {title}
ISSUE_BODY:
{body}
"""

    # Write prompt to a temp file so we don't have shell quoting issues
    with tempfile.NamedTemporaryFile(mode="w", suffix=".txt", delete=False) as tf:
        tf.write(prompt)
        prompt_file = tf.name

    try:
        # Reset to repo root and clean branch before each agent run
        subprocess.run(["git", "checkout", "main"], cwd=repo_root, capture_output=True)
        subprocess.run(["git", "pull", "--rebase", "--quiet"], cwd=repo_root, capture_output=True)

        # Run opencode with the agent and issue context as the message
        subprocess.run(
            ["opencode", "run", "--agent", "issue-worker",
             "--dangerously-skip-permissions",
             f"@{prompt_file}"],
            cwd=repo_root,
            check=False
        )
    finally:
        os.unlink(prompt_file)

    print(f"  -> Agent finished for issue #{num}", flush=True)

PYEOF
    rm -f "$ISSUES_TMP"
  fi

  echo "Sleeping ${POLL_SECONDS}s..."
  sleep "$POLL_SECONDS"
done

echo "=== Issue Loop exited after $iteration polls ==="
