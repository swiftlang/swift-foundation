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

#include "include/platform_shims.h"

#if __has_include(<crt_externs.h>)
#include <crt_externs.h>
#elif defined(_WIN32)
#include <stdlib.h>
#elif __has_include(<unistd.h>)
#include <unistd.h>
extern char **environ;
#endif

#if __has_include(<libc_private.h>)
#import <libc_private.h>
void _platform_shims_lock_environ() {
    environ_lock_np();
}

void _platform_shims_unlock_environ() {
    environ_unlock_np();
}
#else
void _platform_shims_lock_environ() { /* noop */ }
void _platform_shims_unlock_environ() { /* noop */ }
#endif

char **
_platform_shims_get_environ()
{
#if __has_include(<crt_externs.h>)
    return *_NSGetEnviron();
#elif defined(_WIN32)
    return _environ;
#elif __has_include(<unistd.h>)
    return environ;
#endif
}

#if __has_include(<libkern/OSThermalNotification.h>)
const char *
_platform_shims_kOSThermalNotificationPressureLevelName()
{
    return kOSThermalNotificationPressureLevelName;
}
#endif

