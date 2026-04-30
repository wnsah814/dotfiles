#!/usr/bin/env bash
# ============================================================================
#  dev-env setup script  (v2)
#  - zsh + oh-my-zsh + powerlevel10k
#  - zsh-autosuggestions, zsh-syntax-highlighting
#  - tmux (4-split bind, mouse, OS-aware clipboard copy)
#  - vim (line numbers + sane defaults)
#
#  Idempotent + self-healing:
#   • Re-running is safe.
#   • Managed blocks are REPLACED on every run, so OS-specific values
#     (e.g. pbcopy vs xclip) stay in sync with the current machine.
#   • Lines outside marker blocks are never touched.
# ============================================================================

set -e

# ---------- pretty logging ----------
GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; RED='\033[0;31m'; NC='\033[0m'
info()  { echo -e "${BLUE}[INFO]${NC} $*"; }
ok()    { echo -e "${GREEN}[ OK ]${NC} $*"; }
skip()  { echo -e "${YELLOW}[SKIP]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
err()   { echo -e "${RED}[ERR ]${NC} $*"; }

# ---------- OS detection ----------
detect_os() {
  case "$(uname -s)" in
    Darwin) echo "macos" ;;
    Linux)
      if grep -qi microsoft /proc/version 2>/dev/null; then echo "wsl"
      elif [ -n "${WAYLAND_DISPLAY:-}" ]; then echo "linux-wayland"
      else echo "linux"
      fi
      ;;
    *) echo "unknown" ;;
  esac
}
OS=$(detect_os)
info "Detected OS: $OS"

# ---------- pick clipboard cmd for tmux ----------
case "$OS" in
  macos)         CLIP_CMD="pbcopy" ;;
  wsl)           CLIP_CMD="clip.exe" ;;
  linux-wayland) CLIP_CMD="wl-copy" ;;
  linux)         CLIP_CMD="xclip -selection clipboard -i" ;;
  *)             CLIP_CMD="cat" ;;
esac
info "Clipboard command: $CLIP_CMD"

# ---------- package install helper ----------
install_pkg() {
  local pkg="$1"
  if command -v "$pkg" >/dev/null 2>&1; then
    skip "$pkg already installed"
    return 0
  fi
  info "Installing $pkg ..."
  case "$OS" in
    macos)
      command -v brew >/dev/null || { err "Homebrew not found. Install: https://brew.sh"; exit 1; }
      brew install "$pkg"
      ;;
    linux|wsl|linux-wayland)
      if   command -v apt-get >/dev/null; then sudo apt-get update -qq && sudo apt-get install -y "$pkg"
      elif command -v dnf     >/dev/null; then sudo dnf install -y "$pkg"
      elif command -v pacman  >/dev/null; then sudo pacman -S --noconfirm "$pkg"
      elif command -v zypper  >/dev/null; then sudo zypper install -y "$pkg"
      else err "No supported package manager found"; exit 1
      fi
      ;;
    *) err "Unsupported OS"; exit 1 ;;
  esac
  ok "$pkg installed"
}

# ---------- managed block replacement ----------
# Replaces (or inserts) the block between BEGIN/END markers.
# Lines outside the markers are preserved verbatim.
#   $1 = file path
#   $2 = label (e.g. "tmux config")
#   $3 = body (BEGIN/END marker lines added automatically)
replace_block() {
  local file="$1" label="$2" body="$3"
  local begin="# >>> dev-env $label BEGIN >>>"
  local end="# <<< dev-env $label END <<<"

  mkdir -p "$(dirname "$file")"
  [ -f "$file" ] || touch "$file"

  local tmp; tmp=$(mktemp)
  awk -v b="$begin" -v e="$end" '
    $0==b {inside=1; next}
    $0==e {inside=0; next}
    !inside {print}
  ' "$file" > "$tmp"

  [ -s "$tmp" ] && [ "$(tail -c1 "$tmp")" != "" ] && printf '\n' >> "$tmp"

  {
    echo "$begin"
    echo "$body"
    echo "$end"
  } >> "$tmp"

  mv "$tmp" "$file"
  ok "Wrote managed block to $(basename "$file"): $label"
}

# ============================================================================
# 1. Core packages
# ============================================================================
info "=== Step 1/5: core packages ==="
install_pkg git
install_pkg curl
install_pkg zsh
install_pkg tmux
install_pkg vim

case "$OS" in
  linux)
    if ! command -v xclip >/dev/null; then install_pkg xclip; else skip "xclip already installed"; fi
    ;;
  linux-wayland)
    if ! command -v wl-copy >/dev/null; then
      info "Installing wl-clipboard ..."
      sudo apt-get install -y wl-clipboard 2>/dev/null || \
      sudo dnf install -y wl-clipboard 2>/dev/null || \
      sudo pacman -S --noconfirm wl-clipboard 2>/dev/null || \
      warn "Could not install wl-clipboard automatically"
    else
      skip "wl-clipboard already installed"
    fi
    ;;
esac

# ============================================================================
# 2. Oh My Zsh
# ============================================================================
info "=== Step 2/5: Oh My Zsh ==="
if [ -d "$HOME/.oh-my-zsh" ]; then
  skip "Oh My Zsh already installed"
else
  info "Installing Oh My Zsh ..."
  RUNZSH=no CHSH=no KEEP_ZSHRC=yes \
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  ok "Oh My Zsh installed"
fi

ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"

# ============================================================================
# 3. Theme + plugins
# ============================================================================
info "=== Step 3/5: theme & plugins ==="

clone_if_missing() {
  local repo="$1" dest="$2" name="$3"
  if [ -d "$dest" ]; then
    skip "$name already cloned"
  else
    git clone --depth=1 "$repo" "$dest"
    ok "$name cloned"
  fi
}

clone_if_missing https://github.com/romkatv/powerlevel10k.git \
  "$ZSH_CUSTOM/themes/powerlevel10k" "powerlevel10k"
clone_if_missing https://github.com/zsh-users/zsh-autosuggestions \
  "$ZSH_CUSTOM/plugins/zsh-autosuggestions" "zsh-autosuggestions"
clone_if_missing https://github.com/zsh-users/zsh-syntax-highlighting \
  "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting" "zsh-syntax-highlighting"

chmod -R go-w "$HOME/.oh-my-zsh" 2>/dev/null || true
chmod go-w "$HOME" 2>/dev/null || true
ok "Permissions tightened"

# ---- ~/.zshrc ----
ZSHRC="$HOME/.zshrc"
[ -f "$ZSHRC" ] || touch "$ZSHRC"

if grep -q '^ZSH_THEME=' "$ZSHRC"; then
  if grep -q '^ZSH_THEME="powerlevel10k/powerlevel10k"' "$ZSHRC"; then
    skip "ZSH_THEME already powerlevel10k"
  else
    sed -i.bak 's|^ZSH_THEME=.*|ZSH_THEME="powerlevel10k/powerlevel10k"|' "$ZSHRC"
    ok "ZSH_THEME set to powerlevel10k"
  fi
else
  echo 'ZSH_THEME="powerlevel10k/powerlevel10k"' >> "$ZSHRC"
  ok "ZSH_THEME added"
fi

if grep -q '^plugins=' "$ZSHRC"; then
  for p in git zsh-autosuggestions zsh-syntax-highlighting; do
    if grep -E '^plugins=\(.*\b'"$p"'\b.*\)' "$ZSHRC" >/dev/null; then
      skip "plugin already enabled: $p"
    else
      sed -i.bak -E "s/^plugins=\((.*)\)/plugins=(\1 $p)/" "$ZSHRC"
      ok "plugin added: $p"
    fi
  done
else
  echo 'plugins=(git zsh-autosuggestions zsh-syntax-highlighting)' >> "$ZSHRC"
  ok "plugins line added"
fi

replace_block "$ZSHRC" "zsh extras" '# autosuggestion color (240 = soft gray)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE="fg=240"

# load powerlevel10k user config if present
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh'

# ============================================================================
# 4. tmux (managed block — OS-aware, replaced every run)
# ============================================================================
info "=== Step 4/5: tmux ==="
TMUX_CONF="$HOME/.tmux.conf"

replace_block "$TMUX_CONF" "tmux config" "# 4-split layout on prefix + 4
bind 4 split-window -h \\; split-window -v \\; select-pane -t 0 \\; split-window -v \\; select-layout tiled \\; select-pane -t 0

# mouse: click-to-focus, drag-to-resize, scroll
set -g mouse on
set -g set-clipboard on

# drag-select copies to system clipboard (OS: $OS)
bind -T copy-mode-vi MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel \"$CLIP_CMD\"
bind -T copy-mode    MouseDragEnd1Pane send-keys -X copy-pipe-and-cancel \"$CLIP_CMD\"

# bigger scrollback
set -g history-limit 50000

# start numbering at 1
set -g base-index 1
setw -g pane-base-index 1

# faster escape (better for vim in tmux)
set -sg escape-time 10

# 256 color + truecolor
set -g default-terminal \"tmux-256color\"
set -ga terminal-overrides \",*256col*:Tc\""

# clean up stale legacy lines outside our block (only on non-macOS)
if [ "$OS" != "macos" ] && grep -q "pbcopy" "$TMUX_CONF" 2>/dev/null; then
  # check there's any pbcopy outside the managed block
  if awk '/# >>> dev-env tmux config BEGIN >>>/{i=1;next}
          /# <<< dev-env tmux config END <<</{i=0;next}
          !i && /pbcopy/{found=1} END{exit !found}' "$TMUX_CONF"; then
    warn "Found stray 'pbcopy' lines in ~/.tmux.conf — removing"
    cp "$TMUX_CONF" "$TMUX_CONF.bak"
    awk '/# >>> dev-env tmux config BEGIN >>>/{i=1}
         /# <<< dev-env tmux config END <<</{print; i=0; next}
         i || !/pbcopy/' "$TMUX_CONF.bak" > "$TMUX_CONF"
    ok "Stray pbcopy lines removed (backup at ~/.tmux.conf.bak)"
  fi
fi

# reload tmux if a server is running
if command -v tmux >/dev/null && tmux info >/dev/null 2>&1; then
  tmux source-file "$TMUX_CONF" 2>/dev/null && ok "Reloaded tmux config in running server" \
    || warn "Could not reload tmux config — try: tmux kill-server && tmux"
fi

# ============================================================================
# 5. vim (managed block)
# ============================================================================
info "=== Step 5/5: vim ==="
VIMRC="$HOME/.vimrc"

replace_block "$VIMRC" "vim config" 'set nocompatible              " no vi compat
syntax on                     " syntax highlighting
filetype plugin indent on     " filetype detection

" --- display ---
set number                    " line numbers
set relativenumber            " relative line numbers
set cursorline                " highlight current line
set ruler                     " show cursor position
set showcmd                   " show partial commands
set laststatus=2              " always show status bar
set wildmenu                  " better command completion
set scrolloff=5               " keep 5 lines around cursor

" --- indentation ---
set expandtab                 " spaces, not tabs
set tabstop=4
set shiftwidth=4
set softtabstop=4
set autoindent
set smartindent

" --- search ---
set hlsearch                  " highlight matches
set incsearch                 " incremental search
set ignorecase                " case-insensitive...
set smartcase                 " ...unless capitals used

" --- editing ---
set backspace=indent,eol,start
set mouse=a                   " mouse support
set clipboard=unnamedplus     " system clipboard
set encoding=utf-8

" --- usability ---
set hidden                    " allow buffer switching w/o save
set noerrorbells visualbell t_vb=
set history=1000

silent! colorscheme desert'

# ============================================================================
# Default shell
# ============================================================================
if [ "${SHELL##*/}" = "zsh" ]; then
  skip "Default shell already zsh"
else
  if command -v chsh >/dev/null 2>&1; then
    ZSH_BIN="$(command -v zsh)"
    if grep -qx "$ZSH_BIN" /etc/shells 2>/dev/null; then
      info "Changing default shell to zsh ..."
      chsh -s "$ZSH_BIN" || warn "chsh failed; run manually:  chsh -s $ZSH_BIN"
    else
      warn "$ZSH_BIN not in /etc/shells — skipping chsh"
    fi
  fi
fi

# ============================================================================
# Done
# ============================================================================
echo
ok "All done!"
echo
echo "Next steps:"
echo "  1.  Open a new terminal  (or run:  exec zsh )"
echo "  2.  On first launch p10k runs a config wizard."
echo "      To re-run later:  p10k configure"
echo "  3.  Inside tmux: Ctrl+B then 4  → 4-split"
echo "                   drag with mouse  → copies to system clipboard"
echo
echo "If tmux mouse-copy still misbehaves, kill the server fully:"
echo "      tmux kill-server && tmux"
