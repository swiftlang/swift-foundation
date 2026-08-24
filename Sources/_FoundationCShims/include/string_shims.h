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

#ifndef CSHIMS_STRING_H
#define CSHIMS_STRING_H

#include "_CShimsMacros.h"
#include "_CStdlib.h"

#if __has_include(<locale.h>)
#include <locale.h>
#endif
#include <stddef.h>

#if __has_include(<xlocale.h>)
#include <xlocale.h>
#endif

#ifdef __cplusplus
extern "C" {
#endif

#if !TARGET_OS_WINDOWS && !TARGET_OS_MAC
inline static int _stringshims_LC_ALL_MASK() {
    return LC_ALL_MASK;
}
#endif

#if defined(TARGET_OS_EXCLAVEKIT) && TARGET_OS_EXCLAVEKIT
#include <strings.h>
#endif

#ifdef __cplusplus
}
#endif

#endif /* CSHIMS_STRING_H */
