# turnip-swap2

Swap2-Native's own build of Turnip, Mesa's Vulkan driver for Adreno, packed as an adrenotools zip
(`meta.json` + `libvulkan_freedreno.so`) that the app installs like any other custom driver
(`--es gpu_driver_zip <zip>`, `dm/gfx/vk_android/vka_driver.c`). Mesa is MIT-licensed; nothing GPL is
applied here (the community mesh-shader patch carried by "V39-patched" is GPL-3.0: ideas only).

## Layout

| Where | What |
|---|---|
| `scripts/` (this folder, on D:) | everything that builds or measures; run from WSL Ubuntu-26.04 |
| `patches/` | our Mesa patches, one file each, against the base commit below |
| `tools/` | `spv_layout.py` (SPIR-V binding reflection), `tu_compile.c` (offline pipeline compile), `bigalloc.c` (large-allocation tracer) |
| `out/` | the driver zips |
| `~/turnip-swap2/` in WSL (the WSL disk is `D:\WSL\Ubuntu-26.04\ext4.vhdx`) | the Mesa checkout `mesa/`, an unpatched worktree `mesa-base/`, build folders, venv, results |

Base: upstream Mesa `2648b2059f` (2026-11-07, "27.0.0-devel"), the commit Turnip Gen8 V39 reports.

## Building

```bash
bash scripts/setup-tools.sh      # once: venv with meson + mako, bison/flex/m4 unpacked from Ubuntu .debs (no root)
bash scripts/clone-mesa.sh       # once: blobless clone (~55 s, 366 MB .git), checks out 2648b2059f
cd ~/turnip-swap2/mesa && git apply /mnt/d/Projetos/Jogos/Android/turnip-swap2/patches/*.patch
bash scripts/build-android.sh      # NDK r30, API 29, KGSL; ~33 s full, ~11-17 s after a patch
```

The zip lands in `out/` as `Swap2-Turnip-<commit>-p<patched files>.zip` (`-vanilla` with none).

## Release

`out/Swap2-Turnip-2648b2059f-release.zip` is the zip handed out. It is Mesa `2648b2059f` with the shipping patches only: 0001, 0002, 0004 and, since 2026-11-28, 0005. It is built with `platform-sdk-version` 36 and NDK target API 29. 0003 and the 9xxx diagnostics are left out. `scripts/build-release.sh` builds it: a clean `mesa-rel` worktree (`scripts/rel-worktree.sh 0005`), then `build-android.sh` into `build-android-rel`. Its `libvulkan_freedreno.so` is byte for byte the one measured on the phone as Swap2-Turnip-shfl. It is GitHub release v0.1.1 (a pre-release, 2026-11-28). The zip of v0.1.0 (0001, 0002 and 0004) is kept as `out/Swap2-Turnip-2648b2059f-release-20261123.zip`. Swap2-Native loads it from Game settings > GPU driver.

## Measuring a shader compile on the PC

`build-host.sh` builds the same driver for x86_64 with the msm kernel interface and freedreno's no-op
drm-shim, so it runs on the PC as an Adreno 830 (`FD_GPU_ID=830`) and compiles pipelines with ir3
exactly as on the phone (asserts on).

```bash
bash scripts/build-host.sh
bash scripts/run-compile.sh <module.spv>          # time, peak RSS, peak mappings
bash scripts/trace-compile.sh <module.spv>        # where the large (>= 64 KiB) allocations come from
bash scripts/base-worktree.sh                     # unpatched worktree + build, for comparisons
bash scripts/compare-set.sh <out.tsv> <jobs> <modules...>   # base vs patched: time, memory, identical ir3 output
```

## Patches

Build with `scripts/build-android.sh` (name Swap2-Turnip, Mesa `platform-sdk-version` 36 so no extension V39 has is hidden; NDK target API 29).

- `0002-vk-android-linear-swapchain-when-gralloc-cannot-tell.patch`: when the gralloc backend is the fallback (it cannot read a buffer's layout), swapchain buffers are asked for with CPU read usage and taken as LINEAR. Before, Turnip laid them out as it liked (UBWC) while the display read them linear: noise on screen. A safety net since 0004. The same patch asks for compressed (UBWC) swapchain buffers when the backend can name the vendor's usage bit (`u_gralloc_get_compression_usage`; QTI's `GRALLOC_USAGE_PRIVATE_ALLOC_UBWC`, bit 28): RGBA8/BGRA8 color attachments with optimal tiling, no storage use, not mutable, not protected, not shared-present; `MESA_ANDROID_SWAPCHAIN_UBWC=0` turns it off. The bit goes in two places: `vkGetSwapchainGrallocUsage2ANDROID`, and the usage `vkGetPhysicalDeviceImageFormatProperties2` reports in `VkAndroidHardwareBufferUsageANDROID`. Android 16's loader takes the swapchain's producer usage from the latter and never calls the former (measured). On the POCO the buffers then come back UBWC: COMPRESSION `QTI=10`, two planes (metadata at 0 with a 128-byte pitch, 102,400 bytes; pixels after them with 5,888-byte rows). That is Turnip's fdl6 layout for 1440x3200 (metadata pitch align(90, 64) blocks, 800 rows, 4 KiB planes; bank bit and UBWC version from KGSL), and the picture is correct. Zip: `out/Swap2-Turnip-2648b2059f-ubwc.zip`.
- `0003-tu-build-time-TU_DEBUG-default.patch`: `-DTU_DEBUG_DEFAULT=<flags>` for diagnostic builds (`scripts/build-variant.sh`); the app loads the driver before it sets the game's environment, so TU_DEBUG cannot be passed there.
- `0004-u_gralloc-imapper5-stable-c-backend.patch`: `u_gralloc_aimapper.c`, a u_gralloc backend for IMapper 5's stable C API without libui: `mapper.<suffix>.so` from the vendor's hw folder, loaded through libvndksupport's `android_load_sphal_library`; reads PIXEL_FORMAT_FOURCC, PIXEL_FORMAT_MODIFIER, ALLOCATION_SIZE, LAYER_COUNT, COMPRESSION and PLANE_LAYOUTS (QTI's mapper prefixes every value with its type, as the gralloc4 encoding does); a compressed RGB buffer is given to Turnip as one QCOM_COMPRESSED plane. On the POCO F7 Ultra (Android 16) Zelda's swapchain buffers come back AB24, modifier 0 (linear), one plane of 5888-byte rows. QTI's mapper gives no PIXEL_FORMAT_FOURCC for a UBWC buffer, so the fourcc then comes from the handle's HAL format. Before that fix the buffer fell back to linear and the display read linear pixels as UBWC (bands).
- `0005-ir3-shuffle-absolute-lane-passes.patch` (made by `scripts/make-0005.py`; in release v0.1.1, 2026-11-28): ir3 lowers a subgroup shuffle with a varying index to a loop of `shfl` passes, one per distinct relative offset `index - lane`. The translator's form of NVIDIA's SHFL.IDX from a warp-uniform lane is `(lane & 0x60) | src` in 64-lane subgroups. Each lane then has its own offset, so the loop runs up to 32 passes. Since the host's library of chain b103fbe53956, Zelda's foliage culling computes keep these shuffles as shuffles (MKWDroid's `shaders.md`, "Compute shuffles through workgroup memory where some lanes are not there"). With the patch, each pass also serves every pending lane that reads the absolute lane the first pending lane reads: `read_invocation_cond_ir3` picks that lane, then one `movs` (`nir_read_invocation`). It is only on GPUs with `has_movs`. A broadcast per 32-lane half then takes at most two passes; a rotate keeps its relative passes. Offline (drm-shim, A830) on culling module `09557e3eda60648e`: compiles, 36 `shfl` and 38 `movs`, 15,997 instructions against 14,902. Measured 2026-11-27 on the POCO F7 Ultra (Castle Town, save copy user1127, library b103, one warm-up then A B A B, `out/zelda/burgoshfl-1127-2308`): Swap2-Turnip 10.3 / 10.3 fps, GPU p50 87.0 / 87.2 ms; with 0005, 13.1 / 12.6 fps, GPU p50 71.2 / 70.1 ms. That is the frame rate of the old library, whose foliage flickered (~12.6 fps, ~72 ms), and the foliage stays still (flicker 0.004 % and 0.003 % against 0.007 % and 0.005 %). Zip: `out/rel/Swap2-Turnip-shfl-2648b2059f-0005.zip` (the shipping patches plus 0005, built from `mesa-rel` by `scripts/rel-worktree.sh 0005`).
- `9001-diag-log-gralloc-handle.patch`: diagnostic log of the fallback's handle words; drop before shipping.
- `9002-diag-u_trace-print-gate.patch`: on Android, u_trace's events are printed only while the property `debug.mesa.gpu.traces.on` is not `0`, so a window of a long run can be traced (`MESA_GPU_TRACES=print_csv` and `MESA_GPU_TRACEFILE` as the properties `debug.mesa.gpu.traces` / `debug.mesa.gpu.tracefile`; `tools/utrace_passes.py` reads the CSV, with `--frames` since Turnip numbers every event frame 0). Zip p10. Diagnostic; drop before shipping.
- `9003-diag-wfi-counts-rp-nowfi-ir3-cs-regs.patch`: diagnostics for where the GPU's time goes, all off unless set. The wait-for-idles barriers emit, outside and inside render passes, are counted and logged (tag MESA) every 3,000 submissions. `TU_RP_NOWFI=1` (property `debug.mesa.tu.rp.nowfi`) drops the ones inside render passes: an incorrect picture is possible, it only bounds their cost. `IR3_CS_REGS=<n>` (property `debug.mesa.ir3.cs.regs`) caps a compute shader's full registers at n vec4s and spills the rest, to trade spills for waves. Offline (Adreno 830), Zelda's costliest mesh fallback module `3fa631a86435d3e8` goes from 48 registers and 4 waves (24,523 instructions) to 32 and 6 (37,531) or 24 and 8 (38,547). Zip p13. Drop before shipping.
  Measured 2026-11-22 on the POCO F7 Ultra (Hyrule Field, save copy user1117, window 250+60 s, one run each, `out/zelda/p11`):
  - Two runs as is: 23.0 and 22.2 fps, GPU p50 36.1 and 37.0 ms (the run-to-run spread). With the shader caches off: 22.4 fps, 36.7 ms.
  - The register caps lose: 32 registers 21.5 fps, 39.6 ms; 24 registers 19.6 fps, 43.7 ms. The spills cost more than the extra waves give.
  - Inside render passes barriers emit no wait-for-idle at all (0 in every 3,000 submissions), so `TU_RP_NOWFI` changes nothing. Outside them about 32 a submission (about 700 a frame): nearly every dispatch and copy of the mesh fallback's chain waits for the one before it, a dependency in the host's work and not a driver choice.
- `9004-diag-ssbo-readonly-isam.patch`: `TU_SSBO_RO_AUTO=1` (property `debug.mesa.tu.ssbo.ro.auto`) takes a storage buffer variable that no store or atomic of the shader reaches as NonWritable, as a module could declare it. `nir_opt_access` then marks its loads reorderable and ir3 reads them with `isam.v` (the texture path, as the vendor driver does) instead of `ldib`. Only when every storage buffer write names its variable. Not conformant: another binding or a buffer device address over the same memory may be written by the shader, so it only measures what NonWritable decorations in the modules would give. Offline, Zelda's `3fa631a86435d3e8` goes from 386 `ldib` to 316 `isam.v` (24,523 to 24,110 instructions), `edeefae4c37b0257` from 36,781 to 35,249. Zip p14, with 9003. Drop before shipping.
  Measured 2026-11-22 on the POCO F7 Ultra (Hyrule Field, one run each; the phone's cooler was off in these blocks, skin 47-52 °C):
  - On every storage buffer the shader never writes (p14, `out/zelda/p14`), the grass is not drawn, in both runs. The fallback's own buffers (bindings 384-388: its info block and group table, written by the dispatch before) read wrong through isam.
  - With `TU_SSBO_RO_MAXBIND=384` (zip p15, the guest's buffers only; `out/zelda/p15`) the picture is right: 23.4 fps, GPU 36.3 ms, against 36.0-37.0 ms without the switch in the same heat. No measurable gain.

Swap2-Turnip against 891.14, the same APK (MKWDroid 83cb654), save copy user1117, window 250+40/60 s, the phone cool (skin 34-37 °C), one run each:

| Run | Swap2-Turnip (p15, no switch) | 891.14 |
|---|---|---|
| Grass high (`out/zelda/prof2`) | 23.2 fps, GPU 36.7 ms | 23.4 fps, GPU 36.8 ms |
| Grass none (`out/zelda/prof2`) | 24.2 fps, GPU 33.3 ms | 26.5 fps, GPU 33.4 ms |
| Grass none (`out/zelda/sync2`) | 25.9 fps, GPU 33.3 ms | 26.8 fps, GPU 32.0 ms |

- Per step (the host's `DM_VK_GPUPROF_LIST`, `tools/gpuprof_diff.py`; grass none, timed frames): Turnip +1.05 ms in draw passes and +0.37 ms in the fallback's compute passes. The 200-draw parts do not line up exactly between the drivers, so this sum is noisy.
- The game's one GPU wait a frame (`DM_VK_SYNCLOG`): p50 21.6 ms on Turnip, 22.5 ms on 891.14.
- Turnip emulates timeline semaphores on KGSL (`vk_sync_timeline`). Polling the host's timeline every 0.25 ms instead (`DM_VK_TL_POLL=1`, A B A B, `out/zelda/tlpoll`) changes nothing: 26.0 / 26.0 fps, GPU 33.4 / 33.3 ms (the first run, 24.9 fps, was still warming). So Turnip does not wake late.

So on equal settings Swap2-Turnip matches 891.14 within about 1 ms of GPU. Neither reaches 30 fps in this window: the GPU frame is 32-37 ms, and the frame has another 4-5 ms outside the GPU.

- `0001-ir3-spill-sparse-next-use.patch`: ir3's spiller kept two next-use arrays per basic block over
  every SSA definition (blocks x definitions x 8 bytes). Zelda's mesh fallback `73dc0b90c4082e43`
  (12,707 blocks, ~37,700 definitions) needed 3.6 GiB in 25,414 blocks of 147 KiB, each its own
  mapping under Android's scudo: past `vm.max_map_count` and the compile dies. Now only the live-in /
  live-out values of each block are kept (sorted, merged against the predecessor's list). Same ir3
  output, bit for bit; peak 4.24 GB -> 0.80 GB on that module.

## Next version (to do)

Left for the next version on 2026-11-23, at the user's request. Goal: 30 fps in Ocarina of Time's Hyrule Field with the grass drawn. Where things stand (POCO F7 Ultra, the phone cool, save copy user1117, window 250+60 s):

- **The driver is not the gap.** On one APK, Swap2-Turnip matches 891.14 within about 1 ms of GPU (36.7 against 36.8 ms with the grass, 33.3 against 31.8-33.4 without), and Turnip V39 the same. Neither reaches 30 fps there: the GPU frame is 32-37 ms, plus 4-5 ms a frame outside the GPU.
- **Tried and dropped** (measured, details above and in `out/zelda/*`): ir3 register caps (worse), wait-for-idles (none inside passes; the ~700 a frame outside come from the host's mesh fallback chain), isam for read-only storage buffers (right picture with the guest's buffers only, no gain), the autotuner's modes (GMEM worse), timeline wake latency (`DM_VK_TL_POLL`, no change), `DM_VK_MESH_FUSE_TASK` (-0.1 to -0.3 ms), the mesh computes before their pass (`DM_VK_MESH_HOIST`, three versions, +1.1 ms; its code was not kept), and the cooperative pool table search (vk chain db147b8fa6b5, +1.2 ms on V39; `out/exp-src/vk_android_spv.coop.py`).
- **Measured:** the raw global memory pool search costs about 2.6 ms of GPU a frame in all (the probe library, vk chain 5bd65a66ba64, with the search run twice: 37.0 to 39.5 ms).
- **Open leads:**
  - The 4-5 ms a frame the GPU waits outside its work. One wait a frame for the game's frame, about 6.9 ms of idle between submissions in the u_trace capture (`tools/utrace_passes.py`), the same on 891.14. That is the game's and host's frame sync (`DM_VK_SYNCLOG`, the parked GPU waits), not Turnip.
  - The mesh fallback's own compute (7.2 ms with the grass; `3fa631a86435d3e8` 1.26 ms and `edeefae4c37b0257` 1.16 ms, one dispatch each). It is latency-bound: 48 registers, 4 waves, half of each 64-lane wave idle. A smaller output per group (a compact, indexed output) and fewer raw reads per invocation are the remaining ideas.
  - A per-invocation cache of more than one pool entry, which would cut the search's misses without subgroup operations, has not been tried.
  - The grass level option (`DM_VK_FOLIAGE`, committed) already takes Hyrule Field from 22.5 to 25.1 fps on V39 without the grass.
