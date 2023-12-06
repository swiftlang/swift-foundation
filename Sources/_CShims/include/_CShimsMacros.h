//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2021 - 2022 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#ifndef _C_SHIMS_MACROS_H
#define _C_SHIMS_MACROS_H

#if FOUNDATION_FRAMEWORK
// This macro prevents the symbol from being exported from the framework, where library evolution is enabled.
#define INTERNAL __attribute__((__visibility__("hidden")))
#else
// This macro makes the symbol available for package users. With library evolution disabled, it is possible for clients to end up referencing these normally-internal symbols.
#define INTERNAL extern
#endif

#endif
