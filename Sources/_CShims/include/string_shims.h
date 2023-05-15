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

#include <locale.h>
#include <stddef.h>

#if __has_include(<xlocale.h>)
#include <xlocale.h>
#endif

#if defined(_WIN32)
#define locale_t _locale_t
#endif

int _cshims_strncasecmp_l(const char * _Nullable s1, const char * _Nullable s2, size_t n, locale_t _Nullable loc);

double _cshims_strtod_l(const char * _Nullable restrict nptr, char * _Nullable * _Nullable restrict endptr, locale_t _Nullable loc);

float _cshims_strtof_l(const char * _Nullable restrict nptr, char * _Nullable * _Nullable restrict endptr, locale_t _Nullable loc);

int _cshims_get_formatted_str_length(double value);

#endif /* CSHIMS_STRING_H */
