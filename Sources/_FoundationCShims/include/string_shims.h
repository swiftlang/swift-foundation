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

#if defined(_WIN32)
#define locale_t _locale_t
#endif

#if defined(TARGET_OS_EXCLAVEKIT) && TARGET_OS_EXCLAVEKIT
#define locale_t void *
#endif

INTERNAL int _stringshims_strncasecmp_clocale(const char * _Nullable s1, const char * _Nullable s2, size_t n);

INTERNAL double _stringshims_strtod_clocale(const char * _Nullable __restrict nptr, char * _Nullable * _Nullable __restrict endptr);

INTERNAL float _stringshims_strtof_clocale(const char * _Nullable __restrict nptr, char * _Nullable * _Nullable __restrict endptr);

#define _STRINGSHIMS_MACROMAN_MAP_SIZE 129
INTERNAL const uint8_t _stringshims_macroman_mapping[_STRINGSHIMS_MACROMAN_MAP_SIZE][3];

#define _STRINGSHIMS_NEXTSTEP_MAP_SIZE 128
INTERNAL const uint16_t _stringshims_nextstep_mapping[_STRINGSHIMS_NEXTSTEP_MAP_SIZE];

#ifdef __cplusplus
}
#endif

#endif /* CSHIMS_STRING_H */
