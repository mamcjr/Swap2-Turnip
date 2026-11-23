#!/bin/bash
# adds u_gralloc_get_compression_usage (op + API)
set -euo pipefail
cd ~/turnip-swap2/mesa/src/util/u_gralloc
grep -q get_compression_usage u_gralloc_internal.h || sed -i 's/^   int (\*destroy)(struct u_gralloc \*gralloc);$/   int (*destroy)(struct u_gralloc *gralloc);\n   \/* the usage bits that ask this allocator for a compressed (UBWC) buffer *\/\n   int (*get_compression_usage)(struct u_gralloc *gralloc, uint64_t *out_usage);/' u_gralloc_internal.h
grep -q u_gralloc_get_compression_usage u_gralloc.h || sed -i 's/^int u_gralloc_get_type(struct u_gralloc \*gralloc);$/int u_gralloc_get_type(struct u_gralloc *gralloc);\n\nint u_gralloc_get_compression_usage(struct u_gralloc *gralloc,\n                                    uint64_t *out_usage);/' u_gralloc.h
grep -q u_gralloc_get_compression_usage u_gralloc.c || cat >> u_gralloc.c <<'C'

int
u_gralloc_get_compression_usage(struct u_gralloc *gralloc, uint64_t *out_usage)
{
   if (!gralloc || !gralloc->ops.get_compression_usage)
      return -ENOTSUP;

   return gralloc->ops.get_compression_usage(gralloc, out_usage);
}
C
grep -n "get_compression_usage" u_gralloc_internal.h u_gralloc.h u_gralloc.c
