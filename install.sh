#!/usr/bin/env bash
# install.sh - Install ampcmd for your shell
# Usage: curl -sSL https://raw.githubusercontent.com/soundslikeinfo/ampcmd/main/install.sh | bash
#
# Auto-detects shell (zsh/fish/bash) and installs appropriate version.
# Supports: macOS (Homebrew), Linux (Debian/Ubuntu/Arch/Fedora)

set -e

REPO_URL="https://github.com/soundslikeinfo/ampcmd"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/share/ampcmd}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

info() { echo -e "${CYAN}➜${NC} $1"; }
success() { echo -e "${GREEN}✓${NC} $1"; }
warn() { echo -e "${YELLOW}!${NC} $1"; }
error() {
	echo -e "${RED}✗${NC} $1"
	exit 1
}

cleanup() {
	warn "Installation failed. Cleaning up..."
	[[ -n "$INSTALL_DIR" ]] && rm -rf "$INSTALL_DIR" 2>/dev/null || true
}

trap cleanup ERR

detect_shell() {
	local shell_name=""

	# Check $SHELL first
	if [[ -n "$SHELL" ]]; then
		shell_name=$(basename "$SHELL")
	fi

	# Fallback to checking running processes
	if [[ -z "$shell_name" ]]; then
		if pgrep -x "zsh" >/dev/null; then
			shell_name="zsh"
		elif pgrep -x "fish" >/dev/null; then
			shell_name="fish"
		else
			shell_name="bash"
		fi
	fi

	echo "$shell_name"
}

check_dependencies() {
	info "Checking dependencies..."

	# Check for fzf
	if ! command -v fzf >/dev/null 2>&1; then
		warn "fzf not found. Install with:"
		echo "  macOS:   brew install fzf"
		echo "  Debian:  sudo apt install fzf"
		echo "  Arch:    sudo pacman -S fzf"
		echo "  Fedora:  sudo dnf install fzf"
		echo ""
		error "fzf is required. Aborting."
	fi
	success "fzf found: $(command -v fzf)"

	# Check for curl or wget
	if command -v curl >/dev/null 2>&1; then
		FETCH_CMD="curl -fsSL"
		success "curl found"
	elif command -v wget >/dev/null 2>&1; then
		FETCH_CMD="wget -qO-"
		success "wget found"
	else
		error "curl or wget is required"
	fi
}

download_file() {
	local url="$1"
	local dest="$2"

	info "Downloading $url..."
	if ! $FETCH_CMD "$url" >"$dest" 2>/dev/null; then
		error "Failed to download $url"
	fi

	if [[ ! -s "$dest" ]]; then
		error "Downloaded file is empty: $dest"
	fi

	success "Downloaded: $(basename "$dest")"
}

install_zsh() {
	info "Installing for zsh..."

	mkdir -p "$INSTALL_DIR/zsh"

	# Download zsh version and preview script
	download_file "$REPO_URL/raw/main/src/ampcmd.zsh" "$INSTALL_DIR/zsh/ampcmd.zsh"
	download_file "$REPO_URL/raw/main/src/ampcmd-preview.sh" "$INSTALL_DIR/zsh/ampcmd-preview.sh"
	chmod +x "$INSTALL_DIR/zsh/ampcmd-preview.sh"

	# Create plugin file
	cat >"$INSTALL_DIR/zsh/ampcmd.plugin.zsh" <<'PLUGIN'
# ampcmd - Chain multiple history commands
local _ampcmd_dir="${0:A:h}"
source "$_ampcmd_dir/ampcmd.zsh"

_ampcmd_widget() {
    local selected
    selected=$(ampcmd 20)
    if [[ -n "$selected" ]]; then
        LBUFFER="$selected"
        zle reset-prompt
    fi
}

zle -N _ampcmd_widget
bindkey '^H' _ampcmd_widget
PLUGIN

	# Add to zshrc if not already present
	local zshrc="${ZDOTDIR:-$HOME}/.zshrc"
	local source_line="[ -f $INSTALL_DIR/zsh/ampcmd.plugin.zsh ] && source $INSTALL_DIR/zsh/ampcmd.plugin.zsh"

	if ! grep -q "ampcmd.plugin.zsh" "$zshrc" 2>/dev/null; then
		echo "" >>"$zshrc"
		echo "# ampcmd - history chaining" >>"$zshrc"
		echo "$source_line" >>"$zshrc"
		success "Added to $zshrc"
	else
		success "Already configured in $zshrc"
	fi

	success "zsh installation complete"
}

install_fish() {
	info "Installing for fish..."

	mkdir -p "$INSTALL_DIR/fish"
	mkdir -p "$HOME/.config/fish/functions"

	# Download fish version and preview script
	download_file "$REPO_URL/raw/main/src/ampcmd.fish" "$INSTALL_DIR/fish/ampcmd.fish"
	download_file "$REPO_URL/raw/main/src/ampcmd-preview.sh" "$INSTALL_DIR/fish/ampcmd-preview.sh"
	chmod +x "$INSTALL_DIR/fish/ampcmd-preview.sh"

	# Copy to fish functions directory
	cp "$INSTALL_DIR/fish/ampcmd.fish" "$HOME/.config/fish/functions/ampcmd.fish"
	cp "$INSTALL_DIR/fish/ampcmd-preview.sh" "$HOME/.config/fish/functions/ampcmd-preview.sh"

	# Add key binding
	local fish_conf="$HOME/.config/fish/config.fish"
	mkdir -p "$(dirname "$fish_conf")"

	if ! grep -q "ampcmd" "$fish_conf" 2>/dev/null; then
		cat >>"$fish_conf" <<'FISHBIND'

# ampcmd - CTRL-H keybinding
function fish_user_key_bindings
    bind \ch 'ampcmd | begin; read -l key; read -l cmd; and begin; switch "$key"; case ctrl-y; echo -n "$cmd" | pbcopy; or echo -n "$cmd" | xclip -selection clipboard; or echo -n "$cmd" | xsel --clipboard; echo "Copied to clipboard"; case "*"; commandline -- "$cmd"; commandline -f execute; end; end; end'
end
FISHBIND
		success "Added CTRL-H binding to $fish_conf"
	else
		success "Already configured in $fish_conf"
	fi

	success "fish installation complete"
}

install_bash() {
	info "Installing for bash..."

	mkdir -p "$INSTALL_DIR/bash"

	# Download bash version and preview script
	download_file "$REPO_URL/raw/main/src/ampcmd.bash" "$INSTALL_DIR/bash/ampcmd.bash"
	download_file "$REPO_URL/raw/main/src/ampcmd-preview.sh" "$INSTALL_DIR/bash/ampcmd-preview.sh"
	chmod +x "$INSTALL_DIR/bash/ampcmd-preview.sh"

	# Add to bashrc
	local bashrc="$HOME/.bashrc"
	local source_line="[ -f $INSTALL_DIR/bash/ampcmd.bash ] && source $INSTALL_DIR/bash/ampcmd.bash"

	if ! grep -q "ampcmd.bash" "$bashrc" 2>/dev/null; then
		echo "" >>"$bashrc"
		echo "# ampcmd - history chaining" >>"$bashrc"
		echo "$source_line" >>"$bashrc"
		success "Added to $bashrc"
	else
		success "Already configured in $bashrc"
	fi

	success "bash installation complete"
}

install_all() {
	info "Installing for all shells..."
	install_zsh
	install_fish
	install_bash
}

# Main
main() {
	echo ""
	echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
	echo -e "${CYAN}║        ampcmd installer             ║${NC}"
	echo -e "${CYAN}║    Chain history commands with &&      ║${NC}"
	echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"
	echo ""

	check_dependencies

	# Determine install target
	local target_shell="${1:-$(detect_shell)}"

	case "$target_shell" in
	zsh)
		install_zsh
		;;
	fish)
		install_fish
		;;
	bash)
		install_bash
		;;
	all)
		install_all
		;;
	*)
		warn "Unknown shell: $target_shell"
		info "Supported shells: zsh, fish, bash, all"
		info "Usage: $0 [zsh|fish|bash|all]"
		exit 1
		;;
	esac

	echo ""
	success "Installation complete!"
	echo ""
	echo -e "${YELLOW}Next steps:${NC}"
	echo "  1. Reload your shell: exec \$SHELL"
	echo "  2. Press CTRL-H to open ampcmd"
	echo "  3. TAB/SPACE to select multiple commands"
	echo "  4. ENTER to chain them together"
	echo ""
}

main "$@"
