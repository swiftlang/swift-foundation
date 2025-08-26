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

#include "include/uuid.h"

#if __has_include(<TargetConditionals.h>)
#include <TargetConditionals.h>
#endif

#if TARGET_OS_MAC

INTERNAL void _foundation_uuid_clear(uuid_t uu) {
    uuid_clear(uu);
}

INTERNAL int _foundation_uuid_compare(const uuid_t uu1, const uuid_t uu2) {
    return uuid_compare(uu1, uu2);
}

INTERNAL void _foundation_uuid_copy(uuid_t dst, const uuid_t src) {
    uuid_copy(dst, src);
}

INTERNAL void _foundation_uuid_generate(uuid_t out) {
    uuid_generate(out);
}

INTERNAL void _foundation_uuid_generate_random(uuid_t out) {
    uuid_generate_random(out);
}

INTERNAL void _foundation_uuid_generate_time(uuid_t out) {
    uuid_generate_time(out);
}

INTERNAL int _foundation_uuid_is_null(const uuid_t uu) {
    return uuid_is_null(uu);
}

INTERNAL int _foundation_uuid_parse(const uuid_string_t in, uuid_t uu) {
    return uuid_parse(in, uu);
}

INTERNAL void _foundation_uuid_unparse(const uuid_t uu, uuid_string_t out) {
    uuid_unparse(uu, out);
}

INTERNAL void _foundation_uuid_unparse_lower(const uuid_t uu, uuid_string_t out) {
    uuid_unparse_lower(uu, out);
}

INTERNAL void _foundation_uuid_unparse_upper(const uuid_t uu, uuid_string_t out) {
    uuid_unparse_upper(uu, out);
}

#else

#include <stdint.h>
#include <string.h>
#include <fcntl.h>
#if defined(__unix__) || (defined(__APPLE__) && defined(__MACH__))
#include <unistd.h>
#elif defined(_WIN32)
#include <io.h>
#define WIN32_LEAN_AND_MEAN
#include <Windows.h>
#include <bcrypt.h>
#endif
#include <stdio.h>

#if TARGET_OS_LINUX || TARGET_OS_BSD || TARGET_OS_WASI
#include <time.h>

static inline void nanotime(struct timespec *tv) {
    clock_gettime(CLOCK_MONOTONIC, tv);
}

#elif TARGET_OS_WINDOWS
#include <time.h>

static inline void nanotime(struct timespec *tv) {
    FILETIME ftTime;
    
    GetSystemTimePreciseAsFileTime(&ftTime);
    
    uint64_t Value = (((uint64_t)ftTime.dwHighDateTime << 32) | ftTime.dwLowDateTime);
    
    tv->tv_sec = Value / 1000000000;
    tv->tv_nsec = Value - (tv->tv_sec * 1000000000);
}
#endif

#if TARGET_OS_WINDOWS
static inline void read_random(void *buffer, unsigned numBytes) {
    BCryptGenRandom(NULL, buffer, numBytes,
                    BCRYPT_RNG_USE_ENTROPY_IN_BUFFER | BCRYPT_USE_SYSTEM_PREFERRED_RNG);
}
#elif TARGET_OS_WASI
#include <sys/random.h>

static inline void read_random(void *buffer, unsigned numBytes) {
    getentropy(buffer, numBytes);
}
#else
static inline void read_random(void *buffer, unsigned numBytes) {
    int fd = open("/dev/urandom", O_RDONLY);
    read(fd, buffer, numBytes);
    close(fd);
}
#endif

UUID_DEFINE(UUID_NULL, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0);

static void read_node(uint8_t *node) {
#if NETWORKING
    struct ifnet *ifp;
    struct ifaddr *ifa;
    struct sockaddr_dl *sdl;
    
    ifnet_head_lock_shared();
    TAILQ_FOREACH(ifp, &ifnet_head, if_link) {
        TAILQ_FOREACH(ifa, &ifp->if_addrhead, ifa_link) {
            sdl = (struct sockaddr_dl *)ifa->ifa_addr;
            if (sdl && sdl->sdl_family == AF_LINK && sdl->sdl_type == IFT_ETHER) {
                memcpy(node, LLADDR(sdl), 6);
                ifnet_head_done();
                return;
            }
        }
    }
    ifnet_head_done();
#endif /* NETWORKING */
    
    read_random(node, 6);
    node[0] |= 0x01;
}

static uint64_t read_time(void) {
    struct timespec tv;
    
    nanotime(&tv);
    
    return (tv.tv_sec * 10000000ULL) + (tv.tv_nsec / 100ULL) + 0x01B21DD213814000ULL;
}

void _foundation_uuid_clear(uuid_t uu) {
    memset(uu, 0, sizeof(uuid_t));
}

int _foundation_uuid_compare(const uuid_t uu1, const uuid_t uu2) {
    return memcmp(uu1, uu2, sizeof(uuid_t));
}

void _foundation_uuid_copy(uuid_t dst, const uuid_t src) {
    memcpy(dst, src, sizeof(uuid_t));
}

void _foundation_uuid_generate_random(uuid_t out) {
    read_random(out, sizeof(uuid_t));
    
    out[6] = (out[6] & 0x0F) | 0x40;
    out[8] = (out[8] & 0x3F) | 0x80;
}

void _foundation_uuid_generate_time(uuid_t out) {
    uint64_t time;
    
    read_node(&out[10]);
    read_random(&out[8], 2);
    
    time = read_time();
    out[0] = (uint8_t)(time >> 24);
    out[1] = (uint8_t)(time >> 16);
    out[2] = (uint8_t)(time >> 8);
    out[3] = (uint8_t)time;
    out[4] = (uint8_t)(time >> 40);
    out[5] = (uint8_t)(time >> 32);
    out[6] = (uint8_t)(time >> 56);
    out[7] = (uint8_t)(time >> 48);
    
    out[6] = (out[6] & 0x0F) | 0x10;
    out[8] = (out[8] & 0x3F) | 0x80;
}

void _foundation_uuid_generate(uuid_t out)
{
    _foundation_uuid_generate_random(out);
}

int _foundation_uuid_is_null(const uuid_t uu)
{
    return !memcmp(uu, UUID_NULL, sizeof(uuid_t));
}

int _foundation_uuid_parse(const uuid_string_t in, uuid_t uu)
{
    int n = 0;
    
    sscanf(in,
           "%2hhx%2hhx%2hhx%2hhx-"
           "%2hhx%2hhx-"
           "%2hhx%2hhx-"
           "%2hhx%2hhx-"
           "%2hhx%2hhx%2hhx%2hhx%2hhx%2hhx%n",
           &uu[0], &uu[1], &uu[2], &uu[3],
           &uu[4], &uu[5],
           &uu[6], &uu[7],
           &uu[8], &uu[9],
           &uu[10], &uu[11], &uu[12], &uu[13], &uu[14], &uu[15], &n);
    
    return (n != 36 || in[n] != '\0' ? -1 : 0);
}

void _foundation_uuid_unparse_lower(const uuid_t uu, uuid_string_t out) {
    snprintf(out,
             sizeof(uuid_string_t),
             "%02x%02x%02x%02x-"
             "%02x%02x-"
             "%02x%02x-"
             "%02x%02x-"
             "%02x%02x%02x%02x%02x%02x",
             uu[0], uu[1], uu[2], uu[3],
             uu[4], uu[5],
             uu[6], uu[7],
             uu[8], uu[9],
             uu[10], uu[11], uu[12], uu[13], uu[14], uu[15]);
}

void _foundation_uuid_unparse_upper(const uuid_t uu, uuid_string_t out) {
    snprintf(out,
             sizeof(uuid_string_t),
             "%02X%02X%02X%02X-"
             "%02X%02X-"
             "%02X%02X-"
             "%02X%02X-"
             "%02X%02X%02X%02X%02X%02X",
             uu[0], uu[1], uu[2], uu[3],
             uu[4], uu[5],
             uu[6], uu[7],
             uu[8], uu[9],
             uu[10], uu[11], uu[12], uu[13], uu[14], uu[15]);
}

void _foundation_uuid_unparse(const uuid_t uu, uuid_string_t out) {
    _foundation_uuid_unparse_upper(uu, out);
}

#endif

