//===----------------------------------------------------------------------===//
 //
 // This source file is part of the Swift Collections open source project
 //
 // Copyright (c) 2022 Apple Inc. and the Swift project authors
 // Licensed under Apache License v2.0 with Runtime Library Exception
 //
 // See https://swift.org/LICENSE.txt for license information
 //
 //===----------------------------------------------------------------------===//


#if FOUNDATION_FRAMEWORK
/// Describes an error in the POSIX error domain.
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public struct POSIXError : _BridgedStoredNSError {
    public let _nsError: NSError

    public init(_nsError error: NSError) {
        precondition(error.domain == NSPOSIXErrorDomain)
        self._nsError = error
    }

    public static var errorDomain: String { NSPOSIXErrorDomain }

    public var hashValue: Int {
        _nsError.hashValue
    }

    public typealias Code = POSIXErrorCode
}
#else
// Define the POSIXErrorCode for all platforms here.
public enum POSIXErrorCode : Int32 {
    /// Operation not permitted.
    case EPERM = 1

    /// No such file or directory.
    case ENOENT = 2

    /// No such process.
    case ESRCH = 3

    /// Interrupted system call.
    case EINTR = 4

    /// Input/output error.
    case EIO = 5

    /// Device not configured.
    case ENXIO = 6

    /// Argument list too long.
    case E2BIG = 7

    /// Exec format error.
    case ENOEXEC = 8

    /// Bad file descriptor.
    case EBADF = 9

    /// No child processes.
    case ECHILD = 10

    /// Resource deadlock avoided.
    case EDEADLK = 11

    /// 11 was EAGAIN.
    /// Cannot allocate memory.
    case ENOMEM = 12

    /// Permission denied.
    case EACCES = 13

    /// Bad address.
    case EFAULT = 14

    /// Block device required.
    case ENOTBLK = 15

    /// Device / Resource busy.
    case EBUSY = 16

    /// File exists.
    case EEXIST = 17

    /// Cross-device link.
    case EXDEV = 18

    /// Operation not supported by device.
    case ENODEV = 19

    /// Not a directory.
    case ENOTDIR = 20

    /// Is a directory.
    case EISDIR = 21

    /// Invalid argument.
    case EINVAL = 22

    /// Too many open files in system.
    case ENFILE = 23

    /// Too many open files.
    case EMFILE = 24

    /// Inappropriate ioctl for device.
    case ENOTTY = 25

    /// Text file busy.
    case ETXTBSY = 26

    /// File too large.
    case EFBIG = 27

    /// No space left on device.
    case ENOSPC = 28

    /// Illegal seek.
    case ESPIPE = 29

    /// Read-only file system.
    case EROFS = 30

    /// Too many links.
    case EMLINK = 31

    /// Broken pipe.
    case EPIPE = 32

    /// math software.
    /// Numerical argument out of domain.
    case EDOM = 33

    /// Result too large.
    case ERANGE = 34

    /// non-blocking and interrupt i/o.
    /// Resource temporarily unavailable.
    case EAGAIN = 35

    /// Operation would block.
    public static var EWOULDBLOCK: POSIXErrorCode { EAGAIN }

    /// Operation now in progress.
    case EINPROGRESS = 36

    /// Operation already in progress.
    case EALREADY = 37

    /// ipc/network software -- argument errors.
    /// Socket operation on non-socket.
    case ENOTSOCK = 38

    /// Destination address required.
    case EDESTADDRREQ = 39

    /// Message too long.
    case EMSGSIZE = 40

    /// Protocol wrong type for socket.
    case EPROTOTYPE = 41

    /// Protocol not available.
    case ENOPROTOOPT = 42

    /// Protocol not supported.
    case EPROTONOSUPPORT = 43

    /// Socket type not supported.
    case ESOCKTNOSUPPORT = 44

    /// Operation not supported.
    case ENOTSUP = 45

    /// Protocol family not supported.
    case EPFNOSUPPORT = 46

    /// Address family not supported by protocol family.
    case EAFNOSUPPORT = 47

    /// Address already in use.
    case EADDRINUSE = 48

    /// Can't assign requested address.
    case EADDRNOTAVAIL = 49

    /// ipc/network software -- operational errors
    /// Network is down.
    case ENETDOWN = 50

    /// Network is unreachable.
    case ENETUNREACH = 51

    /// Network dropped connection on reset.
    case ENETRESET = 52

    /// Software caused connection abort.
    case ECONNABORTED = 53

    /// Connection reset by peer.
    case ECONNRESET = 54

    /// No buffer space available.
    case ENOBUFS = 55

    /// Socket is already connected.
    case EISCONN = 56

    /// Socket is not connected.
    case ENOTCONN = 57

    /// Can't send after socket shutdown.
    case ESHUTDOWN = 58

    /// Too many references: can't splice.
    case ETOOMANYREFS = 59

    /// Operation timed out.
    case ETIMEDOUT = 60

    /// Connection refused.
    case ECONNREFUSED = 61

    /// Too many levels of symbolic links.
    case ELOOP = 62

    /// File name too long.
    case ENAMETOOLONG = 63

    /// Host is down.
    case EHOSTDOWN = 64

    /// No route to host.
    case EHOSTUNREACH = 65

    /// Directory not empty.
    case ENOTEMPTY = 66

    /// quotas & mush.
    /// Too many processes.
    case EPROCLIM = 67

    /// Too many users.
    case EUSERS = 68

    /// Disc quota exceeded.
    case EDQUOT = 69

    /// Network File System.
    /// Stale NFS file handle.
    case ESTALE = 70

    /// Too many levels of remote in path.
    case EREMOTE = 71

    /// RPC struct is bad.
    case EBADRPC = 72

    /// RPC version wrong.
    case ERPCMISMATCH = 73

    /// RPC prog. not avail.
    case EPROGUNAVAIL = 74

    /// Program version wrong.
    case EPROGMISMATCH = 75

    /// Bad procedure for program.
    case EPROCUNAVAIL = 76

    /// No locks available.
    case ENOLCK = 77

    /// Function not implemented.
    case ENOSYS = 78

    /// Inappropriate file type or format.
    case EFTYPE = 79

    /// Authentication error.
    case EAUTH = 80

    /// Need authenticator.
    case ENEEDAUTH = 81

    /// Intelligent device errors.
    /// Device power is off.
    case EPWROFF = 82

    /// Device error, e.g. paper out.
    case EDEVERR = 83

    /// Value too large to be stored in data type.
    case EOVERFLOW = 84

    /// Bad executable.
    case EBADEXEC = 85

    /// Bad CPU type in executable.
    case EBADARCH = 86

    /// Shared library version mismatch.
    case ESHLIBVERS = 87

    /// Malformed Macho file.
    case EBADMACHO = 88

    /// Operation canceled.
    case ECANCELED = 89

    /// Identifier removed.
    case EIDRM = 90

    /// No message of desired type.
    case ENOMSG = 91

    /// Illegal byte sequence.
    case EILSEQ = 92

    /// Attribute not found.
    case ENOATTR = 93

    /// Bad message.
    case EBADMSG = 94

    /// Reserved.
    case EMULTIHOP = 95

    /// No message available on STREAM.
    case ENODATA = 96

    /// Reserved.
    case ENOLINK = 97

    /// No STREAM resources.
    case ENOSR = 98

    /// Not a STREAM.
    case ENOSTR = 99

    /// Protocol error.
    case EPROTO = 100

    /// STREAM ioctl timeout.
    case ETIME = 101

    /// No such policy registered.
    case ENOPOLICY = 103

    /// State not recoverable.
    case ENOTRECOVERABLE = 104

    /// Previous owner died.
    case EOWNERDEAD = 105

    /// Interface output queue is full.
    case EQFULL = 106

    /// Must be equal largest errno.
    public static var ELAST: POSIXErrorCode { EQFULL }

    public typealias RawValue = Int32
}

extension POSIXErrorCode : Equatable, Hashable, RawRepresentable {
}

/// Describes an error in the POSIX error domain.
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public struct POSIXError : _StoredError {
    public let code: Code

    public static var errorDomain: String { "NSPOSIXErrorDomain" }

    public var hashValue: Int {
        code.hashValue
    }

    public typealias Code = POSIXErrorCode
}
#endif

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension POSIXErrorCode : _ErrorCodeProtocol {
    public typealias _ErrorType = POSIXError
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension POSIXError {
    public static var EPERM: POSIXErrorCode {
        .EPERM
    }

    /// No such file or directory.
    public static var ENOENT: POSIXErrorCode {
        .ENOENT
    }

    /// No such process.
    public static var ESRCH: POSIXErrorCode {
        .ESRCH
    }

    /// Interrupted system call.
    public static var EINTR: POSIXErrorCode {
        .EINTR
    }

    /// Input/output error.
    public static var EIO: POSIXErrorCode {
        .EIO
    }

    /// Device not configured.
    public static var ENXIO: POSIXErrorCode {
        .ENXIO
    }

    /// Argument list too long.
    public static var E2BIG: POSIXErrorCode {
        .E2BIG
    }

    /// Exec format error.
    public static var ENOEXEC: POSIXErrorCode {
        .ENOEXEC
    }

    /// Bad file descriptor.
    public static var EBADF: POSIXErrorCode {
        .EBADF
    }

    /// No child processes.
    public static var ECHILD: POSIXErrorCode {
        .ECHILD
    }

    /// Resource deadlock avoided.
    public static var EDEADLK: POSIXErrorCode {
        .EDEADLK
    }

    /// Cannot allocate memory.
    public static var ENOMEM: POSIXErrorCode {
        .ENOMEM
    }

    /// Permission denied.
    public static var EACCES: POSIXErrorCode {
        .EACCES
    }

    /// Bad address.
    public static var EFAULT: POSIXErrorCode {
        .EFAULT
    }

    /// Block device required.
    public static var ENOTBLK: POSIXErrorCode {
        .ENOTBLK
    }
    /// Device / Resource busy.
    public static var EBUSY: POSIXErrorCode {
        .EBUSY
    }
    /// File exists.
    public static var EEXIST: POSIXErrorCode {
        .EEXIST
    }
    /// Cross-device link.
    public static var EXDEV: POSIXErrorCode {
        .EXDEV
    }
    /// Operation not supported by device.
    public static var ENODEV: POSIXErrorCode {
        .ENODEV
    }
    /// Not a directory.
    public static var ENOTDIR: POSIXErrorCode {
        .ENOTDIR
    }
    /// Is a directory.
    public static var EISDIR: POSIXErrorCode {
        .EISDIR
    }
    /// Invalid argument.
    public static var EINVAL: POSIXErrorCode {
        .EINVAL
    }
    /// Too many open files in system.
    public static var ENFILE: POSIXErrorCode {
        .ENFILE
    }
    /// Too many open files.
    public static var EMFILE: POSIXErrorCode {
        .EMFILE
    }
    /// Inappropriate ioctl for device.
    public static var ENOTTY: POSIXErrorCode {
        .ENOTTY
    }
    /// Text file busy.
    public static var ETXTBSY: POSIXErrorCode {
        .ETXTBSY
    }
    /// File too large.
    public static var EFBIG: POSIXErrorCode {
        .EFBIG
    }
    /// No space left on device.
    public static var ENOSPC: POSIXErrorCode {
        .ENOSPC
    }
    /// Illegal seek.
    public static var ESPIPE: POSIXErrorCode {
        .ESPIPE
    }
    /// Read-only file system.
    public static var EROFS: POSIXErrorCode {
        .EROFS
    }
    /// Too many links.
    public static var EMLINK: POSIXErrorCode {
        .EMLINK
    }
    /// Broken pipe.
    public static var EPIPE: POSIXErrorCode {
        .EPIPE
    }

    /// math software.
    /// Numerical argument out of domain.
    public static var EDOM: POSIXErrorCode {
        .EDOM
    }
    /// Result too large.
    public static var ERANGE: POSIXErrorCode {
        .ERANGE
    }

    /// non-blocking and interrupt i/o.
    /// Resource temporarily unavailable.
    public static var EAGAIN: POSIXErrorCode {
        .EAGAIN
    }
    /// Operation would block.
    public static var EWOULDBLOCK: POSIXErrorCode {
        .EWOULDBLOCK
    }
    /// Operation now in progress.
    public static var EINPROGRESS: POSIXErrorCode {
        .EINPROGRESS
    }
    /// Operation already in progress.
    public static var EALREADY: POSIXErrorCode {
        .EALREADY
    }

    /// ipc/network software -- argument errors.
    /// Socket operation on non-socket.
    public static var ENOTSOCK: POSIXErrorCode {
        .ENOTSOCK
    }
    /// Destination address required.
    public static var EDESTADDRREQ: POSIXErrorCode {
        .EDESTADDRREQ
    }
    /// Message too long.
    public static var EMSGSIZE: POSIXErrorCode {
        .EMSGSIZE
    }
    /// Protocol wrong type for socket.
    public static var EPROTOTYPE: POSIXErrorCode {
        .EPROTOTYPE
    }
    /// Protocol not available.
    public static var ENOPROTOOPT: POSIXErrorCode {
        .ENOPROTOOPT
    }
    /// Protocol not supported.
    public static var EPROTONOSUPPORT: POSIXErrorCode {
        .EPROTONOSUPPORT
    }
    /// Socket type not supported.
    public static var ESOCKTNOSUPPORT: POSIXErrorCode {
        .ESOCKTNOSUPPORT
    }
    /// Operation not supported.
    public static var ENOTSUP: POSIXErrorCode {
        .ENOTSUP
    }
    /// Protocol family not supported.
    public static var EPFNOSUPPORT: POSIXErrorCode {
        .EPFNOSUPPORT
    }
    /// Address family not supported by protocol family.
    public static var EAFNOSUPPORT: POSIXErrorCode {
        .EAFNOSUPPORT
    }

    /// Address already in use.
    public static var EADDRINUSE: POSIXErrorCode {
        .EADDRINUSE
    }
    /// Can't assign requested address.
    public static var EADDRNOTAVAIL: POSIXErrorCode {
        .EADDRNOTAVAIL
    }

    /// ipc/network software -- operational errors
    /// Network is down.
    public static var ENETDOWN: POSIXErrorCode {
        .ENETDOWN
    }
    /// Network is unreachable.
    public static var ENETUNREACH: POSIXErrorCode {
        .ENETUNREACH
    }
    /// Network dropped connection on reset.
    public static var ENETRESET: POSIXErrorCode {
        .ENETRESET
    }
    /// Software caused connection abort.
    public static var ECONNABORTED: POSIXErrorCode {
        .ECONNABORTED
    }
    /// Connection reset by peer.
    public static var ECONNRESET: POSIXErrorCode {
        .ECONNRESET
    }
    /// No buffer space available.
    public static var ENOBUFS: POSIXErrorCode {
        .ENOBUFS
    }
    /// Socket is already connected.
    public static var EISCONN: POSIXErrorCode {
        .EISCONN
    }
    /// Socket is not connected.
    public static var ENOTCONN: POSIXErrorCode {
        .ENOTCONN
    }
    /// Can't send after socket shutdown.
    public static var ESHUTDOWN: POSIXErrorCode {
        .ESHUTDOWN
    }
    /// Too many references: can't splice.
    public static var ETOOMANYREFS: POSIXErrorCode {
        .ETOOMANYREFS
    }
    /// Operation timed out.
    public static var ETIMEDOUT: POSIXErrorCode {
        .ETIMEDOUT
    }
    /// Connection refused.
    public static var ECONNREFUSED: POSIXErrorCode {
        .ECONNREFUSED
    }

    /// Too many levels of symbolic links.
    public static var ELOOP: POSIXErrorCode {
        .ELOOP
    }
    /// File name too long.
    public static var ENAMETOOLONG: POSIXErrorCode {
        .ENAMETOOLONG
    }

    /// Host is down.
    public static var EHOSTDOWN: POSIXErrorCode {
        .EHOSTDOWN
    }
    /// No route to host.
    public static var EHOSTUNREACH: POSIXErrorCode {
        .EHOSTUNREACH
    }
    /// Directory not empty.
    public static var ENOTEMPTY: POSIXErrorCode {
        .ENOTEMPTY
    }

    /// quotas & mush.
    /// Too many processes.
    public static var EPROCLIM: POSIXErrorCode {
        .EPROCLIM
    }
    /// Too many users.
    public static var EUSERS: POSIXErrorCode {
        .EUSERS
    }
    /// Disc quota exceeded.
    public static var EDQUOT: POSIXErrorCode {
        .EDQUOT
    }

    /// Network File System.
    /// Stale NFS file handle.
    public static var ESTALE: POSIXErrorCode {
        .ESTALE
    }
    /// Too many levels of remote in path.
    public static var EREMOTE: POSIXErrorCode {
        .EREMOTE
    }
    /// RPC struct is bad.
    public static var EBADRPC: POSIXErrorCode {
        .EBADRPC
    }
    /// RPC version wrong.
    public static var ERPCMISMATCH: POSIXErrorCode {
        .ERPCMISMATCH
    }
    /// RPC prog. not avail.
    public static var EPROGUNAVAIL: POSIXErrorCode {
        .EPROGUNAVAIL
    }
    /// Program version wrong.
    public static var EPROGMISMATCH: POSIXErrorCode {
        .EPROGMISMATCH
    }
    /// Bad procedure for program.
    public static var EPROCUNAVAIL: POSIXErrorCode {
        .EPROCUNAVAIL
    }

    /// No locks available.
    public static var ENOLCK: POSIXErrorCode {
        .ENOLCK
    }
    /// Function not implemented.
    public static var ENOSYS: POSIXErrorCode {
        .ENOSYS
    }

    /// Inappropriate file type or format.
    public static var EFTYPE: POSIXErrorCode {
        .EFTYPE
    }
    /// Authentication error.
    public static var EAUTH: POSIXErrorCode {
        .EAUTH
    }
    /// Need authenticator.
    public static var ENEEDAUTH: POSIXErrorCode {
        .ENEEDAUTH
    }

    /// Intelligent device errors.
    /// Device power is off.
    public static var EPWROFF: POSIXErrorCode {
        .EPWROFF
    }
    /// Device error, e.g. paper out.
    public static var EDEVERR: POSIXErrorCode {
        .EDEVERR
    }

    /// Value too large to be stored in data type.
    public static var EOVERFLOW: POSIXErrorCode {
        .EOVERFLOW
    }

    /// Program loading errors.
    /// Bad executable.
    public static var EBADEXEC: POSIXErrorCode {
        .EBADEXEC
    }
    /// Bad CPU type in executable.
    public static var EBADARCH: POSIXErrorCode {
        .EBADARCH
    }
    /// Shared library version mismatch.
    public static var ESHLIBVERS: POSIXErrorCode {
        .ESHLIBVERS
    }
    /// Malformed Macho file.
    public static var EBADMACHO: POSIXErrorCode {
        .EBADMACHO
    }

    /// Operation canceled.
    public static var ECANCELED: POSIXErrorCode {
        .ECANCELED
    }

    /// Identifier removed.
    public static var EIDRM: POSIXErrorCode {
        .EIDRM
    }
    /// No message of desired type.
    public static var ENOMSG: POSIXErrorCode {
        .ENOMSG
    }
    /// Illegal byte sequence.
    public static var EILSEQ: POSIXErrorCode {
        .EILSEQ
    }
    /// Attribute not found.
    public static var ENOATTR: POSIXErrorCode {
        .ENOATTR
    }

    /// Bad message.
    public static var EBADMSG: POSIXErrorCode {
        .EBADMSG
    }
    /// Reserved.
    public static var EMULTIHOP: POSIXErrorCode {
        .EMULTIHOP
    }
    /// No message available on STREAM.
    public static var ENODATA: POSIXErrorCode {
        .ENODATA
    }
    /// Reserved.
    public static var ENOLINK: POSIXErrorCode {
        .ENOLINK
    }
    /// No STREAM resources.
    public static var ENOSR: POSIXErrorCode {
        .ENOSR
    }
    /// Not a STREAM.
    public static var ENOSTR: POSIXErrorCode {
        .ENOSTR
    }
    /// Protocol error.
    public static var EPROTO: POSIXErrorCode {
        .EPROTO
    }
    /// STREAM ioctl timeout.
    public static var ETIME: POSIXErrorCode {
        .ETIME
    }

    /// No such policy registered.
    public static var ENOPOLICY: POSIXErrorCode {
        .ENOPOLICY
    }

    /// State not recoverable.
    public static var ENOTRECOVERABLE: POSIXErrorCode {
        .ENOTRECOVERABLE
    }
    /// Previous owner died.
    public static var EOWNERDEAD: POSIXErrorCode {
        .EOWNERDEAD
    }

    /// Interface output queue is full.
    public static var EQFULL: POSIXErrorCode {
        .EQFULL
    }
}
