#!/usr/bin/env bash
set -euo pipefail

USER_HOME="/home/vscode"
cd "$USER_HOME"

echo "=== 🧰 [dev-toolbox] 初始化开始（asdf + Java/Node/Python/Go） ==="

##############################################
# 0. 基础工具 & 国内 apt 源（可按需微调）
##############################################
echo ">>> 配置 Debian 镜像为清华（可改成阿里）"
# sudo sed -i 's@deb.debian.org@mirrors.tuna.tsinghua.edu.cn@g' /etc/apt/sources.list || true
sudo tee /etc/apt/sources.list <<'EOF'
# 默认注释了源码镜像以提高 apt update 速度，如有需要可自行取消注释
deb https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie main contrib non-free non-free-firmware
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie main contrib non-free non-free-firmware

deb https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie-updates main contrib non-free non-free-firmware
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie-updates main contrib non-free non-free-firmware

deb https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie-backports main contrib non-free non-free-firmware
# deb-src https://mirrors.tuna.tsinghua.edu.cn/debian/ trixie-backports main contrib non-free non-free-firmware

# 以下安全更新软件源包含了官方源与镜像站配置，如有需要可自行修改注释切换
deb https://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
# deb-src https://security.debian.org/debian-security trixie-security main contrib non-free non-free-firmware
EOF

sudo apt-get update

echo ">>> 安装基础工具"
sudo apt-get install -y \
  curl unzip xz-utils wget \
  build-essential pkg-config \
  libssl-dev zlib1g-dev libffi-dev \
  ca-certificates gnupg dirmngr \
  sqlite3 ripgrep fd-find

# 切换默认 shell 为 zsh（vscode 用户）
if [ "$SHELL" != "/usr/bin/zsh" ]; then
  echo ">>> 将默认 shell 切换为 zsh"
  sudo chsh -s /usr/bin/zsh vscode || true
fi

##############################################
# 🍺 安装 Homebrew（Linuxbrew）+ 中国镜像加速
##############################################
echo ">>> 安装 Homebrew (Linuxbrew)"

if ! command -v brew >/dev/null 2>&1; then
  NONINTERACTIVE=1 bash -c \
    "$(curl -fsSL https://gh-proxy.com/https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

  # 写入 shellenv
  echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >>"$USER_HOME/.bashrc"
  echo 'eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"' >>"$USER_HOME/.zshrc"
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

echo ">>> 配置 Homebrew 中国镜像源"
brew_repo="$(brew --repo)"
# brew 主仓库
git -C "$brew_repo" remote set-url origin https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/brew.git || true

# homebrew-core
if [ -d "$brew_repo/Library/Taps/homebrew/homebrew-core" ]; then
  git -C "$brew_repo/Library/Taps/homebrew/homebrew-core" \
    remote set-url origin https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-core.git
fi

# homebrew-cask
if [ -d "$brew_repo/Library/Taps/homebrew/homebrew-cask" ]; then
  git -C "$brew_repo/Library/Taps/homebrew/homebrew-cask" \
    remote set-url origin https://mirrors.tuna.tsinghua.edu.cn/git/homebrew/homebrew-cask.git
fi

brew update || true

echo ">>> 安装 starship（使用官方安装器 + 代理）"
brew install starship

##############################################
# 1. 安装 asdf（统一版本管理工具）
##############################################
if [ ! -d "$USER_HOME/.asdf" ]; then
  echo ">>> 安装 asdf"
  brew install asdf
fi

export ASDF_DATA_DIR="$USER_HOME/.asdf" >>~/.zshrc
export PATH="$ASDF_DATA_DIR/shims:$PATH" >>~/.zshrc

# 当前脚本也启用 asdf
# . "$USER_HOME/.asdf/asdf.sh"

##############################################
# 2. 配置一些国内镜像（按需改，不想用可以注释掉）
##############################################
echo ">>> 配置 Python / pip 国内源"
mkdir -p "$USER_HOME/.pip"
cat <<EOF >"$USER_HOME/.pip/pip.conf"
[global]
index-url=https://mirrors.tuna.tsinghua.edu.cn/pypi/web/simple
EOF

echo ">>> 配置 Go proxy"
mkdir -p "$USER_HOME/.config/go"
cat <<EOF >"$USER_HOME/.config/go/env"
GOPROXY=https://goproxy.cn,direct
EOF

echo ">>> Rust crates 镜像（as extra，给将来用）"
mkdir -p "$USER_HOME/.cargo"
cat <<EOF >"$USER_HOME/.cargo/config"
[source.crates-io]
replace-with = "ustc"
[source.ustc]
registry = "https://mirrors.ustc.edu.cn/crates.io-index/"
EOF

##############################################
# 3. 通过 asdf 安装 Node / Python / Java / Go
##############################################

echo ">>> 安装 asdf 插件：nodejs / python / java / golang"

export ASDF_DATA_DIR="$HOME/.asdf"
export PATH="$ASDF_DATA_DIR/shims:$PATH"
# Node.js
if ! asdf plugin list | grep -q '^nodejs$'; then
  echo ">>> asdf 添加 nodejs 插件"
  # 用官方索引里的 nodejs 插件（不写 URL，避免路径变来变去）
  if ! asdf plugin add nodejs; then
    echo "!!! asdf plugin add nodejs 失败，请检查网络（GitHub 访问）"
    exit 1
  fi
fi

# Python
if ! asdf plugin list | grep -q '^python$'; then
  echo ">>> asdf 添加 python 插件"
  if ! asdf plugin add python; then
    echo "!!! asdf plugin add python 失败"
    exit 1
  fi
fi

# Java
if ! asdf plugin list | grep -q '^java$'; then
  echo ">>> asdf 添加 java 插件"
  if ! asdf plugin add java; then
    echo "!!! asdf plugin add java 失败"
    exit 1
  fi
fi

# Go
if ! asdf plugin list | grep -q '^golang$'; then
  echo ">>> asdf 添加 golang 插件"
  if ! asdf plugin add golang; then
    echo "!!! asdf plugin add golang 失败"
    exit 1
  fi
fi

echo ">>> 用 asdf 安装具体版本（你可以按需改版本号）"

# 你可以改成自己偏好的版本
NODE_VERSION="latest"
PYTHON_VERSION="3.11.9"
JAVA_VERSION="zulu-crac-21.46.23" # Java 21 LTS（Temurin）
GO_VERSION="latest"

# Node
asdf install nodejs "$NODE_VERSION"
asdf set nodejs "$NODE_VERSION"

# Python
asdf install python "$PYTHON_VERSION"
asdf set python "$PYTHON_VERSION"

# Java
asdf install java "$JAVA_VERSION"
asdf set java "$JAVA_VERSION"

# Go
asdf install golang "$GO_VERSION"
asdf set golang "$GO_VERSION"

echo ">>> 当前 asdf 全局版本："
asdf current

##############################################
# 4. 安装 Neovim（编辑器，用 apt 即可，够用）
##############################################
if ! command -v nvim >/dev/null 2>&1; then
  echo ">>> 安装 Neovim"
  sudo apt-get install -y neovim
fi

##############################################
# 5. dotfiles / AstroNvim（只对你自己生效）
##############################################
if [ "${NEOVIM_MODE:-0}" = "1" ]; then
  echo ">>> NEOVIM_MODE=1，配置 Neovim 环境"

  # 优先使用你的 chezmoi dotfiles
  if [ -n "${DOTFILES_REPO:-}" ]; then
    echo ">>> 检测到 DOTFILES_REPO，使用 chezmoi"
    # Debian 上可以 apt 直接装 chezmoi
    if ! command -v chezmoi >/dev/null 2>&1; then
      sudo apt-get install -y chezmoi
    fi

    if [ ! -d "$USER_HOME/.local/share/chezmoi" ]; then
      chezmoi init "$DOTFILES_REPO"
    fi
    chezmoi apply -v
  else
    # 没有 dotfiles 的情况下，帮你装一份 AstroNvim 作为默认
    if [ ! -d "$USER_HOME/.config/nvim" ]; then
      echo ">>> 未设置 DOTFILES_REPO，默认安装 AstroNvim"
      git clone https://gh-proxy.com/https://github.com/AstroNvim/AstroNvim \
        "$USER_HOME/.config/nvim"
    fi
  fi
fi

##############################################
# 6. 预留 .env 机制（给 AI Key 之类用）
##############################################
if ! grep -q 'source ~/.env' "$USER_HOME/.zshrc" 2>/dev/null; then
  echo '[ -f ~/.env ] && source ~/.env' >>"$USER_HOME/.zshrc"
fi

echo "=== ✅ [dev-toolbox] 初始化完成，你的多语言工具箱已就绪（asdf 管理 Java/Node/Python/Go） ==="
