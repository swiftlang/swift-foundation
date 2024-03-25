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

#include "include/_CShimsTargetConditionals.h"
#include "include/process_shims.h"
#include <errno.h>
#include <signal.h>
#include <sys/wait.h>

int _was_process_exited(int status) {
    return WIFEXITED(status);
}

int _get_exit_code(int status) {
    return WEXITSTATUS(status);
}

int _was_process_signaled(int status) {
    return WIFSIGNALED(status);
}

int _get_signal_code(int status) {
    return WTERMSIG(status);
}

#if TARGET_OS_LINUX
#include <stdio.h>

int _shims_snprintf(
    char * _Nonnull str,
    int len,
    const char * _Nonnull format,
    char * _Nonnull str1,
    char * _Nonnull str2
) {
    return snprintf(str, len, format, str1, str2);
}
#endif

// MARK: - Darwin (posix_spawn)
#if TARGET_OS_MAC

int _subprocess_spawn(
    pid_t  * _Nonnull  pid,
    const char  * _Nonnull  exec_path,
    const posix_spawn_file_actions_t _Nullable * _Nonnull file_actions,
    const posix_spawnattr_t _Nullable * _Nonnull spawn_attrs,
    char * _Nullable const args[_Nonnull],
    char * _Nullable const env[_Nullable],
    uid_t * _Nullable uid,
    gid_t * _Nullable gid,
    int number_of_sgroups, const gid_t * _Nullable sgroups,
    int create_session
) {
    int require_pre_fork = uid != NULL ||
        gid != NULL ||
        number_of_sgroups > 0 ||
    create_session > 0;

    if (require_pre_fork != 0) {
        pid_t childPid = fork();
        if (childPid != 0) {
            *pid = childPid;
            return childPid < 0 ? errno : 0;
        }

        if (uid != NULL) {
            if (setuid(*uid) != 0) {
                return errno;
            }
        }

        if (gid != NULL) {
            if (setgid(*gid) != 0) {
                return errno;
            }
        }

        if (number_of_sgroups > 0 && sgroups != NULL) {
            if (setgroups(number_of_sgroups, sgroups) != 0) {
                return errno;
            }
        }

        if (create_session != 0) {
            (void)setsid();
        }
    }

    // Set POSIX_SPAWN_SETEXEC if we already forked
    if (require_pre_fork) {
        short flags = 0;
        int rc = posix_spawnattr_getflags(spawn_attrs, &flags);
        if (rc != 0) {
            return rc;
        }

        rc = posix_spawnattr_setflags(
            (posix_spawnattr_t *)spawn_attrs, flags | POSIX_SPAWN_SETEXEC);
        if (rc != 0) {
            return rc;
        }
    }

    // Spawn
    return posix_spawn(pid, exec_path, file_actions, spawn_attrs, args, env);
}

#endif // TARGET_OS_MAC

// MARK: - Linux (fork/exec + posix_spawn fallback)

#if _POSIX_SPAWN
static int _subprocess_posix_spawn_fallback(
    pid_t * _Nonnull pid,
    const char * _Nonnull exec_path,
    const char * _Nullable working_directory,
    const int file_descriptors[_Nonnull],
    char * _Nullable const args[_Nonnull],
    char * _Nullable const env[_Nullable],
    int create_process_group
) {
    // Setup stdin, stdout, and stderr
    posix_spawn_file_actions_t file_actions;

    int rc = posix_spawn_file_actions_init(&file_actions);
    if (rc != 0) { return rc; }
    rc = posix_spawn_file_actions_adddup2(
        &file_actions, file_descriptors[0], STDIN_FILENO);
    if (rc != 0) { return rc; }
    rc = posix_spawn_file_actions_adddup2(
        &file_actions, file_descriptors[2], STDOUT_FILENO);
    if (rc != 0) { return rc; }
    rc = posix_spawn_file_actions_adddup2(
        &file_actions, file_descriptors[4], STDERR_FILENO);
    if (rc != 0) { return rc; }
    if (file_descriptors[1] != 0) {
        rc = posix_spawn_file_actions_addclose(&file_actions, file_descriptors[1]);
        if (rc != 0) { return rc; }
    }
    if (file_descriptors[3] != 0) {
        rc = posix_spawn_file_actions_addclose(&file_actions, file_descriptors[3]);
        if (rc != 0) { return rc; }
    }
    if (file_descriptors[5] != 0) {
        rc = posix_spawn_file_actions_addclose(&file_actions, file_descriptors[5]);
        if (rc != 0) { return rc; }
    }

    // Setup spawnattr
    posix_spawnattr_t spawn_attr;
    rc = posix_spawnattr_init(&spawn_attr);
    if (rc != 0) { return rc; }
    // Masks
    sigset_t no_signals;
    sigset_t all_signals;
    sigemptyset(&no_signals);
    sigfillset(&all_signals);
    rc = posix_spawnattr_setsigmask(&spawn_attr, &no_signals);
    if (rc != 0) { return rc; }
    rc = posix_spawnattr_setsigdefault(&spawn_attr, &all_signals);
    if (rc != 0) { return rc; }
    // Flags
    short flags = POSIX_SPAWN_SETSIGMASK | POSIX_SPAWN_SETSIGDEF;
    if (create_process_group) {
        flags |= POSIX_SPAWN_SETPGROUP;
    }
    rc = posix_spawnattr_setflags(&spawn_attr, flags);

    // Spawn!
    rc = posix_spawn(
        pid, exec_path,
        &file_actions, &spawn_attr,
        args, env
    );
    posix_spawn_file_actions_destroy(&file_actions);
    posix_spawnattr_destroy(&spawn_attr);
    return rc;
}
#endif // _POSIX_SPAWN

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
) {
    int require_pre_fork = working_directory != NULL ||
        uid != NULL ||
        gid != NULL ||
        (number_of_sgroups > 0 && sgroups != NULL) ||
        create_session;

#if _POSIX_SPAWN
    // If posix_spawn is available on this platform and
    // we do not require prefork, use posix_spawn if possible.
    //
    // (Glibc's posix_spawn does not support
    // `POSIX_SPAWN_SETEXEC` therefore we have to keep
    // using fork/exec if `require_pre_fork` is true.
    if (require_pre_fork == 0) {
        return _subprocess_posix_spawn_fallback(
            pid, exec_path,
            working_directory,
            file_descriptors,
            args, env,
            create_process_group
        );
    }
#endif

    pid_t child_pid = fork();
    if (child_pid != 0) {
        *pid = child_pid;
        return child_pid < 0 ? errno : 0;
    }

    if (working_directory != NULL) {
        if (chdir(working_directory) != 0) {
            return errno;
        }
    }

    if (uid != NULL) {
        if (setuid(*uid) != 0) {
            return errno;
        }
    }

    if (gid != NULL) {
        if (setgid(*gid) != 0) {
            return errno;
        }
    }

    if (number_of_sgroups > 0 && sgroups != NULL) {
        if (setgroups(number_of_sgroups, sgroups) != 0) {
            return errno;
        }
    }

    if (create_session != 0) {
        (void)setsid();
    }

    if (create_process_group != 0) {
        (void)setpgid(0, 0);
    }

    // Bind stdin, stdout, and stderr
    int rc = 0;
    if (file_descriptors[0] != 0) {
        rc = dup2(file_descriptors[0], STDIN_FILENO);
        if (rc != 0) { return rc; }
    }
    if (file_descriptors[2] != 0) {
        rc = dup2(file_descriptors[2], STDOUT_FILENO);
        if (rc != 0) { return rc; }
    }

    if (file_descriptors[4] != 0) {
        rc = dup2(file_descriptors[4], STDERR_FILENO);
        if (rc != 0) { return rc; }
    }

#warning Shold close all and then return error no early return
    // Close parent side
    if (file_descriptors[1] != 0) {
        rc = close(file_descriptors[1]);
        if (rc != 0) { return rc; }
    }
    if (file_descriptors[3] != 0) {
        rc = close(file_descriptors[3]);
        if (rc != 0) { return rc; }
    }
    if (file_descriptors[4] != 0) {
        rc = close(file_descriptors[5]);
        if (rc != 0) { return rc; }
    }

    // Finally, exec
    execve(exec_path, args, env);
    // If we got here, something went wrong
    return errno;
}

