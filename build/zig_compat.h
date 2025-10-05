/* Compatibility header for Zig cross-compilation */
#ifndef ZIG_COMPAT_H
#define ZIG_COMPAT_H

/* Zig's musl libc doesn't declare dlvsym even with _GNU_SOURCE */
#if defined(HAVE_DLVSYM) && defined(__linux__)
#ifndef _DLFCN_H
#define _DLFCN_H 1
#endif
#include <dlfcn.h>
/* Declare dlvsym if not already declared (musl libc issue) */
#ifndef dlvsym
extern void *dlvsym(void *handle, const char *symbol, const char *version);
#endif
#endif

/* Zig's musl libc doesn't declare mallopt even with _GNU_SOURCE */
#if defined(HAVE_MALLOPT) && defined(__linux__)
#include <malloc.h>
/* Declare mallopt if not already declared (musl libc issue) */
#ifndef mallopt
extern int mallopt(int param, int value);
#endif
#endif

#endif /* ZIG_COMPAT_H */
