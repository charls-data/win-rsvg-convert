# linux-static.sh
#!/usr/bin/env sh
set -euo pipefail

# This script performs a fully static build of rsvg-convert on Alpine Linux

# 1. Install build tools and static library dependencies
apk update
apk add --no-cache \
  build-base \
  meson \
  ninja \
  pkgconfig \
  curl \
  git \
  musl-dev \
  libunwind-dev \
  glib-dev \
  cairo-dev \
  pango-dev \
  libxml2-dev \
  freetype-dev \
  pixman-dev \
  gdk-pixbuf-dev \
  openssl-dev \
  zlib-dev  # Ensure zlib static library is available for -lz linking

# 2. Install Rustup and add MUSL target
if [ ! -x "$(command -v rustup)" ]; then
  curl https://sh.rustup.rs -sSf | sh -s -- -y
  export PATH="$HOME/.cargo/bin:$PATH"
else
  export PATH="$HOME/.cargo/bin:$PATH"
fi
rustup target add x86_64-unknown-linux-musl
# Ensure cargo-c (for cargo cbuild) is available
if ! command -v cargo-cbuild >/dev/null 2>&1; then
  cargo install cargo-c
fi

# 3. Clone librsvg and enter source directory
git clone --depth 1 https://gitlab.gnome.org/GNOME/librsvg.git
cd librsvg

# 4. Patch ci/Cargo.toml: insert version in [package] if missing
if ! grep -q '^version' ci/Cargo.toml; then
  sed -i '/^\[package\]/a version = "0.0.0"' ci/Cargo.toml
fi

# 5. Configure Meson for static build
meson setup build \
  --default-library=static \
  -Dtriplet=x86_64-unknown-linux-musl \
  -Dtests=false \
  -Ddocs=disabled \
  -Dintrospection=disabled \
  -Dvala=disabled

# 6. Compile and strip symbols
ninja -C build
strip build/rsvg-convert

# 7. Optional: verify the binary is static
ldd build/rsvg-convert || true
