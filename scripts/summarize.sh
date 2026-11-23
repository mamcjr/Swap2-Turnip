#!/bin/bash
# summary of a compare-set.sh TSV
f=${1:-$HOME/turnip-swap2/results/mesh-direct.tsv}
echo "rows: $(($(wc -l < "$f") - 1))"
echo "same_asm:"; tail -n +2 "$f" | cut -f6 | sort | uniq -c
echo "exits:"; tail -n +2 "$f" | cut -f7,8 | sort | uniq -c
tail -n +2 "$f" | awk -F'\t' '{split($2,a,":"); split($4,b,":"); bs+=a[2]; ps+=b[2]; bm+=$3; pm+=$5; if($3>mb){mb=$3;mn=$1}; if($5>mp)mp=$5; n++}
 END {printf "n=%d total_sec base=%.0f patched=%.0f; mean peak base=%.0f MB patched=%.0f MB; max base=%.0f MB (%s) max patched=%.0f MB\n", n, bs, ps, bm/n/1024, pm/n/1024, mb/1024, mn, mp/1024}'
echo "largest base peaks:"; tail -n +2 "$f" | sort -t$'\t' -k3 -n -r | head -5 | cut -f1-6
