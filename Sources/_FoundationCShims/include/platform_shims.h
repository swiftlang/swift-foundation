//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#ifndef CSHIMS_PLATFORM_SHIMS
#define CSHIMS_PLATFORM_SHIMS

#include "_CShimsTargetConditionals.h"
#include "_CShimsMacros.h"

#if __has_include(<stddef.h>)
#include <stddef.h>
#endif

#if __has_include(<libkern/OSThermalNotification.h>)
#include <libkern/OSThermalNotification.h>
#endif

// Workaround for inability to import `security.h` as a module in WinSDK
#if defined(_WIN32)
#include <windows.h>
#define SECURITY_WIN32
#include <security.h>
#endif

INTERNAL char * _Nullable * _Nullable _platform_shims_get_environ(void);

INTERNAL void _platform_shims_lock_environ(void);
INTERNAL void _platform_shims_unlock_environ(void);

#if __has_include(<mach/vm_page_size.h>)
#include <mach/vm_page_size.h>
INTERNAL vm_size_t _platform_shims_vm_size(void);
#endif

#if __has_include(<mach/mach.h>)
#include <mach/mach.h>
INTERNAL mach_port_t _platform_mach_task_self(void);
#endif

#if __has_include(<libkern/OSThermalNotification.h>)
typedef enum {
#if TARGET_OS_OSX || TARGET_OS_MACCATALYST
    _kOSThermalPressureLevelNominal = kOSThermalPressureLevelNominal,
    _kOSThermalPressureLevelModerate = kOSThermalPressureLevelModerate,
    _kOSThermalPressureLevelHeavy = kOSThermalPressureLevelHeavy,
    _kOSThermalPressureLevelTrapping = kOSThermalPressureLevelTrapping,
    _kOSThermalPressureLevelSleeping = kOSThermalPressureLevelSleeping
#else
    _kOSThermalPressureLevelNominal = kOSThermalPressureLevelNominal,
    _kOSThermalPressureLevelLight = kOSThermalPressureLevelLight,
    _kOSThermalPressureLevelModerate = kOSThermalPressureLevelModerate,
    _kOSThermalPressureLevelHeavy = kOSThermalPressureLevelHeavy,
    _kOSThermalPressureLevelTrapping = kOSThermalPressureLevelTrapping,
    _kOSThermalPressureLevelSleeping = kOSThermalPressureLevelSleeping
#endif
} _platform_shims_OSThermalPressureLevel;


INTERNAL const char * _Nonnull _platform_shims_kOSThermalNotificationPressureLevelName(void);
#endif

#if TARGET_OS_WASI
// Define clock id getter shims so that we can use them in Swift
// even if clock id macros can't be imported through ClangImporter.

#include <time.h>
static inline _Nonnull clockid_t _platform_shims_clock_monotonic(void) {
    return CLOCK_MONOTONIC;
}
static inline _Nonnull clockid_t _platform_shims_clock_realtime(void) {
    return CLOCK_REALTIME;
}

// Define dirent shims so that we can use them in Swift because wasi-libc defines
// `d_name` as "flexible array member" which is not supported by ClangImporter yet.

#include <dirent.h>

static inline char * _Nonnull _platform_shims_dirent_d_name(struct dirent * _Nonnull entry) {
    return entry->d_name;
}

// Define getter shims for constants because wasi-libc defines them as function-like macros
// which are not supported by ClangImporter yet.

#include <stdint.h>
#include <fcntl.h>
#include <dirent.h>

static inline uint8_t _platform_shims_DT_DIR(void) { return DT_DIR; }
static inline uint8_t _platform_shims_DT_UNKNOWN(void) { return DT_UNKNOWN; }
static inline int32_t _platform_shims_O_CREAT(void) { return O_CREAT; }
static inline int32_t _platform_shims_O_EXCL(void) { return O_EXCL; }
static inline int32_t _platform_shims_O_TRUNC(void) { return O_TRUNC; }
static inline int32_t _platform_shims_O_WRONLY(void) { return O_WRONLY; }
static inline int32_t _platform_shims_O_NONBLOCK(void) { return O_NONBLOCK; }
static inline int32_t _platform_shims_O_RDONLY(void) { return O_RDONLY; }
static inline int32_t _platform_shims_O_DIRECTORY(void) { return O_DIRECTORY; }
static inline int32_t _platform_shims_O_NOFOLLOW(void) { return O_NOFOLLOW; }

#endif

#endif /* CSHIMS_PLATFORM_SHIMS */
