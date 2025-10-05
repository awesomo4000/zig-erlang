/* Minimal ncurses_cfg.h for zig-erlang cross-compilation */
#ifndef NC_CONFIG_H
#define NC_CONFIG_H

#include <signal.h>

/* Basic system defines for Unix/POSIX */
#define HAVE_DIRENT_H 1
#define HAVE_ERRNO 1
#define HAVE_FCNTL_H 1
#define HAVE_LIMITS_H 1
#define HAVE_STDINT_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STRING_H 1
#define HAVE_SYS_STAT_H 1
#define HAVE_SYS_TYPES_H 1
#define HAVE_UNISTD_H 1
#define HAVE_VSNPRINTF 1
#define STDC_HEADERS 1

/* Terminal database location */
#define TERMINFO "/usr/share/terminfo"
#define TERMINFO_DIRS "/usr/share/terminfo"

/* Enable termcap compatibility */
#define USE_TERMCAP 1

/* Disable wide character support - not needed for basic termcap */
#define NCURSES_WIDECHAR 0

/* Type definitions */
#define SIG_ATOMIC_T volatile sig_atomic_t
#define NCURSES_EXT_FUNCS 1
#define NCURSES_EXT_COLORS 1
#define NCURSES_INTEROP_FUNCS 1
#define NCURSES_EXTENDED 1

/* Disable features we don't need */
#define NDEBUG 1
#define PURE_TERMINFO 0

#endif /* NC_CONFIG_H */
