#!/bin/bash
TS=$HOME/turnip-swap2
mkdir -p "$TS/modules/mesh-direct" "$TS/modules/mesh-undefer"
cp -u "/mnt/d/Games/ZORCT ROM/0400486024DEC000-work/mesh-direct/"*_5.spv "$TS/modules/mesh-direct/"
cp -u "/mnt/d/Games/ZORCT ROM/0400486024DEC000-work/mesh-undefer/"*_5.spv "$TS/modules/mesh-undefer/"
du -sh "$TS/modules"
cd "$TS/modules/mesh-direct"
bash /mnt/d/Projetos/Jogos/Android/turnip-swap2/scripts/compare-set.sh "$TS/results/mesh-direct.tsv" 4 $(ls -S "$PWD"/*_5.spv)
