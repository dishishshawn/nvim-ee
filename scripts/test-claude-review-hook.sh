#!/usr/bin/env bash
# Plays a Claude session through claude-review-hook.sh in a scratch repo and checks the index.
set -eu
hook="$(cd "$(dirname "$0")" && pwd)/claude-review-hook.sh"
repo=$(mktemp -d)
trap 'rm -rf "$repo"' EXIT
cd "$repo"
git init -q && git config user.email t@t && git config user.name t
printf '1\n2\n' >a.c && git add a.c && git commit -qm init

run() { printf '{"hook_event_name":"%s","tool_input":{"file_path":"%s"}}' "$1" "${2:-}" | NVIM= "$hook"; }
fails=0
check() {
	if eval "$2"; then
		echo "PASS $1"
	else
		echo "FAIL $1"
		fails=$((fails + 1))
	fi
}
diff_of() { git diff -- "$1" | grep '^[+-][^+-]' | tr '\n' ' '; }

echo user >>a.c # your own unstaged work
run PreToolUse "$repo/a.c"
echo claude1 >>a.c
run PostToolUse "$repo/a.c"
check "only Claude's edit is up for review" '[ "$(diff_of a.c)" = "+claude1 " ]'

run UserPromptSubmit
run PreToolUse "$repo/a.c" # Claude edits again before you reviewed
echo claude2 >>a.c
run PostToolUse "$repo/a.c"
check "unreviewed edits are never staged" '[ "$(diff_of a.c)" = "+claude1 +claude2 " ]'

run PreToolUse "$repo/b.c"
echo new >b.c
run PostToolUse "$repo/b.c"
run PreToolUse "$repo/b.c"
check "a new file shows as all added" '[ "$(diff_of b.c)" = "+new " ]'

git add a.c # accept everything in a.c
run UserPromptSubmit
echo user2 >>a.c # hand edit after the review
run PreToolUse "$repo/a.c"
check "after review, hand edits become the baseline" '[ -z "$(diff_of a.c)" ]'
check "b.c is still pending" 'grep -qxF "$repo/b.c" .git/claude-pending'

nogit=$(mktemp -d) && echo x >"$nogit/c.c"
out=$(run PreToolUse "$nogit/c.c")
rm -rf "$nogit"
check "outside git, Claude asks before editing" 'jq -e ".hookSpecificOutput.permissionDecision == \"ask\"" <<<"$out" >/dev/null'

[ "$fails" -eq 0 ] && echo "ALL PASS"
exit "$fails"
