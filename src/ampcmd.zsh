#!/usr/bin/env zsh
# ampcmd - Chain multiple history commands with &&
# Usage: ampcmd [N] - show last N commands (default 20)
#        ampcmd -l  - list chain history
#
# WORKFLOW:
#   1. fzf opens showing recent commands
#   2. TAB or SPACE to toggle selection (select multiple!)
#   3. Press key for action:
#      - ENTER: Execute immediately
#      - CTRL-Y: Copy to clipboard
#   4. Commands chain in LIST ORDER (top = first)

# Use the plugin directory if available, otherwise determine from this file
if [[ -n "${_ampcmd_plugin_dir}" ]]; then
    _ampcmd_script_dir="${_ampcmd_plugin_dir}"
else
    _ampcmd_script_dir="${0:A:h}"
fi

# Config and history paths
_CHAINHIST_CONFIG="${HOME}/.config/ampcmd/config"
_CHAINHIST_HISTORY="${HOME}/.ampcmd_history"
[[ -f "${HOME}/.ampcmd.conf" ]] && _CHAINHIST_CONFIG="${HOME}/.ampcmd.conf"

_ampcmd_config_get() {
    local key="$1" default="${2:-}"
    [[ -f "$_CHAINHIST_CONFIG" ]] || { echo "$default"; return; }
    local value
    value=$(grep "^${key}=" "$_CHAINHIST_CONFIG" 2>/dev/null | tail -1 | cut -d'=' -f2-)
    echo "${value:-$default}"
}

_ampcmd_source_before_exec() {
    local files
    files="$(_ampcmd_config_get SOURCE_BEFORE_EXEC)"
    [[ -z "$files" ]] && return
    local f
    while IFS= read -r f; do
        f="${f/#\~/$HOME}"
        # shellcheck source=/dev/null
        [[ -f "$f" ]] && source "$f" 2>/dev/null || true
    done < <(printf '%s' "$files" | tr ':' '\n')
}

_ampcmd_read_config() {
    local disallow_history="false"
    if [[ -f "$_CHAINHIST_CONFIG" ]]; then
        # shellcheck source=/dev/null
        source "$_CHAINHIST_CONFIG" 2>/dev/null || true
        grep -q "^DISALLOW_HISTORY=true" "$_CHAINHIST_CONFIG" && disallow_history="true"
    fi
    echo "$disallow_history"
}

_ampcmd_record_history() {
    local chain="$1"
    local disallow
    disallow="$(_ampcmd_read_config)"
    if [[ "$disallow" != "true" ]]; then
        local timestamp
        timestamp=$(date +"%Y-%m-%d %H:%M:%S")
        echo "${timestamp} │ ${chain}" >> "$_CHAINHIST_HISTORY"
    fi
}

ampcmd() {
    if ! command -v fzf &>/dev/null; then
        echo "Error: fzf is not installed. Please install it to use ampcmd." >&2
        return 1
    fi

    # Handle -l/--list flag
    if [[ "$1" == "-l" ]] || [[ "$1" == "--list" ]]; then
        if [[ ! -f "$_CHAINHIST_HISTORY" ]]; then
            echo "No chain history found. Run ampcmd to create some chains first." >&2
            return 1
        fi

        local history_selection
        history_selection=$(tac "$_CHAINHIST_HISTORY" | \
            fzf \
                --height=70% \
                --header="$(echo -e '\033[1;36m━━ ampcmd history ━━\033[0m\n\033[1;33mSelect a chain to run\033[0m')" \
                --expect=ctrl-y \
                --bind 'ctrl-y:accept' \
                --bind 'start:first' \
                --prompt="Select from history > " \
                --no-preview \
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
            { echo "clipboard not available" && return 1; }
            echo "Copied to clipboard: $chain"
        else
            if [[ "$(_ampcmd_config_get SHOW_FULL_AMPCMD true)" == "true" ]]; then
                local divider_style
                divider_style="$(_ampcmd_config_get AMPCMD_DIVIDER dashed)"
                local term_width divider_width width
                term_width=$(tput cols 2>/dev/null) || term_width=${COLUMNS:-80}
                divider_width="$(_ampcmd_config_get AMPCMD_DIVIDER_WIDTH full)"
                case "$divider_width" in
                    half) width=$(( term_width / 2 )) ;;
                    full) width=$term_width ;;
                    *)    width=${divider_width:-$term_width} ;;
                esac
                echo "$chain"
                if [[ "$divider_style" == "solid" ]]; then
                    # shellcheck disable=SC2051,SC2086
                    printf '─%.0s' {1..$width}; echo
                else
                    # shellcheck disable=SC2051,SC2086
                    printf -- '-%.0s' {1..$width}; echo
                fi
            fi
            _ampcmd_source_before_exec
            eval "$chain"
        fi
        return 0
    fi

    local num_lines="${1:-20}"
    local output_only="${2:-}"

    # Preview script: calls external script to avoid shell quoting issues
    local preview_cmd="\"${_ampcmd_script_dir}/ampcmd-preview.sh\" {+}"

    # In non-interactive shells (called via wrapper), fc has no history loaded.
    # Explicitly read the history file so fc has data to work with.
    fc -R "${HISTFILE:-$HOME/.zsh_history}" 2>/dev/null

    # Pre-generate both datasets so CTRL-L can reload without leaving fzf
    local hist_tmp chains_tmp
    hist_tmp=$(mktemp /tmp/ampcmd_hist.XXXXXX)
    chains_tmp=$(mktemp /tmp/ampcmd_chains.XXXXXX)
    fc -ln -"$num_lines" 2>/dev/null | awk '!seen[$0]++' | tail -n "$num_lines" | tac | nl -w3 -s' │ ' > "$hist_tmp"
    [[ -f "$_CHAINHIST_HISTORY" ]] && tac "$_CHAINHIST_HISTORY" | sed 's/^[0-9-]* [0-9:]* │ //' | nl -w3 -s' │ ' > "$chains_tmp"

    local fzf_output
    fzf_output=$(cat "$hist_tmp" | \
        fzf \
            --multi \
            --height=70% \
            --header="$(echo -e '\033[1;36m━━ ampcmd ━━\033[0m\n\033[1;33mTAB/SPACE toggle  │  ENTER = Run  │  CTRL-Y = Copy  │  CTRL-R = Clear  │  CTRL-L = Chains  │  ESC cancel\033[0m')" \
            --expect=ctrl-y \
            --bind 'tab:toggle+down' \
            --bind 'space:toggle' \
            --bind 'shift-tab:toggle+up' \
            --bind 'right:select+down' \
            --bind 'left:deselect' \
            --bind 'ctrl-r:deselect-all' \
            --bind "ctrl-l:transform:if [ \"\${FZF_PROMPT}\" = 'history > ' ]; then echo \"reload(cat ${chains_tmp})+change-prompt(chains > )+change-preview-label( Chain History )\"; else echo \"reload(cat ${hist_tmp})+change-prompt(history > )+change-preview-label( Command Queue )\"; fi" \
            --bind 'ctrl-y:accept' \
            --bind 'start:first' \
            --prompt="history > " \
            --preview "$preview_cmd" \
            --preview-window 'right:40%:border-left:wrap' \
            --preview-label=' Command Queue ' \
            --no-info 2>/dev/null)

    rm -f "$hist_tmp" "$chains_tmp"

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
            { echo "clipboard not available" && return 1; }
            echo "Copied to clipboard: $chain"
            _ampcmd_record_history "$chain"
        else
            # Execute the chain
            if [[ "$(_ampcmd_config_get SHOW_FULL_AMPCMD true)" == "true" ]]; then
                local divider_style
                divider_style="$(_ampcmd_config_get AMPCMD_DIVIDER dashed)"
                local term_width divider_width width
                term_width=$(tput cols 2>/dev/null) || term_width=${COLUMNS:-80}
                divider_width="$(_ampcmd_config_get AMPCMD_DIVIDER_WIDTH full)"
                case "$divider_width" in
                    half) width=$(( term_width / 2 )) ;;
                    full) width=$term_width ;;
                    *)    width=${divider_width:-$term_width} ;;
                esac
                echo "$chain"
                if [[ "$divider_style" == "solid" ]]; then
                    # shellcheck disable=SC2051,SC2086
                    printf '─%.0s' {1..$width}; echo
                else
                    # shellcheck disable=SC2051,SC2086
                    printf -- '-%.0s' {1..$width}; echo
                fi
            fi
            _ampcmd_source_before_exec
            eval "$chain"
            _ampcmd_record_history "$chain"
        fi
    fi
}

# If run directly (not sourced), execute the function
# This allows: zsh ~/.local/share/ampcmd/libexec/ampcmd.zsh 20
# Check if being sourced by plugin vs run directly
if [[ "${0:t}" == "ampcmd.zsh" ]] && [[ -z "${_ampcmd_plugin_dir}" ]]; then
    ampcmd "$@"
fi