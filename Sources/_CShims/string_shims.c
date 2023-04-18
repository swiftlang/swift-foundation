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

#include "include/string_shims.h"
#include "include/_CShimsTargetConditionals.h"

#include <strings.h>
#include <stdlib.h>
#include <stdio.h>
#include <float.h>

int
_cshims_strncasecmp_l(const char * _Nullable s1,
                      const char * _Nullable s2,
                      size_t n,
                      locale_t _Nullable loc)
{
    if (loc != NULL) {
        return strncasecmp_l(s1, s2, n, loc);
    }
    // On Darwin, NULL loc means unlocalized compare.
    // Uses the standard C locale for Linux in this case
#if TARGET_OS_MAC
    return strncasecmp_l(s1, s2, n, NULL);
#else
    locale_t clocale = newlocale(LC_ALL_MASK, "C", (locale_t)0);
    return strncasecmp_l(s1, s2, n, clocale);
#endif // TARGET_OS_MAC
}

double
_cshims_strtod_l(const char * _Nullable restrict nptr,
                 char * _Nullable * _Nullable restrict endptr,
                 locale_t _Nullable loc)
{
#if TARGET_OS_MAC
    return strtod_l(nptr, endptr, loc);
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

float
_cshims_strtof_l(const char * _Nullable restrict nptr,
                 char * _Nullable * _Nullable restrict endptr,
                 locale_t _Nullable loc)
{
#if TARGET_OS_MAC
    return strtof_l(nptr, endptr, loc);
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

int
_cshims_get_formatted_str_length(double value)
{
    char empty[1];
    return snprintf(empty, 0, "%0.*g", DBL_DECIMAL_DIG, value);
}
