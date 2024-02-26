//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
//
//===----------------------------------------------------------------------===//

#ifndef process_shims_h
#define process_shims_h

#include <unistd.h>
#include "_CShimsTargetConditionals.h"

#if TARGET_OS_MAC
#include <spawn.h>

int _subprocess_spawn(
    pid_t * _Nonnull pid,
    const char * _Nonnull exec_path,
    const posix_spawn_file_actions_t _Nullable * _Nonnull file_actions,
    const posix_spawnattr_t _Nullable * _Nonnull spawn_attrs,
    char * _Nullable const args[_Nonnull],
    char * _Nullable const env[_Nullable],
    uid_t * _Nullable uid,
    gid_t * _Nullable gid,
    int number_of_sgroups, const gid_t * _Nullable sgroups,
    int create_session
);
#endif // TARGET_OS_MAC

int _subprocess_fork_exec(
    pid_t * _Nonnull pid,
    const char * _Nonnull exec_path,
    const char * _Nullable working_directory,
    const int file_descriptors[_Nonnull],
    char * _Nullable const args[_Nonnull],
    char * _Nullable const env[_Nullable],
    uid_t * _Nullable uid,
    gid_t * _Nullable gid,
    int number_of_sgroups, const gid_t * _Nullable sgroups,
    int create_session,
    int create_process_group
);

int _was_process_exited(int status);
int _get_exit_code(int status);
int _was_process_signaled(int status);
int _get_signal_code(int status);

#if TARGET_OS_LINUX
int _shims_snprintf(
    char * _Nonnull str,
    int len,
    const char * _Nonnull format,
    char * _Nonnull str1,
    char * _Nonnull str2
);
#endif

#endif /* process_shims_h */
