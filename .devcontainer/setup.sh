#!/usr/bin/env bash
set -euo pipefail

##############################################
# 🧰 dev-toolbox 最小化配置脚本
# 语言环境由 devcontainer.json features 安装
# 本脚本仅负责：镜像源配置、Homebrew 工具、dotfiles
##############################################

USER_HOME="/home/vscode"

log_info()  { echo ">>> $*"; }
log_success() { echo "✅ $*"; }
log_error() { echo "❌ $*" >&2; }

# 确保某行存在于文件中（幂等）
ensure_line() {
  local line="$1" target="$2"
  grep -qxF "$line" "$target" 2>/dev/null || echo "$line" >> "$target"
}

# 确保某行存在于 .zshrc 和 .bashrc
ensure_shell_config() {
  local line="$1"
  ensure_line "$line" "$USER_HOME/.zshrc"
  ensure_line "$line" "$USER_HOME/.bashrc"
}

cd "$USER_HOME"

echo "=== 🧰 [dev-toolbox] 初始化开始 ==="

##############################################
# 🌏 配置国内镜像源
##############################################
log_info "配置各语言包管理器国内源"

# pip (Python)
mkdir -p "$USER_HOME/.config/pip"
cat > "$USER_HOME/.config/pip/pip.conf" <<'EOF'
[global]
index-url = https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple
trusted-host = mirrors.tuna.tsinghua.edu.cn
EOF

# npm (Node.js)
[ -d "$USER_HOME/.npmrc" ] && rm -rf "$USER_HOME/.npmrc"
cat > "$USER_HOME/.npmrc" <<'EOF'
registry=https://registry.npmmirror.com
EOF

# 安装全局 npm 包
log_info "安装全局 npm 包"
npm install -g @anthropic-ai/claude-code || true
npm install -g @openai/codex || true


##############################################
# 🍺 安装并配置 Homebrew
##############################################
LINUXBREW_PATH="/home/linuxbrew/.linuxbrew"

log_info "安装 Homebrew"

if ! command -v brew &>/dev/null; then
  NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
fi

# 配置 Homebrew 环境
if [ -f "${LINUXBREW_PATH}/bin/brew" ]; then
  ensure_shell_config "eval \"\$(${LINUXBREW_PATH}/bin/brew shellenv)\""
  eval "$("${LINUXBREW_PATH}/bin/brew" shellenv)"

  log_info "配置 Homebrew 中国镜像源"
  brew_repo="$(brew --repo)"
  git -C "$brew_repo" remote set-url origin https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git || true

  for tap in homebrew-core homebrew-cask; do
    tap_dir="$brew_repo/Library/Taps/homebrew/$tap"
    [ -d "$tap_dir" ] && git -C "$tap_dir" remote set-url origin "https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/${tap}.git" || true
  done

  brew update || true

  # 安装额外的 Homebrew 工具
  BREW_PACKAGES=(
    "zoxide"
    "fzf"
    "neovim"
    "chezmoi"
    "zellij"
    "starship"
    "lsd"
  )

  log_info "安装 Homebrew 软件包: ${BREW_PACKAGES[*]}"
  brew install "${BREW_PACKAGES[@]}" || true
  brew cleanup || true
fi

##############################################
# ⚙️ Shell 配置
##############################################
log_info "配置 Shell 环境"

# 配置 starship
ensure_shell_config 'eval "$(starship init zsh)"'
ensure_shell_config 'eval "$(zoxide init --cmd j zsh)"'

# 常用 alias
ensure_shell_config 'alias vim=nvim'
ensure_shell_config 'alias ls="lsd"'
ensure_shell_config 'alias claude="claude --dangerously-skip-permissions"'
ensure_shell_config 'alias codex="codex --dangerously-bypass-approvals-and-sandbox"'

##############################################
# ☕ JDK 版本切换配置
##############################################
log_info "配置 JDK 版本切换"

# devcontainer feature 安装的 Java 路径
JAVA_FEATURE_HOME="/usr/local/sdkman/candidates/java/current"

cat >> "$USER_HOME/.zshrc" <<'EOF'

# JDK 版本切换
# 使用方法: jdk8 切换到 JDK 8, jdk 切换回默认版本
export JAVA_HOME_DEFAULT="/usr/local/sdkman/candidates/java/current"
export JAVA_HOME_8="$(brew --prefix openjdk@8 2>/dev/null)/libexec/openjdk.jdk/Contents/Home"

jdk8() {
  if [ -d "$JAVA_HOME_8" ]; then
    export JAVA_HOME="$JAVA_HOME_8"
    export PATH="$JAVA_HOME/bin:$PATH"
    echo "✅ 已切换到 JDK 8: $(java -version 2>&1 | head -1)"
  else
    echo "❌ JDK 8 未安装"
  fi
}

jdk() {
  export JAVA_HOME="$JAVA_HOME_DEFAULT"
  export PATH="$JAVA_HOME/bin:$PATH"
  echo "✅ 已切换到默认 JDK: $(java -version 2>&1 | head -1)"
}
EOF

##############################################
# 🖥️ Neovim & Dotfiles 配置（可选）
##############################################
if [ "${NEOVIM_MODE:-0}" = "1" ]; then
  log_info "NEOVIM_MODE=1，配置 Neovim 环境"

  if [ -n "${DOTFILES_REPO:-}" ]; then
    log_info "检测到 DOTFILES_REPO，使用 chezmoi"
    if command -v chezmoi &>/dev/null; then
      if [ ! -d "$USER_HOME/.local/share/chezmoi" ]; then
        chezmoi init "$DOTFILES_REPO"
      fi
      chezmoi apply -v
    fi
  else
    # 没有 dotfiles 则安装 AstroNvim
    if [ ! -d "$USER_HOME/.config/nvim" ]; then
      log_info "未设置 DOTFILES_REPO，默认安装 AstroNvim"
      git clone --depth 1 https://gh-proxy.com/https://github.com/AstroNvim/template \
        "$USER_HOME/.config/nvim"
    fi
  fi
fi

##############################################
# 🔐 预留 .env 机制
##############################################
ensure_shell_config '[ -f ~/.env ] && source ~/.env'

log_success "[dev-toolbox] 初始化完成！"
echo ""
echo "📦 已安装的开发工具："
echo "   Node.js: $(node --version 2>/dev/null || echo '未安装')"
echo "   Python:  $(python --version 2>/dev/null || echo '未安装')"
echo "   Java:    $(java --version 2>/dev/null | head -1 || echo '未安装')"
echo "   Go:      $(go version 2>/dev/null || echo '未安装')"
echo ""
echo "💡 提示：使用 jdk8/jdk 命令切换 Java 版本"
