//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2021 - 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#ifndef _C_SHIMS_TARGET_CONDITIONALS_H
#define _C_SHIMS_TARGET_CONDITIONALS_H

#if __has_include(<TargetConditionals.h>)
#include <TargetConditionals.h>
#endif

#if (defined(__APPLE__) && defined(__MACH__))
#define TARGET_OS_MAC 1
#else
#define TARGET_OS_MAC 0
#endif

#if defined(__linux__)
#define TARGET_OS_LINUX 1
#else
#define TARGET_OS_LINUX 0
#endif

#if defined(__unix__)
#define TARGET_OS_BSD 1
#else
#define TARGET_OS_BSD 0
#endif

#if defined(_WIN32)
#define TARGET_OS_WINDOWS 1
#else
#define TARGET_OS_WINDOWS 0
#endif

#if defined(__wasi__)
#define TARGET_OS_WASI 1
#else
#define TARGET_OS_WASI 0
#endif

#if defined(__ANDROID__)
#define TARGET_OS_ANDROID 1
#else
#define TARGET_OS_ANDROID 0
#endif

#endif // _C_SHIMS_TARGET_CONDITIONALS_H
