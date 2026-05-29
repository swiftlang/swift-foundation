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

#ifndef _CShims_h
#define _CShims_h

#include "_CShimsTargetConditionals.h"
#include "_CStdlib.h"
#include "CFUniCharBitmapData.inc.h"
#include "CFUniCharBitmapData.h"
#include "string_shims.h"
#include "bplist_shims.h"
#include "io_shims.h"
#include "platform_shims.h"
#include "filemanager_shims.h"
#include "uuid.h"

#if FOUNDATION_FRAMEWORK && !TARGET_OS_EXCLAVEKIT
#include "sandbox_shims.h"
#endif

#endif /* _CShims_h */
