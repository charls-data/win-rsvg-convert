# Fully static build of rsvg-convert: build all C deps from source under musl + static libs

#!/usr/bin/env sh
set -euo pipefail

# 1. Install essential toolchain
APK_DEPS="build-base musl-dev pkgconfig curl git meson ninja ca-certificates openssl libressl-dev zlib-dev zlib-static shared-mime-info"
apk update
apk add --no-cache $APK_DEPS
update-ca-certificates
# export SSL_CERT_FILE=/etc/ssl/certs/ca-certificates.crt

# 2. Set installation prefix and pkg-config paths
RPATH=${GITHUB_WORKSPACE}
PREFIX=$RPATH/CI_BIN
mkdir -p $PREFIX
export PKG_CONFIG_PATH=$PREFIX/lib/pkgconfig:$PKG_CONFIG_PATH
export PATH=$PREFIX/bin:$PATH
DeepBlueWhite="\033[48;2;0;0;139m\033[38;2;255;255;255m"
NC="\033[0m"

echo RPATH: $RPATH
echo HOME: $HOME
echo PKG_CONFIG_PATH: $PKG_CONFIG_PATH
haha

# 3. Build gdk-pixbuf
echo -e "${DeepBlueWhite}============================================================${NC}"
echo -e "${DeepBlueWhite}Building gdk-pixbuf...${NC}"
git clone --depth 1 --no-tags https://gitlab.gnome.org/GNOME/gdk-pixbuf.git
mkdir -p _build_gdk_pixbuf && cd _build_gdk_pixbuf
meson setup ../gdk-pixbuf \
    --buildtype=release \
    --prefix=$PREFIX \
    -Dman=false \
    -Dglycin=disabled \
    -Ddefault_library=static
ninja install
cd ..
rm -rf _build_gdk_pixbuf
echo -e "${DeepBlueWhite}============================================================${NC}"

ls $PREFIX/bin
ls $PREFIX/lib
ls $PREFIX/lib/pkgconfig
ls $PREFIX/include
