//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#ifndef CSHIMS_FILEMANAGER_H
#define CSHIMS_FILEMANAGER_H

#include "_CShimsMacros.h"
#include "_CShimsTargetConditionals.h"

#if __has_include(<sys/param.h>)
#include <sys/param.h>
#endif

#if __has_include(<fts.h>)
#include <fts.h>
#endif

#if __has_include(<sys/quota.h>)
#include <sys/quota.h>
#endif

#if __has_include(<sys/xattr.h>)
#include <sys/xattr.h>
#endif

#if __has_include(<dirent.h>)
#include <dirent.h>
#endif

#if __has_include(<removefile.h>)
#include <removefile.h>
#endif // __has_include(<removefile.h>)

#if FOUNDATION_FRAMEWORK && __has_include(<sys/types.h>)
#include <sys/types.h>
// Darwin-specific API that is implemented but not declared in any header
// This function behaves exactly like the public mkpath_np(3) API, but it also returns the first directory it actually created, which helps us make sure we set the given attributes on the right directories.
extern int _mkpath_np(const char *path, mode_t omode, const char **firstdir);
#endif

#if TARGET_OS_ANDROID && __ANDROID_API__ <= 23
#include <grp.h>
#include <sys/types.h>
#include <string.h>
#include <errno.h>

static inline int _filemanager_shims_getgrgid_r(gid_t gid, struct group *grp,
                                                char *buf, size_t buflen, struct group **result) {
    errno = 0;

    // Call the non-reentrant version.
    // On Android, this uses Thread Local Storage (TLS),
    // so it is safe from race conditions with other threads.
    struct group *p = getgrgid(gid);

    if (p == NULL) {
        *result = NULL;
        return errno;
    }

    size_t name_len = strlen(p->gr_name) + 1;
    if (name_len > buflen) {
        *result = NULL;
        return ERANGE;
    }

    strcpy(buf, p->gr_name);
    grp->gr_name = buf;
    grp->gr_gid = p->gr_gid;

    grp->gr_passwd = (char *)"";
    grp->gr_mem = NULL;

    *result = grp;
    return 0;
}

static inline int _filemanager_shims_getgrnam_r(const char *name, struct group *grp,
                                                char *buf, size_t buflen, struct group **result) {
    errno = 0;

    // Call the non-reentrant version.
    // On Android, this uses Thread Local Storage (TLS),
    // so it is safe from race conditions with other threads.
    struct group *p = getgrnam(name);

    if (p == NULL) {
        *result = NULL;
        return errno;
    }

    size_t name_len = strlen(p->gr_name) + 1;
    if (name_len > buflen) {
        *result = NULL;
        return ERANGE;
    }

    strcpy(buf, p->gr_name);
    grp->gr_name = buf;
    grp->gr_gid = p->gr_gid;

    grp->gr_passwd = (char *)"";
    grp->gr_mem = NULL;

    *result = grp;
    return 0;
}

#elif !TARGET_OS_WINDOWS && !TARGET_OS_WASI
#include <grp.h>

static inline int _filemanager_shims_getgrgid_r(gid_t gid, struct group *grp,
                                                char *buf, size_t buflen, struct group **result) {
    return getgrgid_r(gid, grp, buf, buflen, result);
}

static inline int _filemanager_shims_getgrnam_r(const char *name, struct group *grp,
                                                char *buf, size_t buflen, struct group **result) {
    return getgrnam_r(name, grp, buf, buflen, result);
}
#endif

#endif // CSHIMS_FILEMANAGER_H
