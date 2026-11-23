# source this: PATH and variables for the Turnip build
export TS=${TS:-$HOME/turnip-swap2}
export NDK=${NDK:-$HOME/android-ndk-r30}
export PATH="$TS/venv/bin:$TS/tools/prefix/usr/bin:$PATH"
export BISON_PKGDATADIR="$TS/tools/prefix/usr/share/bison"
export M4="$TS/tools/prefix/usr/bin/m4"
