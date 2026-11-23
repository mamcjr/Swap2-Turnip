#!/bin/bash
cd ~/turnip-swap2/mesa
grep -n "os_get_option\b\|^debug_get_bool_option\|^os_get_option" src/util/os_misc.h src/util/u_debug.h | head
grep -n "#include" src/vulkan/runtime/vk_android.c | head -30
