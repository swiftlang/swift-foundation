/*
 * Copyright (c) 2004 Apple Computer, Inc. All rights reserved.
 *
 * %Begin-Header%
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, and the entire permission notice in its entirety,
 *    including the disclaimer of warranties.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. The name of the author may not be used to endorse or promote
 *    products derived from this software without specific prior
 *    written permission.
 *
 * THIS SOFTWARE IS PROVIDED ``AS IS'' AND ANY EXPRESS OR IMPLIED
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE, ALL OF
 * WHICH ARE HEREBY DISCLAIMED.  IN NO EVENT SHALL THE AUTHOR BE
 * LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
 * CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT
 * OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
 * BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
 * LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE
 * USE OF THIS SOFTWARE, EVEN IF NOT ADVISED OF THE POSSIBILITY OF SUCH
 * DAMAGE.
 * %End-Header%
 */

#ifndef _CSHIMS_UUID_UUID_H
#define _CSHIMS_UUID_UUID_H

#include "_CShimsTargetConditionals.h"
#include "_CShimsMacros.h"

#if TARGET_OS_MAC
#include <uuid/uuid.h>
#else
#include <sys/types.h>
typedef    unsigned char __darwin_uuid_t[16];
typedef    char __darwin_uuid_string_t[37];
#ifdef uuid_t
#undef uuid_t
#endif
typedef __darwin_uuid_t    uuid_t;
typedef __darwin_uuid_string_t    uuid_string_t;

#define UUID_DEFINE(name,u0,u1,u2,u3,u4,u5,u6,u7,u8,u9,u10,u11,u12,u13,u14,u15) \
    static const uuid_t name __attribute__ ((unused)) = {u0,u1,u2,u3,u4,u5,u6,u7,u8,u9,u10,u11,u12,u13,u14,u15}
#endif

#ifdef __cplusplus
extern "C" {
#endif

INTERNAL void _foundation_uuid_clear(uuid_t uu);

INTERNAL int _foundation_uuid_compare(const uuid_t uu1, const uuid_t uu2);

INTERNAL void _foundation_uuid_copy(uuid_t dst, const uuid_t src);

INTERNAL void _foundation_uuid_generate(uuid_t out);
INTERNAL void _foundation_uuid_generate_random(uuid_t out);
INTERNAL void _foundation_uuid_generate_time(uuid_t out);

INTERNAL int _foundation_uuid_is_null(const uuid_t uu);

INTERNAL int _foundation_uuid_parse(const uuid_string_t in, uuid_t uu);

INTERNAL void _foundation_uuid_unparse(const uuid_t uu, uuid_string_t out);
INTERNAL void _foundation_uuid_unparse_lower(const uuid_t uu, uuid_string_t out);
INTERNAL void _foundation_uuid_unparse_upper(const uuid_t uu, uuid_string_t out);

#ifdef __cplusplus
}
#endif

#endif /* _CSHIMS_UUID_UUID_H */
