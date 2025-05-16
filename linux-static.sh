#!/usr/bin/env sh
set -euo pipefail

OS=""
if [ -f /etc/os-release ]; then
  . /etc/os-release
  OS=$ID
fi

if [ "$OS" = "alpine" ]; then
  apk update
  apk add --no-cache \
    build-base meson ninja pkgconfig \
    bash curl musl-dev musl-utils \
    libunwind-dev git \
    glib-dev cairo-dev pango-dev \
    libxml2-dev freetype-dev pixman-dev \
    gdk-pixbuf-dev
elif [ -x "$(command -v apt-get)" ]; then
  sudo apt-get update
  sudo apt-get install -y \
    build-essential meson ninja-build pkg-config \
    rustc cargo cargo-c \
    curl musl-tools libunwind-dev \
    libglib2.0-dev libcairo2-dev libpango1.0-dev \
    libxml2-dev libfreetype6-dev libpixman-1-dev \
    gdk-pixbuf2.0-dev
else
  echo "Unsupported OS: $OS" >&2
  exit 1
fi

# 2. librsvg source
git clone --depth 1 --no-tags https://gitlab.gnome.org/GNOME/librsvg.git
cd librsvg
if ! grep -q '^version' ci/Cargo.toml; then
  sed -i '/^\[package\]/a version = "0.0.0"' ci/Cargo.toml
fi

# 3. rust target
rustup target add x86_64-unknown-linux-musl

# 4. setup build
meson setup build \
  --buildtype=release \
  --default-library=static \
  -Dtriplet=x86_64-unknown-linux-musl \
  -Dtests=false \
  -Ddocs=disabled \
  -Dintrospection=disabled \
  -Dvala=disabled

# 5. build
ninja -C build

# 6. Strip
strip build/rsvg-convert

# 7. check dependencies
ldd build/rsvg-convert || true
