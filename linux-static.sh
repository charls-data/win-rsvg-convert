#!/usr/bin/env bash
set -euo pipefail

# 1. install dependencies
sudo apt-get update
sudo apt-get install -y \
  build-essential \
  meson \
  ninja-build \
  pkg-config \
  rustc \
  cargo \
  cargo-c \
  musl-tools \
  libglib2.0-dev \
  libcairo2-dev \
  libpango1.0-dev \
  libxml2-dev \
  libfreetype6-dev \
  libpixman-1-dev \
  gdk-pixbuf2.0-dev

# 2. librsvg source
git clone --depth 1 --no-tags https://gitlab.gnome.org/GNOME/librsvg.git
cd librsvg

# 3. setup build
meson setup build \
  --buildtype=release \
  --default-library=static \
  -Dtriplet=x86_64-unknown-linux-musl \
  -Dtests=false \
  -Ddocs=disabled \
  -Dintrospection=disabled \
  -Dvala=disabled

# 4. build
ninja -C build

# 5. Strip
strip build/rsvg-convert

# 6. check dependencies
ldd build/rsvg-convert || true
