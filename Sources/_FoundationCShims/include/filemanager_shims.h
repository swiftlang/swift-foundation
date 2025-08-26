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

#endif // CSHIMS_FILEMANAGER_H
