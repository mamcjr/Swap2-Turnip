#!/bin/bash
# Temporary: log what vk_common_GetSwapchainGrallocUsage2ANDROID returns (diagnostic build only).
set -e
cd ~/turnip-swap2/mesa
F=src/vulkan/runtime/vk_android.c
grep -q '"util/log.h"' $F || sed -i '0,/#include "util\/os_misc.h"/s//#include "util\/os_misc.h"\n#include "util\/log.h"/' $F
python3 - "$F" <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
old="""      *grallocProducerUsage |= compression_usage;

   return VK_SUCCESS;
}"""
new="""      *grallocProducerUsage |= compression_usage;

   mesa_logi("swapchain usage2: format %d image usage 0x%x swapchain usage 0x%x gralloc %d compression 0x%llx -> producer 0x%llx consumer 0x%llx",
             format, imageUsage, swapchainImageUsage, gralloc ? (int)u_gralloc_get_type(gralloc) : -1,
             (unsigned long long)compression_usage, (unsigned long long)*grallocProducerUsage,
             (unsigned long long)*grallocConsumerUsage);
   return VK_SUCCESS;
}"""
if "swapchain usage2:" not in s:
    assert old in s; s=s.replace(old,new); open(p,'w').write(s)
PY
grep -n "swapchain usage2\|util/log.h" $F
