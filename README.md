# chainhist

Chain multiple shell history commands into a single command using fuzzy selection.

**Select multiple commands from history → Chain with `&&` → Paste to prompt**

Works across **zsh**, **fish**, and **bash**.

## Requirements

> [!CAUTION]
> **fzf** is a mandatory dependency for the interactive UI. `chainhist` will not work without it.

- `fzf` (fuzzy finder) - [Install guide](https://github.com/junegunn/fzf#installation)
- zsh 5.8+ / fish 3.0+ / bash 4.0+

## Demo

```
┌─────────────────────────────────────────────────┐
│ history > git fetch origin                        │
│ history > git reset --hard origin/main            │
│ history > docker compose down                     │
│ history > docker compose build                    │
│ history > docker compose up -d                    │
└─────────────────────────────────────────────────┘
         TAB to select multiple
                    
Result: git fetch origin && git reset --hard origin/main && docker compose down
```

## Installation

### Homebrew (macOS)

```bash
brew tap YOUR/tap
brew install chainhist
```

Add to your shell config:
```bash
# zsh (~/.zshrc)
source $(brew --prefix)/opt/chainhist/zsh/chainhist.plugin.zsh

# bash (~/.bashrc)
source $(brew --prefix)/opt/chainhist/bash/chainhist.bash

# fish (~/.config/fish/config.fish)
bind \ch 'chainhist | begin; read -l key; read -l cmd; and begin; switch "$key"; case ctrl-y; echo -n "$cmd" | pbcopy; or echo -n "$cmd" | xclip -selection clipboard; or echo -n "$cmd" | xsel --clipboard; echo "Copied to clipboard"; case "*"; commandline -- "$cmd"; commandline -f execute; end; end; end'
```

### curl (One-liner)

```bash
curl -sSL https://raw.githubusercontent.com/YOUR/chainhist/main/install.sh | bash
```

Auto-detects your shell and installs appropriate version.

### Manual Installation

> [!IMPORTANT]
> Ensure **fzf** is installed before manual installation.

#### zsh

```bash
git clone https://github.com/YOUR/chainhist.git ~/.local/share/chainhist
echo 'source ~/.local/share/chainhist/src/chainhist.plugin.zsh' >> ~/.zshrc
exec $SHELL
```

#### fish

```bash
git clone https://github.com/YOUR/chainhist.git ~/.local/share/chainhist
mkdir -p ~/.config/fish/functions
cp ~/.local/share/chainhist/src/chainhist.fish ~/.config/fish/functions/

# Add keybinding
echo 'bind \ch "chainhist | begin; read -l key; read -l cmd; and begin; switch \$key; case ctrl-y; echo -n \$cmd | pbcopy; or echo -n \$cmd | xclip -selection clipboard; or echo -n \$cmd | xsel --clipboard; echo \"Copied to clipboard\"; case \"*\"; commandline -- \$cmd; commandline -f execute; end; end; end"' >> ~/.config/fish/config.fish
exec $SHELL
```

#### bash

```bash
git clone https://github.com/YOUR/chainhist.git ~/.local/share/chainhist
echo 'source ~/.local/share/chainhist/src/chainhist.bash' >> ~/.bashrc
exec $SHELL
```

### For Development (Local)

```bash
# Clone to your Code directory
git clone https://github.com/YOUR/chainhist.git ~/Code/chainhist

# Add to PATH
export PATH="$HOME/Code/chainhist/bin:$PATH"

# Source for your shell
source ~/Code/chainhist/src/chainhist.plugin.zsh  # zsh
source ~/Code/chainhist/src/chainhist.bash         # bash

# fish: symlink the function and preview script
mkdir -p ~/.config/fish/functions
ln -sf ~/Code/chainhist/src/chainhist.fish ~/.config/fish/functions/chainhist.fish
ln -sf ~/Code/chainhist/src/chainhist-preview.sh ~/.config/fish/functions/chainhist-preview.sh

# fish: add keybinding to config.fish
echo "bind \ch 'chainhist | begin; read -l key; read -l cmd; and begin; switch \"\$key\"; case ctrl-y; echo -n \"\$cmd\" | pbcopy; or echo -n \"\$cmd\" | xclip -selection clipboard; or echo -n \"\$cmd\" | xsel --clipboard; echo \"Copied to clipboard\"; case \"*\"; commandline -- \"\$cmd\"; commandline -f execute; end; end; end'" >> ~/.config/fish/config.fish
```

## Usage

### Interactive Mode (CTRL-H)

1. Press `CTRL-H` in your shell
2. TAB or SPACE to toggle command selection
3. Select multiple commands (order matters!)
4. Press one of:
   - **ENTER** - Execute immediately
   - **CTRL-Y** - Copy to clipboard
5. ESC to cancel

### Action Modes

| Key | Action | Description |
|-----|--------|-------------|
| `ENTER` | Execute immediately | Chain runs without confirmation |
| `CTRL-Y` | Copy to clipboard | Chain copied to system clipboard |

### Command Line

```bash
# Show last 20 commands (default)
chainhist

# Show last 50 commands
chainhist 50
```

## Keybindings

| Key | Action |
|-----|--------|
| `TAB` | Toggle selection + move down |
| `SPACE` | Toggle selection (no movement) |
| `SHIFT+TAB` | Toggle selection + move up |
| `ENTER` | Execute chain immediately |
| `CTRL+Y` | Copy chain to clipboard |
| `ESC` | Cancel |

## Order Preservation

Commands are chained in **list order** (top-to-bottom in fzf). For best results:

1. Your most recent commands appear at the top
2. TAB through them in sequence (top item runs first)
3. Result: `cmd1 && cmd2 && cmd3`

## Shell Compatibility

| Feature | zsh | fish | bash |
|---------|-----|------|------|
| Core functionality | ✅ | ✅ | ✅ |
| CTRL-H binding | ✅ | ✅ | ✅ |
| Execute immediately (ENTER) | ✅ | ✅ | ⚠️ Pastes to prompt |
| Copy to clipboard (CTRL-Y) | ✅ | ✅ | ✅ |
| History source | `fc` builtin | `history` builtin | `history` builtin |
| Widget system | zle | `bind` | `bind -x` |

**Note:** In bash, ENTER pastes the chain to prompt instead of executing immediately due to readline limitations. Press Enter manually to run.

## How It Works

```
User presses CTRL-H
    ↓
fzf opens with recent history
    ↓
User selects multiple commands
    ↓
Commands joined with &&
    ↓
User presses action key:
    ├─ ENTER  → Execute immediately
    └─ CTRL-Y → Copy to clipboard
```

## Comparison with Alternatives

| Tool | Multi-select | Order Control | Shell Support |
|------|--------------|---------------|---------------|
| chainhist | ✅ | ✅ List order | zsh/fish/bash |
| fzf Ctrl-R | ✅ | ❌ List order | zsh/fish/bash |
| McFly | ❌ | N/A | zsh/bash |
| Atuin | ❌ | N/A | zsh/fish/bash |

## Contributing

```bash
git clone https://github.com/YOUR/chainhist.git
cd chainhist

# Test zsh version
zsh src/chainhist.zsh

# Test fish version  
fish src/chainhist.fish

# Test bash version
bash src/chainhist.bash
```

## Troubleshooting

### Fish: "Error: Shell history is empty" or fzf shows file list

If you see an error about empty history or `fzf` shows a list of files instead of your commands, it usually means your `fish` history file is empty or in a format `history search` cannot read.

1.  **Verify history exists:** Run `history search --max 10`. If it returns nothing, you have no history.
2.  **Check history location:** `fish` history is normally at `~/.local/share/fish/fish_history`.
3.  **Permissions:** Ensure your user can read the history file.

## License

MITcense

MIT