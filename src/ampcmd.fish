#!/usr/bin/env fish
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

# Config and history paths
set -l config_file "$HOME/.config/ampcmd/config"
set -l history_file "$HOME/.ampcmd_history"
if test -f "$HOME/.ampcmd.conf"
    set config_file "$HOME/.ampcmd.conf"
end

function _ampcmd_read_config
    set -l config_file "$HOME/.config/ampcmd/config"
    if test -f "$HOME/.ampcmd.conf"
        set config_file "$HOME/.ampcmd.conf"
    end
    
    set -l disallow_history "false"
    if test -f "$config_file"
        if grep -q "^DISALLOW_HISTORY=true" "$config_file"
            set disallow_history "true"
        end
    end
    echo "$disallow_history"
end

function _ampcmd_record_history --argument chain
    set -l disallow (_ampcmd_read_config)
    if test "$disallow" != "true"
        set -l timestamp (date +"%Y-%m-%d %H:%M:%S")
        echo "$timestamp │ $chain" >> "$HOME/.ampcmd_history"
    end
end

function ampcmd --argument num_lines
    if not type -q fzf
        echo "Error: fzf is not installed. Please install it to use ampcmd." >&2
        return 1
    end

    # Handle -l/--list flag
    if test "$num_lines" = "-l"; or test "$num_lines" = "--list"
        if not test -f "$HOME/.ampcmd_history"
            echo "No chain history found. Run ampcmd to create some chains first." >&2
            return 1
        end

        set -l script_dir (dirname (status filename))
        set -l preview_cmd "env LC_ALL=C LC_CTYPE=C $script_dir/ampcmd-preview.sh {+}"

        set -l history_tmp (mktemp /tmp/ampcmd.XXXXXX)
        tac "$HOME/.ampcmd_history" | \
            fzf \
                --height=70% \
                --header='━━ ampcmd history ━━
Select a chain to run' \
            fzf \
                --height=70% \
                --header="$header_str" \
                --expect=ctrl-y \
                --bind 'ctrl-y:accept' \
                --bind 'start:first' \
                --prompt="Select from history > " \
                --preview "$preview_cmd" \
                --preview-window 'right:40%:border-left:wrap' \
                --preview-label=' Command ' \
                --no-info > $history_tmp

        set -l fzf_output (cat $history_tmp)
        rm -f $history_tmp

        if test -z "$fzf_output"
            return 1
        end

        set key (echo $fzf_output[1])
        set chain (printf "%s\n" $fzf_output[2..-1] | sed 's/^[0-9-]* [0-9:]* │ //')

        if test -z "$chain"
            return 1
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
        return 0
    end

    # Ensure history is synced
    history merge 2>/dev/null

    set -q num_lines[1]; or set num_lines 20

    # Determine preview script location
    set -l script_dir (dirname (status filename))
    set -l preview_cmd "env LC_ALL=C LC_CTYPE=C $script_dir/ampcmd-preview.sh {+}"

    set -l history_items (history search | awk '!seen[$0]++' | head -n $num_lines)

    if not set -q history_items[1]
        echo "Error: Could not retrieve shell history. Run 'history search' to verify." >&2
        return 1
    end

    set -l fzf_tmp (mktemp /tmp/ampcmd.XXXXXX)
    printf "%s\n" $history_items | \
        nl -w3 -s' │ ' | \
        fzf \
            --multi \
            --height=70% \
            --header='━━ ampcmd ━━
TAB/SPACE toggle  |  ENTER = Run  |  CTRL-Y = Copy  |  ESC cancel' \
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
        _ampcmd_record_history "$chain"
    else
        # If we are in a tty and not being captured, execute directly
        if status is-interactive
            commandline -r "$chain"
            commandline -f execute
        else
            echo "$chain"
        end
        _ampcmd_record_history "$chain"
    end
end

# Keybinding helper for Fish
function __ampcmd_widget
    ampcmd 20
end

# Bind to CTRL-H if in interactive mode
if status is-interactive
    bind \ch __ampcmd_widget
end

# If run directly (not sourced), execute the function
# This allows: fish ~/.local/share/ampcmd/libexec/ampcmd.fish 20
# status current-command returns the script path when run directly
if string match -q '*ampcmd.fish' (status current-command)
    ampcmd $argv
end
