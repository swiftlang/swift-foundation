//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#include <stdlib.h>
#include "data_shims.h"

INTERNAL char *_datashims_mktemp(char *arg) {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated"
    return mktemp(arg);
#pragma GCC diagnostic pop
}
