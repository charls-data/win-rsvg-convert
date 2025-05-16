# =============================================================================
#  ENV
# =============================================================================
# Path
$env:rpath = $env:github.workspace
$env:INST = "$($env:rpath)\rsvg.ci.bin"
$env:INST_PSX = $env:INST.Replace('\','/')
$env:EINC = "$($env:INST)\include"
$env:EINC_GLIB = "$($env:INST)\include\glib-2.0"
$env:EINC_GLIB_INC = "$($env:INST)\include\glib-2.0\include"
$env:ELIB = "$($env:INST)\lib"

# Rust Version
$env:RUST_DOWNGRADE_VER = '1.82.0'
$env:RUST_HOST = 'x86_64-pc-windows-msvc'

# Package Version
$env:LIBXML2_VER = '2.12.6'
$env:FREETYPE2_VER = '2.13.0'
$env:PKG_CONFIG_VER = '0.29.2'

# Preference
$ErrorActionPreference = 'Stop'

# =============================================================================
#  Install Meson
# =============================================================================
pip3 install --upgrade --user "meson~=1.2"

# =============================================================================
#  Setup MSVC Env and update ENVs
# =============================================================================
& '$env:ProgramFiles\Microsoft Visual Studio\2022\Enterprise\Common7\Tools\Launch-VsDevShell.ps1' `
    -HostArch amd64 -Arch amd64 -SkipAutomaticLocation

# Update INCLUDE and LIB (will reset by msvc script)
$env:INCLUDE = "$env:EINC_GLIB;$env:EINC_GLIB_INC;$env:EINC;$env:INCLUDE"
$env:LIB = "$env:ELIB;$env:LIB"

# Update PATH
$env:PATH = "$env:USERPROFILE\AppData\Roaming\Python\Python39\Scripts;$env:PATH"
$env:PATH = "$env:USERPROFILE\.cargo\bin;$env:PATH"
$env:PATH = "$env:INST\bin;$env:PATH"

Write-Host "PATH: $env:PATH"
Write-Host "INCLUDE: $env:INCLUDE"
Write-Host "LIB: $env:LIB"

# =============================================================================
#  Build gdk-pixbuf
# =============================================================================
git clone --depth 1 --no-tags https://gitlab.gnome.org/GNOME/gdk-pixbuf.git
md _build_pango && cd _build_pango
meson setup ..\gdk-pixbuf `
    --buildtype=release `
    --prefix=$env:INST_PSX `
    -Dman=false `
    -Dglycin=disabled `
    -Ddefault_library=static
ninja install
Set-Location -Path ".."
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
    Copy-Item -Path "$env:INST\lib\$src" -Destination "$env:INST\lib\$($libMappings[$src])" -Force
}
Copy-Item -Path "$env:INST\lib\libz.a" -Destination "$env:INST\lib\zlib.lib" -Force
