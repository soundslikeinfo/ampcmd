#!/usr/bin/env zsh
# ampcmd.plugin.zsh - Load this file in your .zshrc for zsh integration
#
# Installation:
#   Add to ~/.zshrc:
#     source /path/to/ampcmd.plugin.zsh
#
# Or use a plugin manager (antidote, zinit, etc.):
#   antidote bundle YOUR/ampcmd

local _ampcmd_plugin_dir="${0:A:h}"

source "$_ampcmd_plugin_dir/ampcmd.zsh"

_ampcmd_widget() {
    local output
    output=$(ampcmd 20 1)

    if [[ -z "$output" ]]; then
        return 1
    fi

    local key chain
    key=$(echo "$output" | head -n1)
    chain=$(echo "$output" | tail -n +2)

    case "$key" in
        ctrl-y)
            echo -n "$chain" | pbcopy 2>/dev/null || \
            echo -n "$chain" | xclip -selection clipboard 2>/dev/null || \
            echo -n "$chain" | xsel --clipboard 2>/dev/null || \
            { echo "clipboard not available" && return 1 }
            zle -M "Copied to clipboard: $chain"
            ;;
        *)
            print -s "$chain"
            LBUFFER="$chain"
            zle reset-prompt
            zle accept-line
            ;;
    esac
}

zle -N _ampcmd_widget
bindkey '^H' _ampcmd_widget