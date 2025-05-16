# linux-static.sh
#!/usr/bin/env sh
set -euo pipefail

# Ensure correct HOME for rustup
export HOME=/root
export RUSTUP_HOME="$HOME/.rustup"
export CARGO_HOME="$HOME/.cargo"
export PATH="$CARGO_HOME/bin:$PATH"

# 1. Install build tools and static library dependencies (Alpine)
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
  libressl-dev \
  openssl \
  ca-certificates \
  zlib-dev  \
  zlib-static

update-ca-certificates

# 3. Install Rustup and add MUSL target
if [ ! -x "$(command -v rustup)" ]; then
  curl https://sh.rustup.rs -sSf | sh -s -- -y
fi
export PATH="$CARGO_HOME/bin:$PATH"
rustup target add x86_64-unknown-linux-musl

# Ensure cargo-cbuild is installed for Meson
if ! command -v cargo-cbuild >/dev/null 2>&1; then
  cargo install cargo-c
fi

# 4. Clone librsvg source and enter directory
git clone --depth 1 https://gitlab.gnome.org/GNOME/librsvg.git
cd librsvg

# 4. Vendor Rust dependencies to avoid network SSL issues
mkdir -p .cargo
cargo vendor > .cargo/config || true

# 5. Patch ci/Cargo.toml: insert version under [package] if missing
if ! grep -q '^version' ci/Cargo.toml; then
  sed -i '/^\[package\]/a version = "0.0.0"' ci/Cargo.toml
fi

# 5. Vendor and build C dependencies via Meson wraps (avoid system libs)
# Ensure subprojects directory exists
mkdir -p subprojects
# Install wraps for key C libraries
meson wrap install glib
meson wrap install cairo
meson wrap install pango
meson wrap install pixman
meson wrap install gdk-pixbuf
meson wrap install fontconfig
meson wrap install expat
git clone --depth 1 https://github.com/freetype/freetype.git subprojects/freetype
meson wrap install zlib

# 6. Configure Meson for static build
meson setup build \
  --wrap-mode=forcefallback \
  --buildtype=release \
  --default-library=static \
  -Dtriplet=x86_64-unknown-linux-musl \
  -Dtests=false \
  -Ddocs=disabled \
  -Dintrospection=disabled \
  -Dvala=disabled

# 7. Build and strip symbols
ninja -C build
strip build/rsvg-convert

# 8. (Optional) Verify static binary
ldd build/rsvg-convert || true
