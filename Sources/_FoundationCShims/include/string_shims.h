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

#if defined(TARGET_OS_ANDROID) && TARGET_OS_ANDROID
inline int _stringshims_android_strncasecmp_l(const char *s1, const char *s2, size_t n, locale_t locale) {
#if __ANDROID_API__ < 23
    return strncasecmp(s1, s2, n);
#else
    return strncasecmp_l(s1, s2, n, locale);
#endif
}
#endif

#define _STRINGSHIMS_MACROMAN_MAP_SIZE 129
INTERNAL const uint8_t _stringshims_macroman_mapping[_STRINGSHIMS_MACROMAN_MAP_SIZE][3];

#define _STRINGSHIMS_NEXTSTEP_MAP_SIZE 128
INTERNAL const uint16_t _stringshims_nextstep_mapping[_STRINGSHIMS_NEXTSTEP_MAP_SIZE];

#ifdef __cplusplus
}
#endif

#endif /* CSHIMS_STRING_H */
