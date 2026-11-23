#!/bin/bash
set -e
cd ~/turnip-swap2/mesa
python3 - src/vulkan/runtime/vk_android.c <<'PY'
import re,sys
p=sys.argv[1]; s=open(p).read()
s=re.sub(r'\n   mesa_logi\("swapchain usage2:.*?\);\n', '\n', s, flags=re.S)
s=re.sub(r'      mesa_logi\("ahb usage:.*?\);\n', '', s, flags=re.S)
s=s.replace('#include "util/os_misc.h"\n#include "util/log.h"\n','#include "util/os_misc.h"\n')
open(p,'w').write(s)
PY
grep -c "mesa_logi(\"swapchain usage2\|mesa_logi(\"ahb usage" src/vulkan/runtime/vk_android.c || true
sed -n '/^vk_common_GetSwapchainGrallocUsage2ANDROID(/,/^}/p' src/vulkan/runtime/vk_android.c | tail -12
