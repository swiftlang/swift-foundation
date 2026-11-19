//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#include <stdbool.h>
#include <stdint.h>
#include <stdio.h>

typedef struct {
    // Use an anonymous union here to work around https://github.com/swiftlang/swift/issues/94273
    union {
        va_list args;
    };
} _stringformatshims_va_list_box;

__attribute__((always_inline))
inline static void _stringformatshims_va_box_init(_stringformatshims_va_list_box *box, va_list args) {
    va_copy(box->args, args);
}

__attribute__((always_inline))
inline static void _stringformatshims_va_box_copy(_stringformatshims_va_list_box *destination, const _stringformatshims_va_list_box *source) {
    va_copy(destination->args, ((_stringformatshims_va_list_box *)source)->args);
}

__attribute__((always_inline))
inline static void _stringformatshims_va_box_end(_stringformatshims_va_list_box box) {
    va_end(box.args);
}

__attribute__((always_inline))
inline static const void *_stringformatshims_va_arg_pointer(_stringformatshims_va_list_box *box) {
    return va_arg(box->args, void *);
}

__attribute__((always_inline))
inline static int _stringformatshims_va_arg_int(_stringformatshims_va_list_box *box) {
    return va_arg(box->args, int);
}

__attribute__((always_inline))
inline static int32_t _stringformatshims_va_arg_int32(_stringformatshims_va_list_box *box) {
    return va_arg(box->args, int32_t);
}

__attribute__((always_inline))
inline static int64_t _stringformatshims_va_arg_int64(_stringformatshims_va_list_box *box) {
    return va_arg(box->args, int64_t);
}

__attribute__((always_inline))
inline static double _stringformatshims_va_arg_double(_stringformatshims_va_list_box *box) {
    return va_arg(box->args, double);
}

__attribute__((always_inline))
inline static long double _stringformatshims_va_arg_long_double(_stringformatshims_va_list_box *box) {
    return va_arg(box->args, long double);
}

#if TARGET_OS_MAC && !NO_LOCALIZATION
#define _stringformatshims_SNPRINTF(buf, size, fmt, ...) snprintf_l(buf, size, NULL, fmt, __VA_ARGS__)
#else
#define _stringformatshims_SNPRINTF(buf, size, fmt, ...) snprintf(buf, size, fmt, __VA_ARGS__)
#endif

#define _stringformatshims_DEFINE_SNPRINTF(NAME, TYPE) \
__attribute__((always_inline)) \
inline static int NAME(char *buf, size_t size, const char *fmt, bool hasWidth, int width, bool hasPrecision, int precision, TYPE value) { \
    if (hasWidth) { \
        return hasPrecision ? _stringformatshims_SNPRINTF(buf, size, fmt, width, precision, value) : _stringformatshims_SNPRINTF(buf, size, fmt, width, value); \
    } \
    return hasPrecision ? _stringformatshims_SNPRINTF(buf, size, fmt, precision, value) : _stringformatshims_SNPRINTF(buf, size, fmt, value); \
}

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wformat-nonliteral"
_stringformatshims_DEFINE_SNPRINTF(_stringformatshims_snprintf_int64, int64_t)
_stringformatshims_DEFINE_SNPRINTF(_stringformatshims_snprintf_double, double)
_stringformatshims_DEFINE_SNPRINTF(_stringformatshims_snprintf_long_double, long double)
#pragma GCC diagnostic pop
