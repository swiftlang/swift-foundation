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


#ifndef IOShims_h
#define IOShims_h

#include "_CShimsTargetConditionals.h"

#if TARGET_OS_MAC && (!defined(TARGET_OS_EXCLAVEKIT) || !TARGET_OS_EXCLAVEKIT)

#include <stdio.h>
#include <sys/attr.h>

// See getattrlist for an explanation of the layout of these structs.

#pragma pack(push, 1)
typedef struct PreRenameAttributes {
    u_int32_t length;
    fsobj_type_t fileType;
    u_int32_t mode;
    attrreference_t fullPathAttr;
    u_int32_t nlink;
    char fullPathBuf[PATH_MAX];
} PreRenameAttributes;
#pragma pack(pop)

#pragma pack(push, 1)
typedef struct FullPathAttributes {
    u_int32_t length;
    attrreference_t fullPathAttr;
    char fullPathBuf[PATH_MAX];
} FullPathAttributes;
#pragma pack(pop)

#endif // TARGET_OS_EXCLAVEKIT

#if TARGET_OS_WINDOWS

#include <stddef.h>

// Replicated from ntifs.h
// https://learn.microsoft.com/en-us/windows-hardware/drivers/ddi/ntifs/ns-ntifs-_reparse_data_buffer

typedef struct _REPARSE_DATA_BUFFER {
    unsigned long  ReparseTag;
    unsigned short ReparseDataLength;
    unsigned short Reserved;
    union {
        struct {
            unsigned short SubstituteNameOffset;
            unsigned short SubstituteNameLength;
            unsigned short PrintNameOffset;
            unsigned short PrintNameLength;
            unsigned long  Flags;
            short          PathBuffer[1];
        } SymbolicLinkReparseBuffer;
        struct {
            unsigned short SubstituteNameOffset;
            unsigned short SubstituteNameLength;
            unsigned short PrintNameOffset;
            unsigned short PrintNameLength;
            short          PathBuffer[1];
        } MountPointReparseBuffer;
        struct {
            unsigned char DataBuffer[1];
        } GenericReparseBuffer;
    };
} REPARSE_DATA_BUFFER;

static inline intptr_t _ioshims_reparse_data_buffer_symboliclinkreparsebuffer_pathbuffer_offset(void) {
  return offsetof(struct _REPARSE_DATA_BUFFER, SymbolicLinkReparseBuffer.PathBuffer);
}

static inline intptr_t _ioshims_reparse_data_buffer_mountpointreparsebuffer_pathbuffer_offset(void) {
  return offsetof(struct _REPARSE_DATA_BUFFER, MountPointReparseBuffer.PathBuffer);
}

#endif
#endif /* IOShims_h */
