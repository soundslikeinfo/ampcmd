#!/usr/bin/env fish
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

function chainhist --argument num_lines
    if not type -q fzf
        echo "Error: fzf is not installed. Please install it to use chainhist." >&2
        return 1
    end

    # Ensure history is synced
    history merge 2>/dev/null

    set -q num_lines[1]; or set num_lines 20

    # Determine preview script location
    set -l script_dir (dirname (status filename))
    set -l preview_cmd "env LC_ALL=C LC_CTYPE=C $script_dir/chainhist-preview.sh {+}"

    set -l history_items (history search | awk '!seen[$0]++' | head -n $num_lines)

    if not set -q history_items[1]
        echo "Error: Could not retrieve shell history. Run 'history search' to verify." >&2
        return 1
    end

    set -l fzf_tmp (mktemp /tmp/chainhist.XXXXXX)
    printf "%s\n" $history_items | \
        nl -w3 -s' │ ' | \
        fzf \
            --multi \
            --height=70% \
            --header="(set_color cyan)━━ chainhist ━━(set_color normal)\n(set_color yellow)TAB/SPACE = toggle selection(set_color normal)\n\n(set_color green)Select commands, then press:(set_color normal)\n(set_color white)  ENTER   → Execute immediately(set_color normal)\n(set_color white)  CTRL-Y  → Copy to clipboard(set_color normal)\n\n(set_color black)ESC = cancel(set_color normal)" \
            --expect=ctrl-y \
            --bind 'tab:toggle+down' \
            --bind 'space:toggle' \
            --bind 'shift-tab:toggle+up' \
            --bind 'ctrl-y:accept' \
            --prompt="Select commands > " \
            --preview "$preview_cmd" \
            --preview-window 'right:40%:border-left:wrap' \
            --preview-label=' Command Queue ' \
            --no-info > $fzf_tmp

    set -l fzf_output (cat $fzf_tmp)
    rm -f $fzf_tmp

    if test -z "$fzf_output"
        return 1
    end

    set key (echo $fzf_output[1])
    set selections (printf "%s\n" $fzf_output[2..-1] | sed 's/^[[:space:]]*[0-9]* │ //')

    if test -z "$selections"
        return 1
    end

    set chain ""
    set first true
    for cmd in $selections
        if test "$first" = true
            set chain "$cmd"
            set first false
        else
            set chain "$chain && $cmd"
        end
    end

    if test "$key" = "ctrl-y"
        if type -q pbcopy
            echo -n "$chain" | pbcopy
        else if type -q xclip
            echo -n "$chain" | xclip -selection clipboard
        else if type -q xsel
            echo -n "$chain" | xsel --clipboard
        else
            echo "Error: clipboard tool not found (pbcopy, xclip, or xsel required)" >&2
            return 1
        end
        echo "Copied to clipboard: $chain"
    else
        # If we are in a tty and not being captured, execute directly
        if status is-interactive
            commandline -r "$chain"
            commandline -f execute
        else
            echo "$chain"
        end
    end
end

# Keybinding helper for Fish
function __chainhist_widget
    chainhist 20
end

# Bind to CTRL-H if in interactive mode
if status is-interactive
    bind \ch __chainhist_widget
end
