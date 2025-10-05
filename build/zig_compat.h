/* Compatibility header for Zig cross-compilation */
#ifndef ZIG_COMPAT_H
#define ZIG_COMPAT_H

/* This is processed LAST (included at end of all headers) to fix issues */

/* closefrom is BSD-only, not in glibc/musl - provide our own */
#if defined(__linux__) && !defined(__GLIBC__)
#include <unistd.h>
/* Declare closefrom - implemented in linux_compat.c */
extern void closefrom(int lowfd);
#endif

/* musl doesn't support symbol versioning - dlvsym is glibc-only */
#if !defined(__GLIBC__)
#include <dlfcn.h>
/* Fall back to regular dlsym for musl (no symbol versioning) */
#ifndef dlvsym
#define dlvsym(handle, symbol, version) dlsym(handle, symbol)
#endif
#endif

/* musl doesn't support malloc tuning - mallopt is glibc-only */
#if !defined(__GLIBC__)
/* Provide no-op stub for musl (returns 0 = failure, but harmless) */
#ifndef M_MMAP_MAX
#define M_MMAP_MAX 0  /* Dummy definition for musl */
#endif
#ifndef mallopt
static inline int mallopt(int param, int value) {
    (void)param;
    (void)value;
    return 0;
}
#endif
#endif

#endif /* ZIG_COMPAT_H */
