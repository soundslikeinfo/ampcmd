# ampcmd

Chain shell history commands into a single command using fuzzy selection.

**Select multiple commands from history → Chain with `&&` → Paste to prompt**

Works across **zsh**, **fish**, and **bash**.

## Requirements

> [!CAUTION]
> **fzf** is a mandatory dependency for the interactive UI. `ampcmd` will not work without it.

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
brew tap soundslikeinfo/ampcmd
brew install ampcmd
```

Add to your shell config:
```bash
# zsh (~/.zshrc)
source $(brew --prefix ampcmd)/libexec/ampcmd.plugin.zsh

# bash (~/.bashrc)
source $(brew --prefix ampcmd)/libexec/ampcmd.bash

# fish (~/.config/fish/config.fish)
source $(brew --prefix ampcmd)/libexec/ampcmd.fish
bind \ch 'ampcmd'
```

**Note:** You can run `ampcmd` directly (command-line mode) without sourcing, but shell integration (CTRL-H keybinding) requires sourcing. If your chains include aliases or custom functions, see [My alias or custom function wasn't recognized](#my-alias-or-custom-function-wasnt-recognized).

### curl (One-liner)

```bash
curl -sSL https://raw.githubusercontent.com/soundslikeinfo/ampcmd/main/install.sh | bash
```

Auto-detects your shell and installs appropriate version.

### Manual Installation

> [!IMPORTANT]
> Ensure **fzf** is installed before manual installation.

#### zsh

```bash
git clone https://github.com/soundslikeinfo/ampcmd.git ~/.local/share/ampcmd
echo 'source ~/.local/share/ampcmd/src/ampcmd.plugin.zsh' >> ~/.zshrc
exec $SHELL
```

#### fish

```bash
git clone https://github.com/soundslikeinfo/ampcmd.git ~/.local/share/ampcmd
mkdir -p ~/.config/fish/functions
cp ~/.local/share/ampcmd/src/ampcmd.fish ~/.config/fish/functions/

# Add keybinding
echo 'bind \ch "ampcmd | begin; read -l key; read -l cmd; and begin; switch \$key; case ctrl-y; echo -n \$cmd | pbcopy; or echo -n \$cmd | xclip -selection clipboard; or echo -n \$cmd | xsel --clipboard; echo \"Copied to clipboard\"; case \"*\"; commandline -- \$cmd; commandline -f execute; end; end; end"' >> ~/.config/fish/config.fish
exec $SHELL
```

#### bash

```bash
git clone https://github.com/soundslikeinfo/ampcmd.git ~/.local/share/ampcmd
echo 'source ~/.local/share/ampcmd/src/ampcmd.bash' >> ~/.bashrc
exec $SHELL
```

### For Development (Local)

```bash
# Clone to your Code directory
git clone https://github.com/soundslikeinfo/ampcmd.git ~/Code/ampcmd

# Add to PATH
export PATH="$HOME/Code/ampcmd/bin:$PATH"

# Source for your shell
source ~/Code/ampcmd/src/ampcmd.plugin.zsh  # zsh
source ~/Code/ampcmd/src/ampcmd.bash         # bash

# fish: symlink the function and preview script
mkdir -p ~/.config/fish/functions
ln -sf ~/Code/ampcmd/src/ampcmd.fish ~/.config/fish/functions/ampcmd.fish
ln -sf ~/Code/ampcmd/src/ampcmd-preview.sh ~/.config/fish/functions/ampcmd-preview.sh

# fish: add keybinding to config.fish
echo "bind \ch 'ampcmd | begin; read -l key; read -l cmd; and begin; switch \"\$key\"; case ctrl-y; echo -n \"\$cmd\" | pbcopy; or echo -n \"\$cmd\" | xclip -selection clipboard; or echo -n \"\$cmd\" | xsel --clipboard; echo \"Copied to clipboard\"; case \"*\"; commandline -- \"\$cmd\"; commandline -f execute; end; end; end'" >> ~/.config/fish/config.fish
```

### Manual Installation

```bash
# Remove installation directory
rm -rf ~/.local/share/ampcmd

# Remove from shell configuration
# Edit ~/.zshrc and remove: source ~/.local/share/ampcmd/src/ampcmd.plugin.zsh
# Edit ~/.bashrc and remove: source ~/.local/share/ampcmd/src/ampcmd.bash

# For fish, remove:
rm ~/.config/fish/functions/ampcmd.fish
rm ~/.config/fish/functions/ampcmd-preview.sh
# And remove the bind command from ~/.config/fish/config.fish
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
ampcmd

# Show last 50 commands
ampcmd 50

# View and select from chain history
ampcmd -l
```

## History Tracking

ampcmd automatically records all executed chains to `~/.ampcmd_history`.

### Viewing Chain History

```bash
# View and rerun previous chains
ampcmd -l
```

This opens an fzf interface showing your chain history (most recent first). Select any chain to execute it again, or press CTRL-Y to copy it to the clipboard.

### Disabling History Recording

Create a config file at `~/.config/ampcmd/config` (or `~/.ampcmd.conf`):

```bash
# ~/.config/ampcmd/config
DISALLOW_HISTORY=true
```

This prevents ampcmd from recording your chains.

### Sourcing aliases before execution

When running `ampcmd` as a standalone command, it spawns a new shell that doesn't load your shell profile. If your chains include aliases or functions defined in your shell config, use `SOURCE_BEFORE_EXEC` to load the specific files that define them:

```bash
# ~/.config/ampcmd/config

# Single file
SOURCE_BEFORE_EXEC=~/.zsh/05-aliases.zsh

# Multiple files (colon-separated)
SOURCE_BEFORE_EXEC=~/.zsh/05-aliases.zsh:~/.zsh/06-functions.zsh
```

> [!TIP]
> Point directly at the file(s) that define your aliases or functions — avoid sourcing your full shell profile (e.g. `~/.zshrc`) as it may trigger welcome messages, plugin initialization, or other interactive-only startup code.
>
> This is only needed for the standalone `ampcmd` command. The CTRL-H widget runs inside your current shell session and already has access to all your aliases.

## Keybindings

| Key | Action |
|-----|--------|
| `TAB` | Toggle selection + move down |
| `SPACE` | Toggle selection (no movement) |
| `SHIFT+TAB` | Toggle selection + move up |
| `RIGHT ARROW` | Select command + move down |
| `LEFT ARROW` | Deselect command |
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
| ampcmd | ✅ | ✅ List order | zsh/fish/bash |
| fzf Ctrl-R | ✅ | ❌ List order | zsh/fish/bash |
| McFly | ❌ | N/A | zsh/bash |
| Atuin | ❌ | N/A | zsh/fish/bash |

## Updating

### Homebrew (Recommended)

When new versions are released, simply run:

```bash
brew upgrade ampcmd
```

Homebrew formula updates automatically when new releases are published.

### Manual Installation

```bash
cd ~/.local/share/ampcmd
git pull
```

## Release Process

Releases are automated via GitHub Actions:

1. New version tagged on GitHub
2. GitHub release published
3. Homebrew formula automatically updated with new SHA256
4. Users can immediately upgrade via `brew upgrade`

No manual formula maintenance required.

## Contributing

```bash
git clone https://github.com/soundslikeinfo/ampcmd.git
cd ampcmd

# Test zsh version
zsh src/ampcmd.zsh

# Test fish version  
fish src/ampcmd.fish

# Test bash version
bash src/ampcmd.bash
```

## Troubleshooting

### My alias or custom function wasn't recognized

When you run `ampcmd` as a standalone command, it executes in a new shell that doesn't load your shell profile — so aliases and functions defined in `~/.zshrc`, `~/.bashrc`, or similar files aren't available.

**Solution:** Add a `SOURCE_BEFORE_EXEC` entry to `~/.config/ampcmd/config` pointing at the file(s) where your aliases or functions are defined:

```bash
# Single file
SOURCE_BEFORE_EXEC=~/.zsh/05-aliases.zsh

# Multiple files (colon-separated)
SOURCE_BEFORE_EXEC=~/.zsh/05-aliases.zsh:~/.zsh/06-functions.zsh
```

> [!TIP]
> Avoid pointing at your full shell profile (e.g. `~/.zshrc`) — it may trigger welcome messages or other interactive-only startup code. Target only the file(s) that define what you need.

**Alternatively, use the CTRL-H widget** — it runs inside your current shell session where all aliases are already loaded, so `SOURCE_BEFORE_EXEC` is never needed. To enable it, add to your shell config:

```bash
# Zsh (~/.zshrc)
source $(brew --prefix ampcmd)/libexec/ampcmd.plugin.zsh

# Bash (~/.bashrc)
source $(brew --prefix ampcmd)/libexec/ampcmd.bash

# Fish (~/.config/fish/config.fish)
source $(brew --prefix ampcmd)/libexec/ampcmd.fish
bind \ch 'ampcmd'
```

Then reload your shell: `exec $SHELL`

### Fish: "Error: Shell history is empty" or fzf shows file list

If you see an error about empty history or `fzf` shows a list of files instead of your commands, it usually means your `fish` history file is empty or in a format `history search` cannot read.

1.  **Verify history exists:** Run `history search --max 10`. If it returns nothing, you have no history.
2.  **Check history location:** `fish` history is normally at `~/.local/share/fish/fish_history`.
3.  **Permissions:** Ensure your user can read the history file.

## Uninstallation

### Remove History File

```bash
rm ~/.ampcmd_history
rm -rf ~/.config/ampcmd
```

### Homebrew

```bash
brew uninstall ampcmd
brew untap soundslikeinfo/ampcmd
```

Remove the shell configuration lines you added to:
- `~/.zshrc` (zsh)
- `~/.bashrc` (bash)
- `~/.config/fish/config.fish` (fish)

## License

MIT License