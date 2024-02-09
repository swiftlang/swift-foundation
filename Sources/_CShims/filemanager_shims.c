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


#include "include/filemanager_shims.h"

#if __has_include(<removefile.h>)

extern void _FileRemove_ConfirmCallback(void);
extern void _FileRemove_ErrorCallback(void);

void _filemanagershims_removefile_attach_callbacks(removefile_state_t state, void *ctx) {
    removefile_state_set(state, REMOVEFILE_STATE_CONFIRM_CONTEXT, ctx);
    removefile_state_set(state, REMOVEFILE_STATE_CONFIRM_CALLBACK, _FileRemove_ConfirmCallback);
    removefile_state_set(state, REMOVEFILE_STATE_ERROR_CONTEXT, ctx);
    removefile_state_set(state, REMOVEFILE_STATE_ERROR_CALLBACK, _FileRemove_ErrorCallback);
}

int _filemanagershims_removefile_state_get_errnum(removefile_state_t state) {
    int errnum = 0;
    removefile_state_get(state, REMOVEFILE_STATE_ERRNO, &errnum);
    return errnum;
}

#endif // __has_include(<removefile.h>)
