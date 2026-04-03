#!/usr/bin/env bash
# chainhist - Chain multiple history commands with &&
# Usage: chainhist [N] - show last N commands (default 20)
#        chainhist -l  - list chain history
#
# WORKFLOW:
#   1. fzf opens showing recent commands
#   2. TAB or SPACE to toggle selection (select multiple!)
#   3. Press key for action:
#      - ENTER: Execute immediately
#      - CTRL-Y: Copy to clipboard
#   4. Commands chain in LIST ORDER (top = first)

# Config and history paths
_CHAINHIST_CONFIG="${HOME}/.config/chainhist/config"
_CHAINHIST_HISTORY="${HOME}/.chainhist_history"
[[ -f "${HOME}/.chainhist.conf" ]] && _CHAINHIST_CONFIG="${HOME}/.chainhist.conf"

_chainhist_read_config() {
	local disallow_history="false"
	if [[ -f "$_CHAINHIST_CONFIG" ]]; then
		grep -q "^DISALLOW_HISTORY=true" "$_CHAINHIST_CONFIG" && disallow_history="true"
	fi
	echo "$disallow_history"
}

_chainhist_record_history() {
	local chain="$1"
	local disallow="$(_chainhist_read_config)"
	if [[ "$disallow" != "true" ]]; then
		local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
		echo "${timestamp} │ ${chain}" >>"$_CHAINHIST_HISTORY"
	fi
}

chainhist() {
	if ! command -v fzf &>/dev/null; then
		echo "Error: fzf is not installed. Please install it to use chainhist." >&2
		return 1
	fi

	# Handle -l/--list flag
	if [[ "$1" == "-l" ]] || [[ "$1" == "--list" ]]; then
		if [[ ! -f "$_CHAINHIST_HISTORY" ]]; then
			echo "No chain history found. Run chainhist to create some chains first." >&2
			return 1
		fi

		local script_dir
		script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
		local preview_cmd="env LC_ALL=C LC_CTYPE=C \"$script_dir/chainhist-preview.sh\" {+}"

		local history_selection
		history_selection=$(tac "$_CHAINHIST_HISTORY" |
			fzf \
				--height=70% \
				--header=$'\033[1;36m━━ chainhist history ━━\033[0m\n\033[1;33mSelect a chain to run\033[0m' \
				--expect=ctrl-y \
				--bind 'ctrl-y:accept' \
				--bind 'start:first' \
				--prompt="Select from history > " \
				--preview "$preview_cmd" \
				--preview-window 'right:40%:border-left:wrap' \
				--preview-label=' Command ' \
				--no-info 2>/dev/null)

		if [[ -z "$history_selection" ]]; then
			return 1
		fi

		local key chain
		key=$(echo "$history_selection" | head -n1)
		chain=$(echo "$history_selection" | tail -n +2 | sed 's/^[0-9-]* [0-9:]* │ //')

		if [[ -z "$chain" ]]; then
			return 1
		fi

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
		return 0
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
			--header=$'\033[1;36m━━ chainhist ━━\033[0m\n\033[1;33mTAB/SPACE toggle  │  ENTER = Run  │  CTRL-Y = Copy  │  ESC cancel\033[0m' \
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
			_chainhist_record_history "$chain"
		else
			eval "$chain"
			_chainhist_record_history "$chain"
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
