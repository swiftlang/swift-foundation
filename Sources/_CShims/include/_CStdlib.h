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

#if __has_include(<setjmp.h>)
#include <setjmp.h>
#endif

#if __has_include(<signal.h>)
#include <signal.h>
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

#if __has_include(<stdnoreturn.h>)
#include <stdnoreturn.h>
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

#if __has_include(<stdatomic.h>)
#include <stdatomic.h>
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

#endif // FOUNDATION_CSTDLIB

