// Offline pipeline compile for a Vulkan ICD (Turnip under freedreno's no-op drm-shim on the PC):
// loads the driver library directly (no loader), makes a device with every feature and extension it
// offers, and builds one compute pipeline from a SPIR-V module whose layout comes from spv_layout.py.
// Reports the compile's wall time, the process's peak resident memory and its peak count of memory
// mappings (sampled; Android kills the process when it reaches vm.max_map_count, 65530 there).
//
// usage: tu_compile <driver.so> <module.spv> <layout.txt> [entry]
// env:   TU_REPEAT=n to build it n times
#define VK_NO_PROTOTYPES
#include <vulkan/vulkan.h>
#include <dlfcn.h>
#include <pthread.h>
#include <stdatomic.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <unistd.h>

static _Atomic int g_stop, g_peak_maps;
static int count_maps(void) {
    FILE *f = fopen("/proc/self/maps", "r");
    if (!f) return -1;
    int n = 0, c;
    char buf[65536];
    size_t r;
    while ((r = fread(buf, 1, sizeof buf, f)) > 0)
        for (size_t i = 0; i < r; i++) n += buf[i] == '\n';
    (void)c;
    fclose(f);
    return n;
}
static void *sampler(void *a) {
    (void)a;
    while (!g_stop) {
        int n = count_maps();
        if (n > g_peak_maps) g_peak_maps = n;
        usleep(2000);
    }
    return NULL;
}
static long status_kb(const char *key) {
    FILE *f = fopen("/proc/self/status", "r");
    char line[256];
    long v = -1;
    while (f && fgets(line, sizeof line, f))
        if (!strncmp(line, key, strlen(key))) v = atol(line + strlen(key));
    if (f) fclose(f);
    return v;
}
static double now(void) {
    struct timespec t;
    clock_gettime(CLOCK_MONOTONIC, &t);
    return t.tv_sec + t.tv_nsec * 1e-9;
}
#define CK(x) do { VkResult r_ = (x); if (r_) { fprintf(stderr, "%s: %d\n", #x, r_); exit(2); } } while (0)

int main(int argc, char **argv) {
    if (argc < 4) { fprintf(stderr, "usage: %s driver.so module.spv layout.txt [entry]\n", argv[0]); return 1; }
    void *lib = dlopen(argv[1], RTLD_NOW | RTLD_LOCAL);
    if (!lib) { fprintf(stderr, "dlopen: %s\n", dlerror()); return 1; }
    PFN_vkGetInstanceProcAddr gipa = (PFN_vkGetInstanceProcAddr)dlsym(lib, "vk_icdGetInstanceProcAddr");
    if (!gipa) {   // an Android build: only the hwvulkan HAL module "HMI" is exported (hardware/hwvulkan.h)
        struct hw_device { uint32_t tag, version; void *module; uint64_t reserved[12]; int (*close)(void *); };
        struct hw_methods { int (*open)(const void *module, const char *id, struct hw_device **dev); };
        struct hw_module { uint32_t tag; uint16_t mver, hver; const char *id, *name, *author; struct hw_methods *methods; void *dso; uint64_t reserved[25]; };
        struct hwvk_device { struct hw_device common; PFN_vkEnumerateInstanceExtensionProperties EnumerateInstanceExtensionProperties;
                             PFN_vkCreateInstance CreateInstance; PFN_vkGetInstanceProcAddr GetInstanceProcAddr; };
        struct hw_module *hmi = (struct hw_module *)dlsym(lib, "HMI");
        struct hw_device *d = NULL;
        if (!hmi || hmi->methods->open(hmi, "vk0", &d) || !d) { fprintf(stderr, "no vk_icdGetInstanceProcAddr and no usable HMI\n"); return 1; }
        fprintf(stderr, "HAL module: %s by %s\n", hmi->name, hmi->author);
        gipa = ((struct hwvk_device *)d)->GetInstanceProcAddr;
    }
    PFN_vkCreateInstance CreateInstance = (PFN_vkCreateInstance)gipa(NULL, "vkCreateInstance");
    VkApplicationInfo ai = {VK_STRUCTURE_TYPE_APPLICATION_INFO, .pApplicationName = "tu_compile", .apiVersion = VK_API_VERSION_1_3};
    VkInstanceCreateInfo ici = {VK_STRUCTURE_TYPE_INSTANCE_CREATE_INFO, .pApplicationInfo = &ai};
    VkInstance inst;
    CK(CreateInstance(&ici, NULL, &inst));
#define IF(n) PFN_##n n = (PFN_##n)gipa(inst, #n)
    IF(vkEnumeratePhysicalDevices); IF(vkGetPhysicalDeviceProperties); IF(vkGetPhysicalDeviceFeatures2);
    IF(vkEnumerateDeviceExtensionProperties); IF(vkCreateDevice); IF(vkGetDeviceProcAddr);
    uint32_t np = 1;
    VkPhysicalDevice pd;
    CK(vkEnumeratePhysicalDevices(inst, &np, &pd));
    VkPhysicalDeviceProperties props;
    vkGetPhysicalDeviceProperties(pd, &props);
    fprintf(stderr, "device: %s, driver 0x%x, push %u\n", props.deviceName, props.driverVersion, props.limits.maxPushConstantsSize);

    VkPhysicalDeviceVulkan13Features f13 = {VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_3_FEATURES};
    VkPhysicalDeviceVulkan12Features f12 = {VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_2_FEATURES, .pNext = &f13};
    VkPhysicalDeviceVulkan11Features f11 = {VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_VULKAN_1_1_FEATURES, .pNext = &f12};
    VkPhysicalDeviceFeatures2 f2 = {VK_STRUCTURE_TYPE_PHYSICAL_DEVICE_FEATURES_2, .pNext = &f11};
    vkGetPhysicalDeviceFeatures2(pd, &f2);
    uint32_t ne = 0;
    vkEnumerateDeviceExtensionProperties(pd, NULL, &ne, NULL);
    VkExtensionProperties *ep = calloc(ne, sizeof *ep);
    vkEnumerateDeviceExtensionProperties(pd, NULL, &ne, ep);
    if (getenv("TU_LIST_EXT")) { for (uint32_t i = 0; i < ne; i++) printf("ext %s\n", ep[i].extensionName); return 0; }
    const char **en = calloc(ne, sizeof *en);
    uint32_t nen = 0;
    for (uint32_t i = 0; i < ne; i++) {
        const char *e = ep[i].extensionName;
        if (strstr(e, "VK_KHR_swapchain") || strstr(e, "display") || strstr(e, "ANDROID")) continue;
        en[nen++] = e;
    }
    float prio = 1;
    VkDeviceQueueCreateInfo qi = {VK_STRUCTURE_TYPE_DEVICE_QUEUE_CREATE_INFO, .queueFamilyIndex = 0, .queueCount = 1, .pQueuePriorities = &prio};
    VkDeviceCreateInfo dci = {VK_STRUCTURE_TYPE_DEVICE_CREATE_INFO, .pNext = &f2, .queueCreateInfoCount = 1, .pQueueCreateInfos = &qi,
                              .enabledExtensionCount = nen, .ppEnabledExtensionNames = en};
    VkDevice dev;
    CK(vkCreateDevice(pd, &dci, NULL, &dev));
#define DF(n) PFN_##n n = (PFN_##n)vkGetDeviceProcAddr(dev, #n)
    DF(vkCreateShaderModule); DF(vkCreateDescriptorSetLayout); DF(vkCreatePipelineLayout); DF(vkCreateComputePipelines); DF(vkDestroyPipeline);

    // module
    FILE *f = fopen(argv[2], "rb");
    if (!f) { perror(argv[2]); return 1; }
    fseek(f, 0, SEEK_END);
    long sz = ftell(f);
    fseek(f, 0, SEEK_SET);
    uint32_t *code = malloc(sz);
    if (fread(code, 1, sz, f) != (size_t)sz) return 1;
    fclose(f);
    VkShaderModuleCreateInfo mi = {VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO, .codeSize = sz, .pCode = code};
    VkShaderModule mod;
    CK(vkCreateShaderModule(dev, &mi, NULL, &mod));

    // layout
    enum { MAXSET = 8, MAXB = 512 };
    VkDescriptorSetLayoutBinding b[MAXSET][MAXB];
    VkDescriptorBindingFlags bf[MAXSET][MAXB];
    uint32_t nb[MAXSET] = {0}, push = 0, nsets = 0;
    char entry[256] = "main", line[512];
    f = fopen(argv[3], "r");
    if (!f) { perror(argv[3]); return 1; }
    while (fgets(line, sizeof line, f)) {
        unsigned s, bi, t, c, m;
        char nm[256];
        if (sscanf(line, "bind %u %u %u %u", &s, &bi, &t, &c) == 4 && s < MAXSET && nb[s] < MAXB) {
            uint32_t k = nb[s]++;
            b[s][k] = (VkDescriptorSetLayoutBinding){bi, (VkDescriptorType)t, c ? c : 1024, VK_SHADER_STAGE_ALL, NULL};
            bf[s][k] = c ? 0 : VK_DESCRIPTOR_BINDING_PARTIALLY_BOUND_BIT;
            if (s + 1 > nsets) nsets = s + 1;
        } else if (sscanf(line, "push %u", &c) == 1) push = c < props.limits.maxPushConstantsSize ? c : props.limits.maxPushConstantsSize;
        else if (sscanf(line, "entry %u %255s", &m, nm) == 2 && m == 5) strcpy(entry, nm);
    }
    fclose(f);
    if (argc > 4) strcpy(entry, argv[4]);
    VkDescriptorSetLayout sl[MAXSET];
    for (uint32_t s = 0; s < nsets; s++) {
        VkDescriptorSetLayoutBindingFlagsCreateInfo fi = {VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_BINDING_FLAGS_CREATE_INFO, .bindingCount = nb[s], .pBindingFlags = bf[s]};
        VkDescriptorSetLayoutCreateInfo li = {VK_STRUCTURE_TYPE_DESCRIPTOR_SET_LAYOUT_CREATE_INFO, .pNext = &fi, .bindingCount = nb[s], .pBindings = b[s]};
        CK(vkCreateDescriptorSetLayout(dev, &li, NULL, &sl[s]));
    }
    VkPushConstantRange pr = {VK_SHADER_STAGE_ALL, 0, push};
    VkPipelineLayoutCreateInfo pli = {VK_STRUCTURE_TYPE_PIPELINE_LAYOUT_CREATE_INFO, .setLayoutCount = nsets, .pSetLayouts = sl,
                                      .pushConstantRangeCount = push ? 1 : 0, .pPushConstantRanges = &pr};
    VkPipelineLayout pl;
    CK(vkCreatePipelineLayout(dev, &pli, NULL, &pl));

    if (getenv("TU_RUN")) {   // dispatch one workgroup with a 4 KiB storage buffer at set 0 binding 0, print its first 17 words
        DF(vkCreateBuffer); DF(vkGetBufferMemoryRequirements); DF(vkAllocateMemory); DF(vkBindBufferMemory); DF(vkMapMemory);
        DF(vkCreateDescriptorPool); DF(vkAllocateDescriptorSets); DF(vkUpdateDescriptorSets); DF(vkCreateCommandPool);
        DF(vkAllocateCommandBuffers); DF(vkBeginCommandBuffer); DF(vkCmdBindPipeline); DF(vkCmdBindDescriptorSets);
        DF(vkCmdDispatch); DF(vkEndCommandBuffer); DF(vkGetDeviceQueue); DF(vkQueueSubmit); DF(vkQueueWaitIdle);
        IF(vkGetPhysicalDeviceMemoryProperties);
        VkComputePipelineCreateInfo ci = {VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO,
                                          .stage = {VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, .stage = VK_SHADER_STAGE_COMPUTE_BIT, .module = mod, .pName = entry},
                                          .layout = pl};
        VkPipeline p;
        CK(vkCreateComputePipelines(dev, VK_NULL_HANDLE, 1, &ci, NULL, &p));
        VkBufferCreateInfo bi = {VK_STRUCTURE_TYPE_BUFFER_CREATE_INFO, .size = 4096, .usage = VK_BUFFER_USAGE_STORAGE_BUFFER_BIT};
        VkBuffer buf; CK(vkCreateBuffer(dev, &bi, NULL, &buf));
        VkMemoryRequirements mr; vkGetBufferMemoryRequirements(dev, buf, &mr);
        VkPhysicalDeviceMemoryProperties mp; vkGetPhysicalDeviceMemoryProperties(pd, &mp);
        uint32_t mt = 0;
        for (; mt < mp.memoryTypeCount; mt++)
            if ((mr.memoryTypeBits & (1u << mt)) && (mp.memoryTypes[mt].propertyFlags & (VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT)) == (VK_MEMORY_PROPERTY_HOST_VISIBLE_BIT | VK_MEMORY_PROPERTY_HOST_COHERENT_BIT)) break;
        VkMemoryAllocateInfo ai2 = {VK_STRUCTURE_TYPE_MEMORY_ALLOCATE_INFO, .allocationSize = mr.size, .memoryTypeIndex = mt};
        VkDeviceMemory mem; CK(vkAllocateMemory(dev, &ai2, NULL, &mem)); CK(vkBindBufferMemory(dev, buf, mem, 0));
        uint32_t *words; CK(vkMapMemory(dev, mem, 0, 4096, 0, (void **)&words)); memset(words, 0, 4096);
        VkDescriptorPoolSize ps = {VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, 1};
        VkDescriptorPoolCreateInfo dpi = {VK_STRUCTURE_TYPE_DESCRIPTOR_POOL_CREATE_INFO, .maxSets = 1, .poolSizeCount = 1, .pPoolSizes = &ps};
        VkDescriptorPool dp; CK(vkCreateDescriptorPool(dev, &dpi, NULL, &dp));
        VkDescriptorSetAllocateInfo dsai = {VK_STRUCTURE_TYPE_DESCRIPTOR_SET_ALLOCATE_INFO, .descriptorPool = dp, .descriptorSetCount = 1, .pSetLayouts = &sl[0]};
        VkDescriptorSet ds; CK(vkAllocateDescriptorSets(dev, &dsai, &ds));
        VkDescriptorBufferInfo dbi = {buf, 0, 4096};
        VkWriteDescriptorSet w = {VK_STRUCTURE_TYPE_WRITE_DESCRIPTOR_SET, .dstSet = ds, .dstBinding = 0, .descriptorCount = 1, .descriptorType = VK_DESCRIPTOR_TYPE_STORAGE_BUFFER, .pBufferInfo = &dbi};
        vkUpdateDescriptorSets(dev, 1, &w, 0, NULL);
        VkCommandPoolCreateInfo cpi = {VK_STRUCTURE_TYPE_COMMAND_POOL_CREATE_INFO, .queueFamilyIndex = 0};
        VkCommandPool cp; CK(vkCreateCommandPool(dev, &cpi, NULL, &cp));
        VkCommandBufferAllocateInfo cbi = {VK_STRUCTURE_TYPE_COMMAND_BUFFER_ALLOCATE_INFO, .commandPool = cp, .level = VK_COMMAND_BUFFER_LEVEL_PRIMARY, .commandBufferCount = 1};
        VkCommandBuffer cb; CK(vkAllocateCommandBuffers(dev, &cbi, &cb));
        VkCommandBufferBeginInfo bgi = {VK_STRUCTURE_TYPE_COMMAND_BUFFER_BEGIN_INFO};
        CK(vkBeginCommandBuffer(cb, &bgi));
        vkCmdBindPipeline(cb, VK_PIPELINE_BIND_POINT_COMPUTE, p);
        vkCmdBindDescriptorSets(cb, VK_PIPELINE_BIND_POINT_COMPUTE, pl, 0, 1, &ds, 0, NULL);
        vkCmdDispatch(cb, 1, 1, 1);
        CK(vkEndCommandBuffer(cb));
        VkQueue q; vkGetDeviceQueue(dev, 0, 0, &q);
        VkSubmitInfo si = {VK_STRUCTURE_TYPE_SUBMIT_INFO, .commandBufferCount = 1, .pCommandBuffers = &cb};
        CK(vkQueueSubmit(q, 1, &si, VK_NULL_HANDLE)); CK(vkQueueWaitIdle(q));
        printf("checked %u words; wrong per 4 KiB block:", words[16]);
        for (int k = 0; k < 16; k++) printf(" %u", words[k]);
        printf("\n");
        return 0;
    }
    if (getenv("TU_GFX_FS")) {   // argv[2] is a vertex module: one graphics pipeline with the fragment module TU_GFX_FS (layout: both modules' bindings), dynamic rendering
        DF(vkCreateGraphicsPipelines);
        FILE *g = fopen(getenv("TU_GFX_FS"), "rb");
        if (!g) { perror("TU_GFX_FS"); return 1; }
        fseek(g, 0, SEEK_END); long gs = ftell(g); fseek(g, 0, SEEK_SET);
        uint32_t *gc = malloc(gs);
        if (fread(gc, 1, gs, g) != (size_t)gs) return 1;
        fclose(g);
        VkShaderModuleCreateInfo fmi = {VK_STRUCTURE_TYPE_SHADER_MODULE_CREATE_INFO, .codeSize = gs, .pCode = gc};
        VkShaderModule fmod; CK(vkCreateShaderModule(dev, &fmi, NULL, &fmod));
        VkPipelineShaderStageCreateInfo st[2] = {{VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, .stage = VK_SHADER_STAGE_VERTEX_BIT, .module = mod, .pName = "main"},
                                                 {VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, .stage = VK_SHADER_STAGE_FRAGMENT_BIT, .module = fmod, .pName = "main"}};
        VkPipelineVertexInputStateCreateInfo vi = {VK_STRUCTURE_TYPE_PIPELINE_VERTEX_INPUT_STATE_CREATE_INFO};
        VkPipelineInputAssemblyStateCreateInfo ia = {VK_STRUCTURE_TYPE_PIPELINE_INPUT_ASSEMBLY_STATE_CREATE_INFO, .topology = VK_PRIMITIVE_TOPOLOGY_TRIANGLE_LIST};
        VkPipelineViewportStateCreateInfo vps = {VK_STRUCTURE_TYPE_PIPELINE_VIEWPORT_STATE_CREATE_INFO, .viewportCount = 1, .scissorCount = 1};
        VkPipelineRasterizationStateCreateInfo rs = {VK_STRUCTURE_TYPE_PIPELINE_RASTERIZATION_STATE_CREATE_INFO, .lineWidth = 1};
        VkPipelineMultisampleStateCreateInfo ms = {VK_STRUCTURE_TYPE_PIPELINE_MULTISAMPLE_STATE_CREATE_INFO, .rasterizationSamples = VK_SAMPLE_COUNT_1_BIT};
        VkPipelineDepthStencilStateCreateInfo dss = {VK_STRUCTURE_TYPE_PIPELINE_DEPTH_STENCIL_STATE_CREATE_INFO, .depthTestEnable = 1, .depthWriteEnable = 1, .depthCompareOp = VK_COMPARE_OP_GREATER_OR_EQUAL};
        VkPipelineColorBlendAttachmentState cba[8];
        VkFormat cf[8];
        for (int k = 0; k < 8; k++) { cba[k] = (VkPipelineColorBlendAttachmentState){.colorWriteMask = 0xf}; cf[k] = VK_FORMAT_R16G16B16A16_SFLOAT; }
        int ncol = getenv("TU_GFX_COLORS") ? atoi(getenv("TU_GFX_COLORS")) : 1;
        VkPipelineColorBlendStateCreateInfo cb = {VK_STRUCTURE_TYPE_PIPELINE_COLOR_BLEND_STATE_CREATE_INFO, .attachmentCount = ncol, .pAttachments = cba};
        VkDynamicState dyn[2] = {VK_DYNAMIC_STATE_VIEWPORT, VK_DYNAMIC_STATE_SCISSOR};
        VkPipelineDynamicStateCreateInfo ds = {VK_STRUCTURE_TYPE_PIPELINE_DYNAMIC_STATE_CREATE_INFO, .dynamicStateCount = 2, .pDynamicStates = dyn};
        VkPipelineRenderingCreateInfo ri = {VK_STRUCTURE_TYPE_PIPELINE_RENDERING_CREATE_INFO, .colorAttachmentCount = ncol, .pColorAttachmentFormats = cf,
                                            .depthAttachmentFormat = VK_FORMAT_D32_SFLOAT};
        VkGraphicsPipelineCreateInfo gi = {VK_STRUCTURE_TYPE_GRAPHICS_PIPELINE_CREATE_INFO, .pNext = &ri, .stageCount = 2, .pStages = st, .pVertexInputState = &vi,
                                           .pInputAssemblyState = &ia, .pViewportState = &vps, .pRasterizationState = &rs, .pMultisampleState = &ms,
                                           .pDepthStencilState = &dss, .pColorBlendState = &cb, .pDynamicState = &ds, .layout = pl};
        VkPipeline p;
        double t0 = now();
        VkResult res = vkCreateGraphicsPipelines(dev, VK_NULL_HANDLE, 1, &gi, NULL, &p);
        printf("result %d seconds %.2f\n", res, now() - t0);
        return res != 0;
    }
    int reps = getenv("TU_REPEAT") ? atoi(getenv("TU_REPEAT")) : 1;
    long rss0 = status_kb("VmRSS:");
    int maps0 = count_maps();
    pthread_t th;
    pthread_create(&th, NULL, sampler, NULL);
    for (int r = 0; r < reps; r++) {
        VkComputePipelineCreateInfo ci = {VK_STRUCTURE_TYPE_COMPUTE_PIPELINE_CREATE_INFO,
                                          .stage = {VK_STRUCTURE_TYPE_PIPELINE_SHADER_STAGE_CREATE_INFO, .stage = VK_SHADER_STAGE_COMPUTE_BIT, .module = mod, .pName = entry},
                                          .layout = pl};
        VkPipeline p;
        double t0 = now();
        VkResult res = vkCreateComputePipelines(dev, VK_NULL_HANDLE, 1, &ci, NULL, &p);
        double t1 = now();
        printf("result %d seconds %.2f\n", res, t1 - t0);
        fflush(stdout);
        if (!res) vkDestroyPipeline(dev, p, NULL);
    }
    g_stop = 1;
    pthread_join(th, NULL);
    printf("rss_before_kb %ld peak_rss_kb %ld maps_before %d peak_maps %d\n", rss0, status_kb("VmHWM:"), maps0, (int)g_peak_maps);
    return 0;
}
