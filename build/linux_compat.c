/* Linux compatibility functions for cross-compilation */

#ifdef __linux__

#include <unistd.h>
#include <dirent.h>
#include <fcntl.h>
#include <stdlib.h>

/* closefrom() is declared in glibc 2.34+ headers but not always available
 * Provide our own implementation that uses /dev/fd or fallback to loop
 */
void closefrom(int lowfd) {
    DIR *dir;
    struct dirent *entry;
    int fd, dir_fd, max_fd;

    if (lowfd < 0)
        lowfd = 0;

    /* Try /dev/fd first */
    dir = opendir("/dev/fd");
    if (dir != NULL) {
        dir_fd = dirfd(dir);
        while ((entry = readdir(dir)) != NULL) {
            fd = atoi(entry->d_name);
            if (fd >= lowfd && fd != dir_fd)
                close(fd);
        }
        closedir(dir);
    } else {
        /* Fallback: close up to sysconf limit */
        max_fd = sysconf(_SC_OPEN_MAX);
        if (max_fd == -1)
            max_fd = 1024;  /* reasonable default */
        for (fd = lowfd; fd < max_fd; fd++)
            close(fd);
    }
}

#endif /* __linux__ */
