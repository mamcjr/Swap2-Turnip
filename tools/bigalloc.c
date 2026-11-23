// LD_PRELOAD tracer: totals of live allocations of at least BIGALLOC_MIN bytes (default 64 KiB,
// scudo's secondary-allocator size on Android, where each such block is its own mapping), grouped by
// the first return address outside ralloc / malloc. At exit prints the groups with their peak count
// and bytes as "<library>+0x<offset>" so addr2line can name them.
#define _GNU_SOURCE
#include <dlfcn.h>
#include <execinfo.h>
#include <pthread.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <malloc.h>

extern void *__libc_malloc(size_t);
extern void *__libc_calloc(size_t, size_t);
extern void *__libc_realloc(void *, size_t);
extern void __libc_free(void *);

#define NSITE 512
#define NLIVE (1 << 20)
static struct { void *pc; long live, peak, bytes, peak_bytes, total; } site[NSITE];
static struct { void *p; int s; size_t n; } live[NLIVE];
static pthread_mutex_t mu = PTHREAD_MUTEX_INITIALIZER;
static size_t minsz = 65536;
static __thread int busy;
static long g_live, g_peak;

static int depth = 4;   // BIGALLOC_DEPTH: which return address names a site (2 = malloc's caller)
static void *caller(void) {
    void *bt[16];
    int n = backtrace(bt, 16);
    return depth < n ? bt[depth] : 0;
}
static void note(void *p, size_t n) {
    if (!p || n < minsz || busy) return;
    busy = 1;
    void *pc = caller();
    pthread_mutex_lock(&mu);
    int s = 0;
    for (; s < NSITE - 1 && site[s].pc && site[s].pc != pc; s++);
    site[s].pc = pc;
    site[s].live++; site[s].total++; site[s].bytes += n;
    if (site[s].live > site[s].peak) site[s].peak = site[s].live;
    if (site[s].bytes > site[s].peak_bytes) site[s].peak_bytes = site[s].bytes;
    if (++g_live > g_peak) g_peak = g_live;
    size_t h = ((uintptr_t)p >> 4) & (NLIVE - 1);
    while (live[h].p) h = (h + 1) & (NLIVE - 1);
    live[h].p = p; live[h].s = s; live[h].n = n;
    pthread_mutex_unlock(&mu);
    busy = 0;
}
static void forget(void *p) {
    if (!p) return;
    pthread_mutex_lock(&mu);
    size_t h = ((uintptr_t)p >> 4) & (NLIVE - 1);
    for (size_t k = 0; k < NLIVE && live[h].p; k++, h = (h + 1) & (NLIVE - 1)) {
        if (live[h].p == p) {
            site[live[h].s].live--; site[live[h].s].bytes -= live[h].n; g_live--;
            // backward-shift deletion keeps the probe chains intact
            size_t j = h;
            for (;;) {
                live[j].p = 0;
                size_t i = j;
                for (;;) {
                    i = (i + 1) & (NLIVE - 1);
                    if (!live[i].p) goto done;
                    size_t home = ((uintptr_t)live[i].p >> 4) & (NLIVE - 1);
                    if ((j < i) ? (home <= j || home > i) : (home <= j && home > i)) break;
                }
                live[j] = live[i]; j = i;
            }
        }
    }
done:
    pthread_mutex_unlock(&mu);
}
void *malloc(size_t n) { void *p = __libc_malloc(n); note(p, n); return p; }
void *calloc(size_t a, size_t b) { void *p = __libc_calloc(a, b); note(p, a * b); return p; }
void *realloc(void *o, size_t n) { forget(o); void *p = __libc_realloc(o, n); note(p, n); return p; }
void free(void *p) { forget(p); __libc_free(p); }

__attribute__((constructor)) static void init(void) { const char *e = getenv("BIGALLOC_MIN"); if (e) minsz = strtoul(e, 0, 0); e = getenv("BIGALLOC_DEPTH"); if (e) depth = atoi(e); }
__attribute__((destructor)) static void fini(void) {
    busy = 1;
    fprintf(stderr, "bigalloc: peak live blocks >= %zu bytes: %ld\n", minsz, g_peak);
    for (int s = 0; s < NSITE && site[s].pc; s++) {
        if (site[s].peak < 16 && site[s].peak_bytes < (64 << 20)) continue;
        Dl_info di; dladdr(site[s].pc, &di);
        fprintf(stderr, "bigalloc: site %s+0x%lx peak_blocks %ld peak_MiB %.1f total_blocks %ld\n", di.dli_fname ? strrchr(di.dli_fname, '/') + 1 : "?",
                (unsigned long)((char *)site[s].pc - (char *)di.dli_fbase), site[s].peak, site[s].peak_bytes / 1048576.0, site[s].total);
    }
}
