#!/bin/bash
# Compile every module of a folder with the unpatched (build-host-base) and patched (build-host)
# drivers; one TSV line per module: name, seconds and peak RSS (KiB) of each, whether the ir3
# disassembly is identical. usage: compare-set.sh <out.tsv> <jobs> <module.spv>...
here=$(cd "$(dirname "$0")" && pwd)
TS=${TS:-$HOME/turnip-swap2}
T=$TS/tools-bin
out=$1; jobs=$2; shift 2
bash "$here/run-compile.sh" "$1" > /dev/null 2>&1   # builds tu_compile
one() {
  spv=$1; n=$(basename "$spv" .spv); w=$(mktemp -d)
  python3 -I "$here/../tools/spv_layout.py" "$spv" > "$w/l"
  for b in base patched; do
    B=$TS/build-host; [ $b = base ] && B=$TS/build-host-base
    ( ulimit -v 7000000
      LD_PRELOAD=$B/src/freedreno/drm-shim/libfreedreno_noop_drm_shim.so FD_GPU_ID=830 MESA_SHADER_CACHE_DISABLE=true IR3_SHADER_DEBUG=disasm \
        timeout 600 "$T/tu_compile" "$B/src/freedreno/vulkan/libvulkan_freedreno.so" "$spv" "$w/l" > "$w/$b" 2>&1 )
    echo "exit=$?" >> "$w/$b"
  done
  for b in base patched; do
    s[$b]=$(grep -m1 '^result' "$w/$b" | awk '{print $2":"$4}')
    r[$b]=$(grep -m1 '^rss' "$w/$b" | awk '{print $4}')
    h[$b]=$(grep -v '^result\|^rss\|^device\|^exit\|seconds' "$w/$b" | sha1sum | cut -c1-12)
    e[$b]=$(grep '^exit' "$w/$b")
  done
  same=no; [ "${h[base]}" = "${h[patched]}" ] && same=yes
  printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" "$n" "${s[base]}" "${r[base]}" "${s[patched]}" "${r[patched]}" "$same" "${e[base]}" "${e[patched]}"
  rm -rf "$w"
}
declare -A s r h e
export -f one; export TS T here
printf "module\tbase_result:sec\tbase_peak_kb\tpatched_result:sec\tpatched_peak_kb\tsame_asm\tbase_exit\tpatched_exit\n" > "$out"
printf "%s\n" "$@" | xargs -P "$jobs" -I{} bash -c 'declare -A s r h e; one "$@"' _ {} >> "$out"
echo "done: $(($(wc -l < "$out") - 1)) modules, identical: $(grep -c "	yes	" "$out")"
