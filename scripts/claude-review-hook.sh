#!/usr/bin/env bash
# Claude Code hook behind the Cursor-style review (wired up in lua/plugins/claude.lua).
# Before Claude first edits a file, its current content is staged, so the git index holds the
# "before" version and Claude's edits show up as unstaged hunks: accept = stage, reject = reset.
# Outside git there is nothing to review against afterwards, so Claude has to ask before each edit
# instead, which shows the edit as a diff in Neovim.
in=$(cat)
event=$(jq -r .hook_event_name <<<"$in")
f=$(jq -r '.tool_input.file_path // empty' <<<"$in")
# reload the file in the Neovim this Claude runs in, so the change shows while Claude works
[ "$event" = PostToolUse ] && [ -n "$NVIM" ] &&
	timeout 2 nvim --server "$NVIM" --remote-expr 'execute("checktime")' >/dev/null 2>&1
[ -n "$f" ] && { cd "$(dirname "$f")" 2>/dev/null || exit 0; } # the file's own repo (submodules too)
if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
	[ "$event" = PreToolUse ] &&
		echo '{"hookSpecificOutput":{"hookEventName":"PreToolUse","permissionDecision":"ask"}}'
	exit 0
fi
list="$(git rev-parse --absolute-git-dir)/claude-pending" # files holding unreviewed Claude edits
pending() { grep -qxF -- "$1" "$list" 2>/dev/null && ! git diff --quiet -- "$1" 2>/dev/null; }

case $event in
UserPromptSubmit) # forget fully reviewed files, so hand edits made there later get staged again
	[ -f "$list" ] || exit 0
	while IFS= read -r p; do pending "$p" && echo "$p"; done <"$list" >"$list.new"
	mv "$list.new" "$list"
	;;
PreToolUse) # snapshot the "before" state, unless the file already holds unreviewed Claude edits
	[ -e "$f" ] && ! pending "$f" || exit 0
	git add -- "$f" 2>/dev/null && { grep -qxF -- "$f" "$list" 2>/dev/null || echo "$f" >>"$list"; }
	;;
PostToolUse)
	# a new file goes in as intent-to-add, so it shows up as one all-added hunk
	git ls-files --error-unmatch -- "$f" >/dev/null 2>&1 ||
		{ git add -N -- "$f" 2>/dev/null && echo "$f" >>"$list"; }
	;;
esac
exit 0
