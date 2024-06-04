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

#if defined(_WIN32)
#define locale_t _locale_t
#endif

#if defined(TARGET_OS_EXCLAVEKIT) && TARGET_OS_EXCLAVEKIT
#define locale_t void *
#endif

INTERNAL int _stringshims_strncasecmp_l(const char * _Nullable s1, const char * _Nullable s2, size_t n, locale_t _Nullable loc);

INTERNAL double _stringshims_strtod_l(const char * _Nullable __restrict nptr, char * _Nullable * _Nullable __restrict endptr, locale_t _Nullable loc);

INTERNAL float _stringshims_strtof_l(const char * _Nullable __restrict nptr, char * _Nullable * _Nullable __restrict endptr, locale_t _Nullable loc);

#ifdef __cplusplus
}
#endif

#endif /* CSHIMS_STRING_H */
