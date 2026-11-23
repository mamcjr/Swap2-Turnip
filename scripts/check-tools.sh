#!/bin/bash
for t in meson ninja bison flex glslangValidator pkg-config cmake python3 clang git; do printf "%s: " $t; command -v $t || echo MISSING; done
python3 -c 'import mako' 2>/dev/null && echo "mako ok" || echo "mako MISSING"
python3 -c 'import yaml' 2>/dev/null && echo "yaml ok" || echo "yaml MISSING"
python3 -c 'import packaging' 2>/dev/null && echo "packaging ok" || echo "packaging MISSING"
python3 -m venv --help >/dev/null 2>&1 && echo "venv ok"
python3 --version
