# Fully static build of rsvg-convert: build all C deps from source under musl + static libs

#!/usr/bin/env sh
set -euo pipefail

# 1. Install essential toolchain
APK_DEPS="build-base autoconf automake libtool m4 musl-dev pkgconfig curl git meson ninja ca-certificates openssl libressl-dev zlib-dev zlib-static shared-mime-info cmake linux-headers"
apk update
apk add --no-cache $APK_DEPS
update-ca-certificates
export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt
export SSL_CERT_DIR=/etc/ssl/certs
export OPENSSL_CERT_FILE=$SSL_CERT_FILE
echo "Using SSL_CERT_FILE=$SSL_CERT_FILE"
haha

# 2. Set installation prefix and pkg-config paths
RPATH=${GITHUB_WORKSPACE}
PREFIX=$RPATH/CI_BIN
mkdir -p $PREFIX
export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig
export PATH=$PREFIX/bin:$PATH
# export LIBRARY_PATH="$PREFIX/lib:${LIBRARY_PATH:-}"
# export C_INCLUDE_PATH="$PREFIX/include:${C_INCLUDE_PATH:-}"
DeepBlueWhite="\033[48;2;0;0;139m\033[38;2;255;255;255m"
NC="\033[0m"

echo RPATH: $RPATH
echo HOME: $HOME
echo PKG_CONFIG_PATH: $PKG_CONFIG_PATH

# Build unwind
echo -e "${DeepBlueWhite}============================================================${NC}"
echo -e "${DeepBlueWhite}Building unwind...${NC}"
git clone https://github.com/libunwind/libunwind.git
cd libunwind
autoreconf -i
mkdir build && cd build
unwind_version=$(
  ../configure --version \
    | head -n1 \
    | awk '{ print $NF }'
)
../configure \
  --prefix="$PREFIX"    \
  --enable-static       \
  --disable-shared      \
  --disable-tests       \
  CFLAGS="-O2 -D__linux__"   \
  LDFLAGS="-L$PREFIX/lib"
make -j"$(nproc)"
make install
cat > "$PREFIX/lib/pkgconfig/libunwind.pc" <<EOF
prefix=$PREFIX
exec_prefix=\${prefix}
libdir=\${exec_prefix}/lib
includedir=\${prefix}/include

Name: libunwind
Description: LLVM libunwind library
Version: $unwind_version
Libs: -L\${libdir} -lunwind
Cflags: -I\${includedir}
EOF
cat "$PREFIX/lib/pkgconfig/libunwind.pc"
cd ..
cd ..
rm -rf libunwind
echo -e "${DeepBlueWhite}============================================================${NC}"

# 3. Build gdk-pixbuf
echo -e "${DeepBlueWhite}============================================================${NC}"
echo -e "${DeepBlueWhite}Building gdk-pixbuf...${NC}"
git clone --depth 1 --no-tags https://gitlab.gnome.org/GNOME/gdk-pixbuf.git
cd gdk-pixbuf
echo "download"
meson subprojects download
echo "ls subprojects/glib"
ls subprojects/glib
echo "end"
sed -i "/# Is statx()/,/endif/ s/if host_system != 'android'.*/if false/" subprojects/glib/meson.build
sed -i "/glib_conf\.set('HAVE_STATX'/d" subprojects/glib/meson.build
cd ..
mkdir -p _build_gdk_pixbuf && cd _build_gdk_pixbuf
meson setup ../gdk-pixbuf \
    --buildtype=release \
    --prefix=$PREFIX \
    -Dman=false \
    -Dglycin=disabled \
    -Dtests=false \
    -Dinstalled_tests=false \
    -Ddefault_library=static \
    -Dglib:tests=false
ninja install
cd ..
rm -rf _build_gdk_pixbuf
echo -e "${DeepBlueWhite}============================================================${NC}"

# 4. Build freetype
echo -e "${DeepBlueWhite}============================================================${NC}"
echo -e "${DeepBlueWhite}Building freetype...${NC}"
git clone --depth 1 --no-tags https://gitlab.freedesktop.org/freetype/freetype.git
mkdir -p _build_freetype && cd _build_freetype
meson setup ../freetype \
    --buildtype=release \
    --prefix=$PREFIX \
    --pkg-config-path=$PKG_CONFIG_PATH \
    --cmake-prefix-path=$PREFIX \
    -Ddefault_library=static
ninja install
cd ..
rm -rf _build_freetype
echo -e "${DeepBlueWhite}============================================================${NC}"

# 5. Build libxml2
echo -e "${DeepBlueWhite}============================================================${NC}"
echo -e "${DeepBlueWhite}Building libxml2...${NC}"
git clone --depth 1 --no-tags https://gitlab.gnome.org/GNOME/libxml2.git
mkdir -p _build_xml && cd _build_xml
meson setup ../libxml2 \
    --buildtype=release \
    --prefix=$PREFIX \
    -Diconv=disabled \
    -Ddocs=disabled \
    --pkg-config-path=$PKG_CONFIG_PATH \
    --cmake-prefix-path=$PREFIX \
    -Ddefault_library=static
ninja install
cd ..
rm -rf _build_xml
echo -e "${DeepBlueWhite}============================================================${NC}"

# 6. Build pango
echo -e "${DeepBlueWhite}============================================================${NC}"
echo -e "${DeepBlueWhite}Building pango...${NC}"
git clone --depth 1 --no-tags https://gitlab.gnome.org/GNOME/pango.git
mkdir -p _build_pango && cd _build_pango
meson setup ../pango \
    --buildtype=release \
    --prefix=$PREFIX \
    --pkg-config-path=$PKG_CONFIG_PATH \
    -Dbuild-examples=false \
    -Dbuild-testsuite=false \
    -Ddefault_library=static \
    -Dcairo:tests=disabled \
    -Dharfbuzz:tests=disabled \
    -Dfontconfig:tests=disabled \
    -Dfribidi:tests=false
ninja install
cd ..
rm -rf _build_pango
echo -e "${DeepBlueWhite}============================================================${NC}"

# 7. Rust toolchain
echo -e "${DeepBlueWhite}============================================================${NC}"
echo -e "${DeepBlueWhite}Install Rust Toolchain...${NC}"
curl https://sh.rustup.rs -sSf | sh -s -- -y --default-toolchain none
export PATH="$HOME/.cargo/bin:$PATH"

rustup toolchain install nightly-x86_64-unknown-linux-musl
rustup default nightly-x86_64-unknown-linux-musl
rustup target add x86_64-unknown-linux-musl
rustup component add rust-src
cargo install cargo-c
export RUSTUP_TOOLCHAIN=nightly-x86_64-unknown-linux-musl

# 8. Build librsvg
echo -e "${DeepBlueWhite}============================================================${NC}"
echo -e "${DeepBlueWhite}Building librsvg...${NC}"
git clone --depth 1 --no-tags https://gitlab.gnome.org/GNOME/librsvg.git
cd librsvg
# cargo +nightly vendor vendor
mkdir -p .cargo
cat > .cargo/config.toml << 'EOF'
[build]
target = "x86_64-unknown-linux-musl"

[unstable]
build-std = ["std", "panic_abort"]
build-std-features = []

[profile.release]
panic = "abort"
EOF

if ! grep -q '^version' ci/Cargo.toml; then
  sed -i '/^\[package\]/a version = "0.0.0"' ci/Cargo.toml
fi
export LDFLAGS="-L${PREFIX}/lib ${LDFLAGS:-}"
meson setup build \
    --buildtype=release \
    --prefix=$PREFIX \
    --pkg-config-path=$PKG_CONFIG_PATH \
    --cmake-prefix-path=$PREFIX \
    -Dtriplet=x86_64-unknown-linux-musl \
    -Dtests=false \
    -Ddocs=disabled \
    -Dintrospection=disabled \
    -Dvala=disabled \
    -Ddefault_library=static
ninja -C build
strip build/rsvg-convert
ninja -C build install
echo "rsvg-convert linked libs:"; ldd build/rsvg-convert || true
