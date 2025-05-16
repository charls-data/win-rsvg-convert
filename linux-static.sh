# linux-static.sh
#!/usr/bin/env sh
set -euo pipefail

# 1. 安装所有构建依赖（Ubuntu）
sudo apt-get update
sudo apt-get install -y \
  build-essential \
  meson \
  ninja-build \
  pkg-config \
  curl \
  musl-tools \
  libunwind-dev \
  libglib2.0-dev \
  libcairo2-dev \
  libpango1.0-dev \
  libxml2-dev \
  libfreetype6-dev \
  libpixman-1-dev \
  gdk-pixbuf2.0-dev \
  libssl-dev \
  zlib1g-dev \
  git

# 2. 安装 Rustup 并设置环境，安装 MUSL 目标和 cargo-c
if [ ! -x "$(command -v rustup)" ]; then
  curl https://sh.rustup.rs -sSf | sh -s -- -y
  . "$HOME/.cargo/env"
fi
export PATH="$HOME/.cargo/bin:$PATH"
rustup target add x86_64-unknown-linux-musl
cargo install cargo-c

# 3. 克隆 librsvg 源码并进入目录
git clone https://gitlab.gnome.org/GNOME/librsvg.git
cd librsvg

# 4. 修补 ci/Cargo.toml：在 [package] 段后插入 version 字段（若不存在）
if ! grep -q '^version' ci/Cargo.toml; then
  sed -i '/^\[package\]/a version = "0.0.0"' ci/Cargo.toml
fi

# 5. 使用 Meson 配置全静态构建
meson setup build \
  --default-library=static \
  -Dtriplet=x86_64-unknown-linux-musl \
  -Dtests=false \
  -Ddocs=disabled \
  -Dintrospection=disabled \
  -Dvala=disabled

# 6. 编译并去除符号
ninja -C build
strip build/rsvg-convert

# 7. （可选）验证静态链接
ldd build/rsvg-convert || true
