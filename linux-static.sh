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
  openssl-dev \
  zlib-dev  \
  zlib-static

# 2. Verify static zlib library presence and configure linker path
ZLIB_A=""
for path in /lib/libz.a /usr/lib/libz.a /usr/lib/x86_64-linux-gnu/libz.a; do
  if [ -f "$path" ]; then
    ZLIB_A="$path"
    break
  fi
done
if [ -z "$ZLIB_A" ]; then
  echo "Error: static zlib library not found. Please install zlib-dev or zlib1g-dev." >&2
  exit 1
fi
haha
export LIBRARY_PATH="$(dirname "$ZLIB_A")${LIBRARY_PATH:+:}$LIBRARY_PATH"
# Copy static zlib into Rust MUSL sysroot to satisfy -lz
SYSROOT="$(rustc --print sysroot)/lib/rustlib/x86_64-unknown-linux-musl/lib"
cp "$ZLIB_A" "$SYSROOT/"

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

# 5. Patch ci/Cargo.toml: insert version under [package] if missing
if ! grep -q '^version' ci/Cargo.toml; then
  sed -i '/^\[package\]/a version = "0.0.0"' ci/Cargo.toml
fi

# 6. Configure Meson for static build
meson setup build \
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
