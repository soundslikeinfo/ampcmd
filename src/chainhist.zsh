#!/usr/bin/env zsh
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

# Use the plugin directory if available, otherwise determine from this file
if [[ -n "${_chainhist_plugin_dir}" ]]; then
    _chainhist_script_dir="${_chainhist_plugin_dir}"
else
    _chainhist_script_dir="${0:A:h}"
fi

# Config and history paths
_CHAINHIST_CONFIG="${HOME}/.config/chainhist/config"
_CHAINHIST_HISTORY="${HOME}/.chainhist_history"
[[ -f "${HOME}/.chainhist.conf" ]] && _CHAINHIST_CONFIG="${HOME}/.chainhist.conf"

_chainhist_read_config() {
    local disallow_history="false"
    if [[ -f "$_CHAINHIST_CONFIG" ]]; then
        source "$_CHAINHIST_CONFIG" 2>/dev/null || true
        grep -q "^DISALLOW_HISTORY=true" "$_CHAINHIST_CONFIG" && disallow_history="true"
    fi
    echo "$disallow_history"
}

_chainhist_record_history() {
    local chain="$1"
    local disallow="$(_chainhist_read_config)"
    if [[ "$disallow" != "true" ]]; then
        local timestamp=$(date +"%Y-%m-%d %H:%M:%S")
        echo "${timestamp} │ ${chain}" >> "$_CHAINHIST_HISTORY"
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

        local preview_cmd="\"${_chainhist_script_dir}/chainhist-preview.sh\" {+}"
        local history_selection
        history_selection=$(tac "$_CHAINHIST_HISTORY" | \
            fzf \
                --height=70% \
                --header="$(echo -e '\033[1;36m━━ chainhist history ━━\033[0m\n\033[1;33mSelect a chain to run\033[0m')" \
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

        local key
        local chain
        key=$(echo "$history_selection" | head -n1)
        chain=$(echo "$history_selection" | tail -n +2 | sed 's/^[0-9-]* [0-9:]* │ //')

        if [[ -z "$chain" ]]; then
            return 1
        fi

        if [[ "$key" == "ctrl-y" ]]; then
            echo -n "$chain" | pbcopy 2>/dev/null || \
            echo -n "$chain" | xclip -selection clipboard 2>/dev/null || \
            echo -n "$chain" | xsel --clipboard 2>/dev/null || \
            { echo "clipboard not available" && return 1 }
            echo "Copied to clipboard: $chain"
        else
            eval "$chain"
        fi
        return 0
    fi

    local num_lines="${1:-20}"
    local output_only="${2:-}"

    # Preview script: calls external script to avoid shell quoting issues
    local preview_cmd="\"${_chainhist_script_dir}/chainhist-preview.sh\" {+}"

    local fzf_output
    fzf_output=$(fc -ln -$num_lines 2>/dev/null | \
        awk '!seen[$0]++' | \
        tail -n "$num_lines" | \
        tac | \
        nl -w3 -s' │ ' | \
        fzf \
            --multi \
            --height=70% \
            --header="$(echo -e '\033[1;36m━━ chainhist ━━\033[0m\n\033[1;33mTAB/SPACE toggle  │  ENTER = Run  │  CTRL-Y = Copy  │  ESC cancel\033[0m')" \
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
            _chainhist_record_history "$chain"
        else
            # Execute the chain
            eval "$chain"
            _chainhist_record_history "$chain"
        fi
    fi
}