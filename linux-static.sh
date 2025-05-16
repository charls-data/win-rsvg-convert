# linux-static.sh
#!/usr/bin/env sh
set -euo pipefail

# Fully static build of rsvg-convert: build all C deps from source under musl + static libs

# 1. Install essential toolchain
APK_DEPS="build-base musl-dev pkgconfig curl git meson ninja ca-certificates libressl-dev zlib-dev zlib-static"
apk update
apk add --no-cache $APK_DEPS
update-ca-certificates
export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

# 2. Install Rust toolchain (rustup, cargo)
if ! command -v rustup >/dev/null 2>&1; then
  curl https://sh.rustup.rs -sSf | sh -s -- -y
fi
[ -f "$HOME/.cargo/env" ] && . "$HOME/.cargo/env"
rustup target add x86_64-unknown-linux-musl
if ! command -v cargo-cbuild >/dev/null 2>&1; then
  cargo install cargo-c
fi

# 3. Set installation prefix and pkg-config paths
apk update
apk add --no-cache \
  build-base musl-dev pkgconfig curl git \
  meson ninja ca-certificates openssl zlib-dev zlib-static
update-ca-certificates
export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

# 2. Set installation prefix and pkg-config paths
PREFIX=/usr/local/static
mkdir -p $PREFIX
export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig
export PATH=$PREFIX/bin:$PATH

# 3. Helper to build a meson project
build_dep() {
  NAME=$1; REPO=$2; MESON_OPTS=$3
  echo "Building $NAME"
  git clone --depth 1 $REPO deps/$NAME
  meson setup deps/$NAME/build deps/$NAME --prefix=$PREFIX --default-library=static $MESON_OPTS
  ninja -C deps/$NAME/build install
}

# 4. Build dependencies in order
build_dep glib https://gitlab.gnome.org/GNOME/glib.git ""
build_dep pixman https://gitlab.gnome.org/GNOME/pixman.git ""
build_dep cairo https://gitlab.gnome.org/GNOME/cairo.git "-Dpixman=enabled"
build_dep fontconfig https://gitlab.gnome.org/GNOME/fontconfig.git ""
build_dep freetype https://github.com/freetype/freetype.git ""
build_dep expat https://github.com/libexpat/libexpat.git ""
build_dep brotli https://github.com/google/brotli.git ""
build_dep bzip2 https://sourceware.org/git/bzip2.git ""
build_dep harfbuzz https://github.com/harfbuzz/harfbuzz.git ""
build_dep graphite2 https://gitlab.freedesktop.org/graphite/graphite2.git ""
build_dep pangocairo https://gitlab.gnome.org/GNOME/pango.git "-Dfontconfig=enabled -Dharfbuzz=enabled"
build_dep gdk-pixbuf https://gitlab.gnome.org/GNOME/gdk-pixbuf.git ""

# 5. Clone librsvg and vendor Rust deps
git clone --depth 1 https://gitlab.gnome.org/GNOME/librsvg.git
cd librsvg
mkdir -p .cargo
cargo vendor > .cargo/config || true

# 6. Patch Cargo manifest for ci
if ! grep -q '^version' ci/Cargo.toml; then
  sed -i '/^\[package\]/a version = "0.0.0"' ci/Cargo.toml
fi

# 7. Configure and build librsvg
meson setup build --prefix=$PREFIX --default-library=static \
  -Dtriplet=x86_64-unknown-linux-musl \
  -Dtests=false -Ddocs=disabled -Dintrospection=disabled -Dvala=disabled

ninja -C build
strip build/rsvg-convert

# 8. Verification
echo "rsvg-convert linked libs:"; ldd build/rsvg-convert || true
