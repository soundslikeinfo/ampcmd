#!/usr/bin/env bash
# chainhist - Chain multiple history commands with &&
# Usage: chainhist [N] - show last N commands (default 20)
#
# WORKFLOW:
#   1. fzf opens showing recent commands
#   2. TAB or SPACE to toggle selection (select multiple!)
#   3. Press key for action:
#      - ENTER: Execute immediately
#      - CTRL-Y: Copy to clipboard
#   4. Commands chain in LIST ORDER (top = first)

chainhist() {
	if ! command -v fzf &>/dev/null; then
		echo "Error: fzf is not installed. Please install it to use chainhist." >&2
		return 1
	fi

	local num_lines="${1:-20}"
	local output_only="${2:-0}"

	# Determine script directory
	local script_dir
	script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
	local preview_cmd="env LC_ALL=C LC_CTYPE=C \"$script_dir/chainhist-preview.sh\" {+}"

	local fzf_output
	fzf_output=$(history |
		tail -n "$num_lines" |
		awk '{for(i=2;i<=NF;i++) printf "%s ", $i; print ""}' |
		awk '!seen[$0]++' |
		nl -w3 -s' │ ' |
		fzf \
			--multi \
			--tac \
			--height=70% \
			--header=$'\033[1;36m━━ chainhist ━━\033[0m\n\033[1;33mTAB/SPACE = toggle selection\033[0m\n\n\033[1;32mSelect commands, then press:\033[0m\n\033[1;37m  ENTER   → Execute immediately\033[0m\n\033[1;37m  CTRL-Y  → Copy to clipboard\033[0m\n\n\033[90mESC = cancel\033[0m' \
			--expect=ctrl-y \
			--bind 'tab:toggle+down' \
			--bind 'space:toggle' \
			--bind 'shift-tab:toggle+up' \
			--bind 'right:select+down' \
			--bind 'left:deselect' \
			--bind 'ctrl-y:accept' \
			--prompt="Select commands > " \
			--preview "$preview_cmd" \
			--preview-window 'right:40%:border-left:wrap' \
			--preview-label=' Command Queue ' \
			--no-info 2>/dev/null)

	if [[ -z "$fzf_output" ]]; then
		return 1
	fi

	local key selections
	key=$(echo "$fzf_output" | head -n1)
	selections=$(echo "$fzf_output" | tail -n +2 | sed 's/^[[:space:]]*[0-9]* │ //')

	if [[ -z "$selections" ]]; then
		return 1
	fi

	local chain=""
	local first=true
	while IFS= read -r cmd; do
		if $first; then
			chain="$cmd"
			first=false
		else
			chain="$chain && $cmd"
		fi
	done <<<"$selections"

	if [[ "$output_only" == "1" ]]; then
		echo "$key"$'\n'"$chain"
	else
		if [[ "$key" == "ctrl-y" ]]; then
			if command -v pbcopy &>/dev/null; then
				echo -n "$chain" | pbcopy
			elif command -v xclip &>/dev/null; then
				echo -n "$chain" | xclip -selection clipboard
			elif command -v xsel &>/dev/null; then
				echo -n "$chain" | xsel --clipboard
			else
				echo "Error: clipboard tool not found" >&2
				return 1
			fi
			echo "Copied to clipboard: $chain"
		else
			eval "$chain"
		fi
	fi
}

# Bind to CTRL-H if running interactively
if [[ -n "$BASH_VERSION" ]] && [[ -o interactive ]]; then
	_chainhist_widget() {
		local output
		output=$(chainhist 20 1)

		if [[ -z "$output" ]]; then
			return 1
		fi

		local key chain
		key=$(echo "$output" | head -n1)
		chain=$(echo "$output" | tail -n +2)

		case "$key" in
		ctrl-y)
			if command -v pbcopy &>/dev/null; then
				echo -n "$chain" | pbcopy
			elif command -v xclip &>/dev/null; then
				echo -n "$chain" | xclip -selection clipboard
			elif command -v xsel &>/dev/null; then
				echo -n "$chain" | xsel --clipboard
			else
				echo "clipboard not available" >&2
				return 1
			fi
			READLINE_LINE="# Copied to clipboard"
			READLINE_POINT=21
			;;
		*)
			# Execute in bash by putting it on the line and letting the user press enter,
			# or we can use a trick to run it immediately.
			# For Bash, standard behavior for widgets is to fill the line.
			# However, if the user wants "no other steps", we can try:
			READLINE_LINE="$chain"
			READLINE_POINT=${#chain}
			# To execute automatically in bash, we'd need to send a literal carriage return.
			# This is difficult without external tools.
			# Most bash widgets just populate the prompt.
			;;
		esac
	}
	bind -x '"\C-h": _chainhist_widget'
fi
