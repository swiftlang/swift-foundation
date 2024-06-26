//===----------------------------------------------------------------------===//
 //
 // This source file is part of the Swift.org open source project
 //
 // Copyright (c) 2022 Apple Inc. and the Swift project authors
 // Licensed under Apache License v2.0 with Runtime Library Exception
 //
 // See https://swift.org/LICENSE.txt for license information
 //
 //===----------------------------------------------------------------------===//

// Import for POSIXErrorCode
#if os(Android)
@preconcurrency import Android
#elseif canImport(Glibc)
@preconcurrency import Glibc 
#elseif canImport(Darwin)
@preconcurrency import Darwin
#elseif os(Windows)
import CRT
import WinSDK
#endif

#if FOUNDATION_FRAMEWORK
/// Describes an error in the POSIX error domain.
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public struct POSIXError : _BridgedStoredNSError {
    public let _nsError: NSError

    public init(_nsError error: NSError) {
        precondition(error.domain == NSPOSIXErrorDomain)
        self._nsError = error
    }

    public static var errorDomain: String { return NSPOSIXErrorDomain }

    public var hashValue: Int {
        return _nsError.hashValue
    }

    public typealias Code = POSIXErrorCode
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension POSIXErrorCode : _ErrorCodeProtocol {
    public typealias _ErrorType = POSIXError
}
#else

/// Describes an error in the POSIX error domain.
public struct POSIXError : Error, Hashable, Sendable {
    public let code: Code

    public static var errorDomain: String { return "NSPOSIXErrorDomain" }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(code)
    }

    public init(_ code: Code) {
        self.code = code
    }
    
    public typealias Code = POSIXErrorCode
}
#endif

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension POSIXError {
    /// Operation not permitted.
    public static var EPERM: POSIXErrorCode {
        return .EPERM
    }

    /// No such file or directory.
    public static var ENOENT: POSIXErrorCode {
        return .ENOENT
    }

    /// No such process.
    public static var ESRCH: POSIXErrorCode {
        return .ESRCH
    }

    /// Interrupted system call.
    public static var EINTR: POSIXErrorCode {
        return .EINTR
    }

    /// Input/output error.
    public static var EIO: POSIXErrorCode {
        return .EIO
    }

    /// Device not configured.
    public static var ENXIO: POSIXErrorCode {
        return .ENXIO
    }

    /// Argument list too long.
    public static var E2BIG: POSIXErrorCode {
        return .E2BIG
    }

    /// Exec format error.
    public static var ENOEXEC: POSIXErrorCode {
        return .ENOEXEC
    }

    /// Bad file descriptor.
    public static var EBADF: POSIXErrorCode {
        return .EBADF
    }

    /// No child processes.
    public static var ECHILD: POSIXErrorCode {
        return .ECHILD
    }

    /// Resource deadlock avoided.
    public static var EDEADLK: POSIXErrorCode {
        return .EDEADLK
    }

    /// Cannot allocate memory.
    public static var ENOMEM: POSIXErrorCode {
        return .ENOMEM
    }

    /// Permission denied.
    public static var EACCES: POSIXErrorCode {
        return .EACCES
    }

    /// Bad address.
    public static var EFAULT: POSIXErrorCode {
        return .EFAULT
    }

    #if !os(Windows) && !os(WASI)
    /// Block device required.
    public static var ENOTBLK: POSIXErrorCode {
        return .ENOTBLK
    }
    #endif

    /// Device / Resource busy.
    public static var EBUSY: POSIXErrorCode {
        return .EBUSY
    }

    /// File exists.
    public static var EEXIST: POSIXErrorCode {
        return .EEXIST
    }

    /// Cross-device link.
    public static var EXDEV: POSIXErrorCode {
        return .EXDEV
    }

    /// Operation not supported by device.
    public static var ENODEV: POSIXErrorCode {
        return .ENODEV
    }

    /// Not a directory.
    public static var ENOTDIR: POSIXErrorCode {
        return .ENOTDIR
    }

    /// Is a directory.
    public static var EISDIR: POSIXErrorCode {
        return .EISDIR
    }

    /// Invalid argument.
    public static var EINVAL: POSIXErrorCode {
        return .EINVAL
    }

    /// Too many open files in system.
    public static var ENFILE: POSIXErrorCode {
        return .ENFILE
    }

    /// Too many open files.
    public static var EMFILE: POSIXErrorCode {
        return .EMFILE
    }

    /// Inappropriate ioctl for device.
    public static var ENOTTY: POSIXErrorCode {
        return .ENOTTY
    }

    #if !os(Windows)
    /// Text file busy.
    public static var ETXTBSY: POSIXErrorCode {
        return .ETXTBSY
    }
    #endif

    /// File too large.
    public static var EFBIG: POSIXErrorCode {
        return .EFBIG
    }

    /// No space left on device.
    public static var ENOSPC: POSIXErrorCode {
        return .ENOSPC
    }

    /// Illegal seek.
    public static var ESPIPE: POSIXErrorCode {
        return .ESPIPE
    }

    /// Read-only file system.
    public static var EROFS: POSIXErrorCode {
        return .EROFS
    }

    /// Too many links.
    public static var EMLINK: POSIXErrorCode {
        return .EMLINK
    }

    /// Broken pipe.
    public static var EPIPE: POSIXErrorCode {
        return .EPIPE
    }

    /// Math Software

    /// Numerical argument out of domain.
    public static var EDOM: POSIXErrorCode {
        return .EDOM
    }

    /// Result too large.
    public static var ERANGE: POSIXErrorCode {
        return .ERANGE
    }

    /// Non-blocking and interrupt I/O.

    /// Resource temporarily unavailable.
    public static var EAGAIN: POSIXErrorCode {
        return .EAGAIN
    }

    #if !os(Windows)
    /// Operation would block.
    public static var EWOULDBLOCK: POSIXErrorCode {
        return .EWOULDBLOCK
    }

    /// Operation now in progress.
    public static var EINPROGRESS: POSIXErrorCode {
        return .EINPROGRESS
    }

    /// Operation already in progress.
    public static var EALREADY: POSIXErrorCode {
        return .EALREADY
    }
    #endif

    /// IPC/Network software -- argument errors.

    #if !os(Windows)
    /// Socket operation on non-socket.
    public static var ENOTSOCK: POSIXErrorCode {
        return .ENOTSOCK
    }

    /// Destination address required.
    public static var EDESTADDRREQ: POSIXErrorCode {
        return .EDESTADDRREQ
    }

    /// Message too long.
    public static var EMSGSIZE: POSIXErrorCode {
        return .EMSGSIZE
    }

    /// Protocol wrong type for socket.
    public static var EPROTOTYPE: POSIXErrorCode {
        return .EPROTOTYPE
    }

    /// Protocol not available.
    public static var ENOPROTOOPT: POSIXErrorCode {
        return .ENOPROTOOPT
    }

    /// Protocol not supported.
    public static var EPROTONOSUPPORT: POSIXErrorCode {
        return .EPROTONOSUPPORT
    }

    #if !os(WASI)
    /// Socket type not supported.
    public static var ESOCKTNOSUPPORT: POSIXErrorCode {
        return .ESOCKTNOSUPPORT
    }
    #endif
    #endif

    #if canImport(Darwin)
    /// Operation not supported.
    public static var ENOTSUP: POSIXErrorCode {
        return .ENOTSUP
    }
    #endif

    #if !os(Windows)
    #if !os(WASI)
    /// Protocol family not supported.
    public static var EPFNOSUPPORT: POSIXErrorCode {
        return .EPFNOSUPPORT
    }
    #endif

    /// Address family not supported by protocol family.
    public static var EAFNOSUPPORT: POSIXErrorCode {
        return .EAFNOSUPPORT
    }

    /// Address already in use.
    public static var EADDRINUSE: POSIXErrorCode {
        return .EADDRINUSE
    }

    /// Can't assign requested address.
    public static var EADDRNOTAVAIL: POSIXErrorCode {
        return .EADDRNOTAVAIL
    }
    #endif

    /// IPC/Network software -- operational errors

    #if !os(Windows)
    /// Network is down.
    public static var ENETDOWN: POSIXErrorCode {
        return .ENETDOWN
    }

    /// Network is unreachable.
    public static var ENETUNREACH: POSIXErrorCode {
        return .ENETUNREACH
    }

    /// Network dropped connection on reset.
    public static var ENETRESET: POSIXErrorCode {
        return .ENETRESET
    }

    /// Software caused connection abort.
    public static var ECONNABORTED: POSIXErrorCode {
        return .ECONNABORTED
    }

    /// Connection reset by peer.
    public static var ECONNRESET: POSIXErrorCode {
        return .ECONNRESET
    }

    /// No buffer space available.
    public static var ENOBUFS: POSIXErrorCode {
        return .ENOBUFS
    }

    /// Socket is already connected.
    public static var EISCONN: POSIXErrorCode {
        return .EISCONN
    }

    /// Socket is not connected.
    public static var ENOTCONN: POSIXErrorCode {
        return .ENOTCONN
    }

    #if !os(WASI)
    /// Can't send after socket shutdown.
    public static var ESHUTDOWN: POSIXErrorCode {
        return .ESHUTDOWN
    }

    /// Too many references: can't splice.
    public static var ETOOMANYREFS: POSIXErrorCode {
        return .ETOOMANYREFS
    }
    #endif
    
    /// Operation timed out.
    public static var ETIMEDOUT: POSIXErrorCode {
        return .ETIMEDOUT
    }

    /// Connection refused.
    public static var ECONNREFUSED: POSIXErrorCode {
        return .ECONNREFUSED
    }

    /// Too many levels of symbolic links.
    public static var ELOOP: POSIXErrorCode {
        return .ELOOP
    }
    #endif

    /// File name too long.
    public static var ENAMETOOLONG: POSIXErrorCode {
        return .ENAMETOOLONG
    }

    #if !os(Windows)
    #if !os(WASI)
    /// Host is down.
    public static var EHOSTDOWN: POSIXErrorCode {
        return .EHOSTDOWN
    }
    #endif

    /// No route to host.
    public static var EHOSTUNREACH: POSIXErrorCode {
        return .EHOSTUNREACH
    }
    #endif

    /// Directory not empty.
    public static var ENOTEMPTY: POSIXErrorCode {
        return .ENOTEMPTY
    }

    /// Quotas

    #if canImport(Darwin)
    /// Too many processes.
    public static var EPROCLIM: POSIXErrorCode {
        return .EPROCLIM
    }
    #endif
    
    #if !os(Windows)
    #if !os(WASI)
    /// Too many users.
    public static var EUSERS: POSIXErrorCode {
        return .EUSERS
    }
    #endif

    /// Disk quota exceeded.
    public static var EDQUOT: POSIXErrorCode {
        return .EDQUOT
    }
    #endif

    /// Network File System

    #if !os(Windows)
    /// Stale NFS file handle.
    public static var ESTALE: POSIXErrorCode {
        return .ESTALE
    }

    /// Too many levels of remote in path.
    public static var EREMOTE: POSIXErrorCode {
        return .EREMOTE
    }
    #endif

    #if canImport(Darwin)
    /// RPC struct is bad.
    public static var EBADRPC: POSIXErrorCode {
        return .EBADRPC
    }

    /// RPC version wrong.
    public static var ERPCMISMATCH: POSIXErrorCode {
        return .ERPCMISMATCH
    }

    /// RPC prog. not avail.
    public static var EPROGUNAVAIL: POSIXErrorCode {
        return .EPROGUNAVAIL
    }

    /// Program version wrong.
    public static var EPROGMISMATCH: POSIXErrorCode {
        return .EPROGMISMATCH
    }

    /// Bad procedure for program.
    public static var EPROCUNAVAIL: POSIXErrorCode {
        return .EPROCUNAVAIL
    }
    #endif
    
    /// No locks available.
    public static var ENOLCK: POSIXErrorCode {
        return .ENOLCK
    }

    /// Function not implemented.
    public static var ENOSYS: POSIXErrorCode {
        return .ENOSYS
    }
    
    #if canImport(Darwin)
    /// Inappropriate file type or format.
    public static var EFTYPE: POSIXErrorCode {
        return .EFTYPE
    }

    /// Authentication error.
    public static var EAUTH: POSIXErrorCode {
        return .EAUTH
    }

    /// Need authenticator.
    public static var ENEEDAUTH: POSIXErrorCode {
        return .ENEEDAUTH
    }
    #endif
    
    /// Intelligent device errors.

    #if canImport(Darwin)
    /// Device power is off.
    public static var EPWROFF: POSIXErrorCode {
        return .EPWROFF
    }

    /// Device error, e.g. paper out.
    public static var EDEVERR: POSIXErrorCode {
        return .EDEVERR
    }
    #endif

    #if !os(Windows)
    /// Value too large to be stored in data type.
    public static var EOVERFLOW: POSIXErrorCode {
        return .EOVERFLOW
    }
    #endif

    /// Program loading errors.

    #if canImport(Darwin)
    /// Bad executable.
    public static var EBADEXEC: POSIXErrorCode {
        return .EBADEXEC
    }
    #endif
    
    #if canImport(Darwin)
    /// Bad CPU type in executable.
    public static var EBADARCH: POSIXErrorCode {
        return .EBADARCH
    }
    
    /// Shared library version mismatch.
    public static var ESHLIBVERS: POSIXErrorCode {
        return .ESHLIBVERS
    }

    /// Malformed Macho file.
    public static var EBADMACHO: POSIXErrorCode {
        return .EBADMACHO
    }
    #endif

    /// Operation canceled.
    public static var ECANCELED: POSIXErrorCode {
#if os(Windows)
        return POSIXErrorCode(rawValue: Int32(ERROR_CANCELLED))!
#else
        return .ECANCELED
#endif
    }

    #if !os(Windows)
    /// Identifier removed.
    public static var EIDRM: POSIXErrorCode {
        return .EIDRM
    }

    /// No message of desired type.
    public static var ENOMSG: POSIXErrorCode {
        return .ENOMSG
    }
    #endif

    /// Illegal byte sequence.
    public static var EILSEQ: POSIXErrorCode {
        return .EILSEQ
    }

    #if canImport(Darwin)
    /// Attribute not found.
    public static var ENOATTR: POSIXErrorCode {
        return .ENOATTR
    }
    #endif

    #if !os(Windows)
    /// Bad message.
    public static var EBADMSG: POSIXErrorCode {
        return .EBADMSG
    }

    #if !os(OpenBSD)
    /// Reserved.
    public static var EMULTIHOP: POSIXErrorCode {
        return .EMULTIHOP
    }

    #if !os(WASI)
    /// No message available on STREAM.
    public static var ENODATA: POSIXErrorCode {
        return .ENODATA
    }
    #endif

    /// Reserved.
    public static var ENOLINK: POSIXErrorCode {
        return .ENOLINK
    }

    #if !os(WASI)
    /// No STREAM resources.
    public static var ENOSR: POSIXErrorCode {
        return .ENOSR
    }

    /// Not a STREAM.
    public static var ENOSTR: POSIXErrorCode {
        return .ENOSTR
    }
    #endif
    #endif

    /// Protocol error.
    public static var EPROTO: POSIXErrorCode {
        return .EPROTO
    }

    #if !os(OpenBSD) && !os(WASI)
    /// STREAM ioctl timeout.
    public static var ETIME: POSIXErrorCode {
        return .ETIME
    }
    #endif
    #endif

    #if canImport(Darwin)
    /// No such policy registered.
    public static var ENOPOLICY: POSIXErrorCode {
        return .ENOPOLICY
    }
    #endif

    #if !os(Windows)
    /// State not recoverable.
    public static var ENOTRECOVERABLE: POSIXErrorCode {
        return .ENOTRECOVERABLE
    }

    /// Previous owner died.
    public static var EOWNERDEAD: POSIXErrorCode {
        return .EOWNERDEAD
    }
    #endif

    #if canImport(Darwin)
    /// Interface output queue is full.
    public static var EQFULL: POSIXErrorCode {
        return .EQFULL
    }
    #endif
}
