#!/bin/bash
# Build tools for the Mesa Android cross-build, without root: meson and mako in a venv,
# bison and flex unpacked from Ubuntu's own .deb files into a user prefix.
set -euo pipefail
TS=${TS:-$HOME/turnip-swap2}
mkdir -p "$TS/tools/debs" "$TS/tools/prefix"
python3 -m venv "$TS/venv"
"$TS/venv/bin/pip" install -q --upgrade pip
"$TS/venv/bin/pip" install -q meson mako pyyaml packaging
cd "$TS/tools/debs"
apt-get download bison flex libfl2 libfl-dev m4 2>&1 | tail -3
for d in *.deb; do dpkg -x "$d" "$TS/tools/prefix"; done
ls "$TS/tools/prefix/usr/bin"
"$TS/venv/bin/meson" --version
