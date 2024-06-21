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

#include "include/_CShimsTargetConditionals.h"
#include "include/string_shims.h"

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <float.h>
#include <assert.h>

#if defined(TARGET_OS_EXCLAVEKIT) && TARGET_OS_EXCLAVEKIT
#include <strings.h>
#endif

int _stringshims_strncasecmp_l(const char * _Nullable s1,
                      const char * _Nullable s2,
                      size_t n,
                      locale_t _Nullable loc)
{
#if TARGET_OS_WINDOWS
  static _locale_t storage;
  static _locale_t *cloc = NULL;
  if (cloc == NULL) {
    storage = _create_locale(LC_ALL, "C");
    cloc = &storage;
  }
  return _strnicmp_l(s1, s2, n, loc ? loc : *cloc);
#else
    if (loc != NULL) {
#if defined(TARGET_OS_EXCLAVEKIT) && TARGET_OS_EXCLAVEKIT
        abort();
#else
        return strncasecmp_l(s1, s2, n, loc);
#endif
    }
    // On Darwin, NULL loc means unlocalized compare.
    // Uses the standard C locale for Linux in this case
#if defined(TARGET_OS_EXCLAVEKIT) && TARGET_OS_EXCLAVEKIT
    return strncasecmp(s1, s2, n);
#elif TARGET_OS_MAC
    return strncasecmp_l(s1, s2, n, NULL);
#else
    locale_t clocale = newlocale(LC_ALL_MASK, "C", (locale_t)0);
    return strncasecmp_l(s1, s2, n, clocale);
#endif // TARGET_OS_MAC
#endif // TARGET_OS_WINDOWS
}

double _stringshims_strtod_l(const char * _Nullable restrict nptr,
                 char * _Nullable * _Nullable restrict endptr,
                 locale_t _Nullable loc)
{
#if defined(TARGET_OS_EXCLAVEKIT) && TARGET_OS_EXCLAVEKIT
    assert(loc == NULL);
    return strtod_l(nptr, endptr, NULL);
#elif TARGET_OS_MAC
    return strtod_l(nptr, endptr, loc);
#elif TARGET_OS_WINDOWS
    return _strtod_l(nptr, endptr, loc);
#else
    // Use the C locale
    locale_t clocale = newlocale(LC_ALL_MASK, "C", (locale_t)0);
    locale_t oldLocale = uselocale(clocale);
    double result = strtod(nptr, endptr);
    // Restore locale
    uselocale(oldLocale);
    return result;
#endif
}

float _stringshims_strtof_l(const char * _Nullable restrict nptr,
                 char * _Nullable * _Nullable restrict endptr,
                 locale_t _Nullable loc)
{
#if defined(TARGET_OS_EXCLAVEKIT) && TARGET_OS_EXCLAVEKIT
    assert(loc == NULL);
    return strtof_l(nptr, endptr, NULL);
#elif TARGET_OS_MAC
    return strtof_l(nptr, endptr, loc);
#elif TARGET_OS_WINDOWS
    return _strtof_l(nptr, endptr, loc);
#else
    // Use the C locale
    locale_t clocale = newlocale(LC_ALL_MASK, "C", (locale_t)0);
    locale_t oldLocale = uselocale(clocale);
    float result = strtof(nptr, endptr);
    // Restore locale
    uselocale(oldLocale);
    return result;
#endif
}
