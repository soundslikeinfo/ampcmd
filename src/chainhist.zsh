#!/usr/bin/env zsh
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

# Use the plugin directory if available, otherwise determine from this file
if [[ -n "${_chainhist_plugin_dir}" ]]; then
    _chainhist_script_dir="${_chainhist_plugin_dir}"
else
    _chainhist_script_dir="${0:A:h}"
fi

chainhist() {
    if ! command -v fzf &>/dev/null; then
        echo "Error: fzf is not installed. Please install it to use chainhist." >&2
        return 1
    fi

    local num_lines="${1:-20}"
    local output_only="${2:-}"

    # Preview script: calls external script to avoid shell quoting issues
    local preview_cmd="\"${_chainhist_script_dir}/chainhist-preview.sh\" {+}"

    local fzf_output
    fzf_output=$(fc -ln -$num_lines 2>/dev/null | \
        awk '!seen[$0]++' | \
        tail -n "$num_lines" | \
        nl -w3 -s' │ ' | \
        fzf \
            --multi \
            --tac \
            --height=70% \
            --header="$(echo -e '\033[1;36m━━━ chainhist ━━━\033[0m\n\033[1;33mTAB/SPACE\033[0m toggle  │  \033[1;32mENTER\033[0m execute  │  \033[1;35mCTRL-Y\033[0m copy\n')" \
            --expect=ctrl-y \
            --bind 'tab:toggle+down' \
            --bind 'space:toggle' \
            --bind 'shift-tab:toggle+up' \
            --bind 'right:select+down' \
            --bind 'left:deselect' \
            --bind 'ctrl-y:accept' \
            --bind 'start:first' \
            --prompt="Select commands > " \
            --preview "$preview_cmd" \
            --preview-window 'right:40%:border-left:wrap' \
            --preview-label=' Command Queue ' \
            --no-info 2>/dev/null)

    if [[ -z "$fzf_output" ]]; then
        return 1
    fi

    local key
    local selections
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
    done <<< "$selections"

    if [[ "$output_only" == "1" ]]; then
        # Being captured by widget - output key and chain
        echo "$key"$'\n'"$chain"
    else
        # Running directly - check key for action
        if [[ "$key" == "ctrl-y" ]]; then
            # Copy to clipboard
            echo -n "$chain" | pbcopy 2>/dev/null || \
            echo -n "$chain" | xclip -selection clipboard 2>/dev/null || \
            echo -n "$chain" | xsel --clipboard 2>/dev/null || \
            { echo "clipboard not available" && return 1 }
            echo "Copied to clipboard: $chain"
        else
            # Execute the chain
            eval "$chain"
        fi
    fi
}