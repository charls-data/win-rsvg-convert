# =============================================================================
#  ENV
# =============================================================================
# Path
$env:rpath = $env:GITHUB_WORKSPACE
$env:INST = "${env:rpath}\rsvg.ci.bin"
$env:INST_PSX = $env:INST.Replace('\','/')
$env:EINC = "${env:INST}\include"
$env:EINC_GLIB = "${env:INST}\include\glib-2.0"
$env:EINC_GLIB_INC = "${env:INST}\lib\glib-2.0\include"
$env:ELIB = "${env:INST}\lib"

# Rust Version
$env:RUST_VER = '1.82.0'
$env:RUST_HOST = 'x86_64-pc-windows-msvc'

# Package Version
$env:LIBXML2_VER = '2.12.6'
$env:FREETYPE2_VER = '2.13.0'
$env:PKG_CONFIG_VER = '0.29.2'

# Preference
$ErrorActionPreference = 'Stop'
$esc = [char]27
$DeepBlueWhite = "$esc[48;2;0;0;139m$esc[38;2;255;255;255m"

# =============================================================================
#  Install Meson
# =============================================================================
pip3 install --upgrade --user "meson~=1.2"

# =============================================================================
#  Setup MSVC Env and update ENVs
# =============================================================================
$vsPath = & "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe" `
    -latest -products * `
    -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 `
    -property installationPath
$vsScript = Join-Path $vsPath 'Common7\Tools\Launch-VsDevShell.ps1'
& $vsScript -HostArch amd64 -Arch amd64 -SkipAutomaticLocation

# Update INCLUDE and LIB (will reset by msvc script)
$env:INCLUDE = "$env:EINC_GLIB;$env:EINC_GLIB_INC;$env:EINC;$env:INCLUDE"
$env:LIB = "$env:ELIB;$env:LIB"

# Update PATH
$env:PATH = "$env:USERPROFILE\AppData\Roaming\Python\Python39\Scripts;$env:PATH"
$env:PATH = "$env:USERPROFILE\.cargo\bin;$env:PATH"
$env:PATH = "$env:INST\bin;$env:PATH"

Write-Host ""
Write-Host "${DeepBlueWhite}=============================="
Write-Host "${DeepBlueWhite}Environment Variables:"
Write-Host "PATH: $env:PATH"
Write-Host "INCLUDE: $env:INCLUDE"
Write-Host "LIB: $env:LIB"
Write-Host "INST_PSX: $env:INST_PSX"
Write-Host "${DeepBlueWhite}=============================="
Write-Host ""

# =============================================================================
#  Build gdk-pixbuf
# =============================================================================
Write-Host "${DeepBlueWhite}=============================="
Write-Host "${DeepBlueWhite}Build gdk-pixbuf:"
Write-Host ""

git clone --depth 1 --no-tags https://gitlab.gnome.org/GNOME/gdk-pixbuf.git
md _build_gdk_pixbuf && cd _build_gdk_pixbuf
meson setup ..\gdk-pixbuf `
    --buildtype=release `
    --prefix=${env:INST_PSX} `
    -Dman=false `
    -Dglycin=disabled `
    -Ddefault_library=static
ninja install
cd ..
Remove-Item -Path "_build_gdk_pixbuf" -Recurse -Force

# get lib manually
$libMappings = @{
    "libffi.a" = "ffi.lib"
    "libgdk_pixbuf-2.0.a" = "gdk_pixbuf-2.0.lib"
    "libgio-2.0.a" = "gio-2.0.lib"
    "libgirepository-2.0.a" = "girepository-2.0.lib"
    "libglib-2.0.a" = "glib-2.0.lib"
    "libgmodule-2.0.a" = "gmodule-2.0.lib"
    "libgobject-2.0.a" = "gobject-2.0.lib"
    "libgthread-2.0.a" = "gthread-2.0.lib"
    "libintl.a" = "intl.lib"
    "libjpeg.a" = "jpeg.lib"
    "libpcre2-16.a" = "pcre2-16.lib"
    "libpcre2-32.a" = "pcre2-32.lib"
    "libpcre2-8.a" = "pcre2-8.lib"
    "libpcre2-posix.a" = "pcre2-posix.lib"
    "libpng16.a" = "png16.lib"
    "libz.a" = "z.lib"
}
foreach ($src in $libMappings.Keys) {
    Copy-Item -Path "${env:INST}\lib\$src" -Destination "${env:INST}\lib\$($libMappings[$src])" -Force
}
Copy-Item -Path "${env:INST}\lib\libz.a" -Destination "${env:INST}\lib\zlib.lib" -Force
Get-ChildItem "${env:INST}\lib"
Write-Host "${DeepBlueWhite}=============================="

# =============================================================================
#  Download and extract pkg-config, freetype, libxml2
# =============================================================================
Write-Host "${DeepBlueWhite}=============================="
Write-Host "${DeepBlueWhite}Download and Extract pkg-config, freetype and libxml2:"
Write-Host ""

# Download
curl -L https://pkgconfig.freedesktop.org/releases/pkg-config-${env:PKG_CONFIG_VER}.tar.gz -o pkg-config.tar.gz
curl -L https://downloads.sourceforge.net/freetype/freetype-${env:FREETYPE2_VER}.tar.xz -o freetype.tar.xz
curl -L https://download.gnome.org/sources/libxml2/2.12/libxml2-${env:LIBXML2_VER}.tar.xz -o libxml2.tar.xz
curl -L https://wrapdb.mesonbuild.com/v2/libxml2_${env:LIBXML2_VER}-1/get_patch -o libxml2_patch.zip

# untar
tar -xf pkg-config.tar.gz
tar -xf freetype.tar.xz
tar -xf libxml2.tar.xz
tar -xf libxml2_patch.zip

# delete tar files
Remove-Item -Path "pkg-config.tar.gz", "freetype.tar.xz", "libxml2.tar.xz", "libxml2_patch.zip" -Force
Write-Host "${DeepBlueWhite}=============================="
Write-Host ""

# =============================================================================
#  Build pkg-config
# =============================================================================
Write-Host "${DeepBlueWhite}=============================="
Write-Host "${DeepBlueWhite}Build gdk-pixbuf:"
Write-Host ""

cd "pkg-config-${env:PKG_CONFIG_VER}"
# patch
Copy-Item -Path "..\patches\pkgconfig-Makefile.vc" -Destination "Makefile.vc" -Force

# build via nmake
nmake /f Makefile.vc CFG=release
Copy-Item -Path "release\x64\pkg-config.exe" -Destination "${env:INST}\bin" -Force
nmake /f Makefile.vc CFG=release clean
cd ..

Write-Host "${DeepBlueWhite}pkg-config.exe path:"
where.exe pkg-config.exe
Write-Host "${DeepBlueWhite}=============================="
Write-Host ""

# =============================================================================
#  Build Freetype
# =============================================================================
Write-Host "${DeepBlueWhite}=============================="
Write-Host "${DeepBlueWhite}Build FreeType:"
Write-Host ""

md _build_ft && cd _build_ft
meson setup ..\freetype-${env:FREETYPE2_VER} `
    --buildtype=release `
    --prefix=${env:INST_PSX} `
    --pkg-config-path=${env:INST}\lib\pkgconfig `
    --cmake-prefix-path=${env:INST} `
    -Ddefault_library=static
ninja install
cd ..
Remove-Item -Path "_build_ft" -Recurse -Force
Copy-Item -Path "${env:INST}\lib\libfreetype.a" -Destination "${env:INST}\lib\freetype.lib" -Force
Write-Host "${DeepBlueWhite}=============================="
Write-Host ""

# =============================================================================
#  Build libxml2
# =============================================================================
Write-Host "${DeepBlueWhite}=============================="
Write-Host "${DeepBlueWhite}Build libxml2:"
Write-Host ""
md _build_libxml && cd _build_libxml
meson setup ..\libxml2-${env:LIBXML2_VER} `
    --buildtype=release `
    --prefix=${env:INST_PSX} `
    -Diconv=disabled `
    --pkg-config-path=${env:INST}\lib\pkgconfig `
    --cmake-prefix-path=${env:INST} `
    -Ddefault_library=static
ninja install
cd ..
Remove-Item -Path "_build_libxml" -Recurse -Force
Copy-Item -Path "${env:INST}\lib\libxml2.a" -Destination "${env:INST}\lib\xml2.lib" -Force
Write-Host "${DeepBlueWhite}=============================="
Write-Host ""

# =============================================================================
#  Build Pango
# =============================================================================
Write-Host "${DeepBlueWhite}=============================="
Write-Host "${DeepBlueWhite}Build libxml2:"
Write-Host ""

git clone --depth 1 --no-tags https://gitlab.gnome.org/GNOME/pango.git
md _build_pango && cd _build_pango
meson setup ..\pango `
    --buildtype=release `
    --prefix=${env:INST_PSX} `
    -Dfontconfig=disabled `
    --pkg-config-path=${env:INST}\lib\pkgconfig `
    -Ddefault_library=static
ninja install
cd ..
Remove-Item -Path "_build_pango" -Recurse -Force

# get lib manually
$pangoLibMappings = @{
    "libcairo-gobject.a" = "cairo-gobject.lib"
    "libcairo-script-interpreter.a" = "cairo-script-interpreter.lib"
    "libcairo.a" = "cairo.lib"
    "libfribidi.a" = "fribidi.lib"
    "libharfbuzz-gobject.a" = "harfbuzz-gobject.lib"
    "libharfbuzz.a" = "harfbuzz.lib"
    "libpango-1.0.a" = "pango-1.0.lib"
    "libpangocairo-1.0.a" = "pangocairo-1.0.lib"
    "libpangowin32-1.0.a" = "pangowin32-1.0.lib"
    "libpixman-1.a" = "pixman-1.lib"
}
foreach ($src in $pangoLibMappings.Keys) {
    Copy-Item -Path "${env:INST}\lib\$src" -Destination "${env:INST}\lib\$($pangoLibMappings[$src])" -Force
}
Write-Host "${DeepBlueWhite}=============================="
Write-Host ""

# =============================================================================
#  Rust toolchain
# =============================================================================
Write-Host "${DeepBlueWhite}=============================="
Write-Host "${DeepBlueWhite}Setup Rust toolchain:"
Write-Host ""

if (-not (Test-Path "${env:USERPROFILE}\.cargo\bin\cargo-cbuild.exe")) {
    cargo install cargo-c
}
rustup install "${env:RUST_VER}-${env:RUST_HOST}"
Write-Host "${DeepBlueWhite}=============================="
Write-Host ""

# =============================================================================
#  Build librsvg
# =============================================================================
Write-Host "${DeepBlueWhite}=============================="
Write-Host "${DeepBlueWhite}Build librsvg:"
Write-Host ""

$env:PKG_CONFIG = "${env:INST}\bin\pkg-config.exe"
git clone --depth 1 --no-tags https://gitlab.gnome.org/GNOME/librsvg.git
# patch
Copy-Item -Path "patches\rsvg-meson.build" -Destination "librsvg\rsvg\meson.build" -Force
md librsvg\msvc-build && cd librsvg\msvc-build
meson setup .. `
    --buildtype=release `
    --prefix=${env:INST_PSX} `
    --pkg-config-path=${env:INST}\lib\pkgconfig `
    --cmake-prefix-path=${env:INST} `
    -Dtriplet=${env:RUST_HOST} `
    -Drustc-version=${env:RUST_VER} `
    -Ddefault_library=static

& ninja
& ninja install
Write-Host "${DeepBlueWhite}=============================="
Write-Host ""