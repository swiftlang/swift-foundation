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

INTERNAL char * _Nullable * _Nullable _platform_shims_get_environ();

INTERNAL void _platform_shims_lock_environ();
INTERNAL void _platform_shims_unlock_environ();

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


INTERNAL const char * _Nonnull _platform_shims_kOSThermalNotificationPressureLevelName();
#endif

#endif /* CSHIMS_PLATFORM_SHIMS */
