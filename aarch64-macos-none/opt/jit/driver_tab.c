#ifdef HAVE_CONFIG_H
#  include "config.h"
#endif /* HAVE_CONFIG_H */
#include <stdio.h>
#include "global.h"


extern ErlDrvEntry inet_driver_entry;
extern ErlDrvEntry ram_file_driver_entry;

ErtsStaticDriver driver_tab[] =
{
    {&inet_driver_entry, 0},
    {&ram_file_driver_entry, 0},
    {NULL}
};
void erts_init_static_drivers(void) {
}
void *prim_socket_nif_init(void);
void *prim_net_nif_init(void);
void *prim_tty_nif_init(void);
void *erl_tracer_nif_init(void);
void *prim_buffer_nif_init(void);
void *prim_file_nif_init(void);
void *zlib_nif_init(void);
void *zstd_nif_init(void);
ErtsStaticNif erts_static_nif_tab[] =
{
    {&prim_socket_nif_init, 0, THE_NON_VALUE, NULL},
    {&prim_net_nif_init, 0, THE_NON_VALUE, NULL},
    {&prim_tty_nif_init, 0, THE_NON_VALUE, NULL},
    {&erl_tracer_nif_init, 0, THE_NON_VALUE, NULL},
    {&prim_buffer_nif_init, 0, THE_NON_VALUE, NULL},
    {&prim_file_nif_init, 0, THE_NON_VALUE, NULL},
    {&zlib_nif_init, 0, THE_NON_VALUE, NULL},
    {&zstd_nif_init, 0, THE_NON_VALUE, NULL},
    {NULL}
};
