/*
 * LD_PRELOAD shim that overrides uname(3) to fake the kernel release string.
 * Reads the fake release from (in order):
 *   1. FAKE_UNAME_R environment variable
 *   2. /.kernelversion file (one-line, as written by OBS/SUSE build systems)
 *
 * Build:  gcc -shared -fPIC -o fakeuname.so fakeuname_preload.c -ldl
 * Usage:  LD_PRELOAD=/usr/local/lib/fakeuname.so rpmbuild ...
 *
 * Based on rpm-software-management/fakeuname and kmod-project/kmod testsuite.
 */
#define _GNU_SOURCE
#include <dlfcn.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/utsname.h>

static const char *get_fake_release(void)
{
    static char buf[256];
    static int checked;
    const char *env;
    FILE *f;

    if (checked)
        return buf[0] ? buf : NULL;
    checked = 1;

    env = getenv("FAKE_UNAME_R");
    if (env && *env) {
        snprintf(buf, sizeof(buf), "%s", env);
        return buf;
    }

    f = fopen("/.kernelversion", "r");
    if (f) {
        if (fgets(buf, sizeof(buf), f)) {
            buf[strcspn(buf, "\n")] = '\0';
        }
        fclose(f);
        if (buf[0])
            return buf;
    }

    return NULL;
}

int uname(struct utsname *u)
{
    static int (*real_uname)(struct utsname *);
    const char *fake;

    if (!real_uname)
        real_uname = dlsym(RTLD_NEXT, "uname");

    int ret = real_uname(u);
    if (ret < 0)
        return ret;

    fake = get_fake_release();
    if (fake && strlen(fake) < sizeof(u->release))
        strcpy(u->release, fake);

    return 0;
}
