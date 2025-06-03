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

#ifndef FOUNDATION_CSTDLIB
#define FOUNDATION_CSTDLIB

#include "_CShimsTargetConditionals.h"

#if __has_include(<assert.h>)
#include <assert.h>
#endif

#if __has_include(<ctype.h>)
#include <ctype.h>
#endif

#if __has_include(<errno.h>)
#include <errno.h>
#endif

#if __has_include(<fenv.h>)
#include <fenv.h>
#endif

#if __has_include(<float.h>)
#include <float.h>
#endif

#if __has_include(<inttypes.h>)
#include <inttypes.h>
#endif

#if __has_include(<iso646.h>)
#include <iso646.h>
#endif

#if __has_include(<limits.h>)
#include <limits.h>
#endif

#if __has_include(<locale.h>)
#include <locale.h>
#endif

#if __has_include(<math.h>)
#include <math.h>
#endif

#if __has_include(<signal.h>)
/// Guard against including `signal.h` on WASI. The `signal.h` header file
/// itself is available in wasi-libc, but it's just a stub that doesn't actually
/// do anything. And also including it requires a special macro definition
/// (`_WASI_EMULATED_SIGNAL`) and it causes compilation errors without the macro.
# if !TARGET_OS_WASI || defined(_WASI_EMULATED_SIGNAL)
#  include <signal.h>
# endif
#endif

#if __has_include(<sys/mman.h>)
/// Similar to `signal.h`, guard against including `sys/mman.h` on WASI unless
/// `_WASI_EMULATED_MMAN` is enabled.
# if !TARGET_OS_WASI || defined(_WASI_EMULATED_MMAN)
#  include <sys/mman.h>
# endif
#endif

#if __has_include(<stdalign.h>)
#include <stdalign.h>
#endif

#if __has_include(<stdarg.h>)
#include <stdarg.h>
#endif

#if __has_include(<stdbool.h>)
#include <stdbool.h>
#endif

#if __has_include(<stddef.h>)
#include <stddef.h>
#endif

#if __has_include(<stdint.h>)
#include <stdint.h>
#endif

#if __has_include(<stdio.h>)
#include <stdio.h>
#endif

#if __has_include(<stdlib.h>)
#include <stdlib.h>
#endif

#if __has_include(<string.h>)
#include <string.h>
#endif

#if !defined(_WIN32)
#if __has_include(<tgmath.h>)
#include <tgmath.h>
#endif
#endif

#if __has_include(<time.h>)
#include <time.h>
#endif

#if __has_include(<wchar.h>)
#include <wchar.h>
#endif

#if __has_include(<wctype.h>)
#include <wctype.h>
#endif


#if __has_include(<complex.h>)
#include <complex.h>
#endif

#if __has_include(<threads.h>)
#include <threads.h>
#endif

#if __has_include(<uchar.h>)
#include <uchar.h>
#endif

#if __has_include(<stdint.h>)
#include <stdint.h>
#endif

#if __has_include(<tzfile.h>)
#include <tzfile.h>
#else

#if TARGET_OS_MAC || TARGET_OS_LINUX || TARGET_OS_BSD
#ifndef TZDIR
#define TZDIR    "/usr/share/zoneinfo/" /* Time zone object file directory */
#endif /* !defined TZDIR */

#ifndef TZDEFAULT
#define TZDEFAULT    "/etc/localtime"
#endif /* !defined TZDEFAULT */
#elif TARGET_OS_WINDOWS || TARGET_OS_WASI
/* not required */
#else
#error "possibly define TZDIR and TZDEFAULT for this platform"
#endif /* TARGET_OS_MAC || TARGET_OS_LINUX || TARGET_OS_BSD */

#endif

// Must be last to avoid conflicts with other headers on Windows.
#if __has_include(<stdnoreturn.h>)
#include <stdnoreturn.h>
#endif

#endif // FOUNDATION_CSTDLIB

