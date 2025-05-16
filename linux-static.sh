# linux-static.sh
#!/usr/bin/env sh
set -euo pipefail

# 0. Ensure HOME points to root in container to satisfy rustup
export HOME=/root
export RUSTUP_HOME="$HOME/.rustup"
export CARGO_HOME="$HOME/.cargo"
export PATH="$CARGO_HOME/bin:$PATH"

# Detect OS (Ubuntu or Alpine)
OS=""
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS=$ID
fi

# 1. Install system dependencies, including git and compression libs
if [ "$OS" = "alpine" ]; then
  apk update
  apk add --no-cache git
  apk add --no-cache \
    build-base meson ninja pkgconfig \
    curl musl-dev musl-utils \
    libunwind-dev \
    glib-dev cairo-dev pango-dev \
    libxml2-dev freetype-dev pixman-dev \
    gdk-pixbuf-dev \
    openssl-dev \
    zlib-dev
elif [ -x "$(command -v apt-get)" ]; then
  sudo apt-get update
  sudo apt-get install -y \
    git build-essential meson ninja-build pkg-config \
    curl musl-tools libunwind-dev \
    libglib2.0-dev libcairo2-dev libpango1.0-dev \
    libxml2-dev libfreetype6-dev libpixman-1-dev \
    gdk-pixbuf2.0-dev \
    libssl-dev \
    zlib1g-dev
else
  echo "Unsupported OS: $OS" >&2
  exit 1
fi

# 2. Install Rustup if missing, add MUSL target, and install cargo-c
if [ ! -x "$(command -v rustup)" ]; then
  curl https://sh.rustup.rs -sSf | sh -s -- -y
fi
rustup target add x86_64-unknown-linux-musl
if ! command -v cargo-cbuild >/dev/null 2>&1; then
  cargo install cargo-c
fi

# 3. Clone librsvg source and enter directory
git clone https://gitlab.gnome.org/GNOME/librsvg.git
cd librsvg

# 4. Ensure ci/Cargo.toml has version under [package]
if ! grep -q '^version' ci/Cargo.toml; then
  sed -i '/^\[package\]/a version = "0.0.0"' ci/Cargo.toml
fi

# 5. Configure Meson for fully static build
meson setup build \
  --default-library=static \
  -Dtriplet=x86_64-unknown-linux-musl \
  -Dtests=false \
  -Ddocs=disabled \
  -Dintrospection=disabled \
  -Dvala=disabled

# 6. Build and strip the binary
ninja -C build
strip build/rsvg-convert

# 7. (Optional) Verify static linking
ldd build/rsvg-convert || true
