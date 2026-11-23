#!/bin/bash
# The UBWC request moves into a helper used by both the gralloc-usage query and the AHB usage report
# (Android 14+ loaders take the swapchain's producer usage from VkAndroidHardwareBufferUsageANDROID).
set -e
cd ~/turnip-swap2/mesa
python3 - src/vulkan/runtime/vk_android.c <<'PY'
import sys
p=sys.argv[1]; s=open(p).read()
old_block = s[s.index("   /* A compressed (UBWC) swapchain buffer when the allocator makes one on"):s.index("   mesa_logi(\"swapchain usage2:")]
new_call = """   uint64_t compression_usage =
      vk_android_compression_usage(format, imageUsage, 0,
                                   swapchainImageUsage & VK_SWAPCHAIN_IMAGE_USAGE_SHARED_BIT_ANDROID);
   *grallocProducerUsage |= compression_usage;

"""
s = s.replace(old_block, new_call)
helper = """/* The allocator usage bit that asks for a compressed (UBWC) buffer, for an
 * image the display or another GPU client reads and Turnip writes: when the
 * allocator makes one on request and the gralloc backend reads its layout
 * back (the import then gets the QCOM_COMPRESSED modifier). Less bandwidth
 * for the GPU's writes and the display's reads. Color attachments of 8-bit
 * RGBA formats, no storage use, not mutable, not protected, not shared
 * (front buffer); MESA_ANDROID_SWAPCHAIN_UBWC=0 turns it off.
 */
static uint64_t
vk_android_compression_usage(VkFormat format, VkImageUsageFlags usage,
                             VkImageCreateFlags flags, bool shared)
{
   const char *opt = os_get_option("MESA_ANDROID_SWAPCHAIN_UBWC");
   if (opt && !strcmp(opt, "0"))
      return 0;
   const bool ubwc_format =
      format == VK_FORMAT_R8G8B8A8_UNORM || format == VK_FORMAT_R8G8B8A8_SRGB ||
      format == VK_FORMAT_B8G8R8A8_UNORM || format == VK_FORMAT_B8G8R8A8_SRGB;
   if (!ubwc_format || shared ||
       !(usage & VK_IMAGE_USAGE_COLOR_ATTACHMENT_BIT) ||
       (usage & VK_IMAGE_USAGE_STORAGE_BIT) ||
       (flags & (VK_IMAGE_CREATE_MUTABLE_FORMAT_BIT | VK_IMAGE_CREATE_PROTECTED_BIT)))
      return 0;
   struct u_gralloc *gralloc = vk_android_get_ugralloc();
   uint64_t compression_usage = 0;
   if (!gralloc || u_gralloc_get_compression_usage(gralloc, &compression_usage) != 0)
      return 0;
   return compression_usage;
}

VKAPI_ATTR VkResult VKAPI_CALL
vk_common_GetSwapchainGrallocUsage2ANDROID("""
s = s.replace("VKAPI_ATTR VkResult VKAPI_CALL\nvk_common_GetSwapchainGrallocUsage2ANDROID(", helper, 1)
s = s.replace("compression 0x%llx -> producer", "compression 0x%llx -> producer")
old_ahb = """   if (ahb_usage_props)
      ahb_usage_props->androidHardwareBufferUsage = ahb_usage;
"""
new_ahb = """   if (ahb_usage_props) {
      /* Android 14+ loaders take a swapchain's producer usage from here, not
       * from vkGetSwapchainGrallocUsage*ANDROID. Only the reported usage asks
       * for compression; the probe above stays the plain one.
       */
      const uint64_t compression_usage =
         info->tiling == VK_IMAGE_TILING_OPTIMAL ?
         vk_android_compression_usage(info->format, info->usage, info->flags, false) : 0;
      ahb_usage_props->androidHardwareBufferUsage = ahb_usage | compression_usage;
      mesa_logi("ahb usage: format %d usage 0x%x flags 0x%x tiling %d -> 0x%llx (compression 0x%llx)",
                info->format, info->usage, info->flags, info->tiling,
                (unsigned long long)ahb_usage_props->androidHardwareBufferUsage,
                (unsigned long long)compression_usage);
   }
"""
assert old_ahb in s; s = s.replace(old_ahb, new_ahb)
open(p,'w').write(s)
PY
grep -n "vk_android_compression_usage\|ahb usage:\|swapchain usage2:" src/vulkan/runtime/vk_android.c
