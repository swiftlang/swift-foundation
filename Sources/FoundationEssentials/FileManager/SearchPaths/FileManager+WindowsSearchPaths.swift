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

#if os(Windows)

import WinSDK

private func _url(for id: KNOWNFOLDERID) -> URL {
    var pszPath: PWSTR?
    let hr: HRESULT = withUnsafePointer(to: id) { id in
        SHGetKnownFolderPath(id, KF_FLAG_DEFAULT, nil, &pszPath)
    }
    precondition(SUCCEEDED(hr), "SHGetKnownFolderPath failed \(String(hr, radix: 16))")
    defer { CoTaskMemFree(pszPath) }
    return URL(filePath: String(decodingCString: pszPath!, as: UTF16.self), directoryHint: .isDirectory)
}

func _WindowsSearchPathURL(for directory: FileManager.SearchPathDirectory, in domain: FileManager.SearchPathDomainMask) -> URL? {
    switch (directory, domain) {
    case (.desktopDirectory, .userDomainMask):
        _url(for: FOLDERID_Desktop)

    case (.documentDirectory, .userDomainMask):
        _url(for: FOLDERID_Documents)

    case (.cachesDirectory, .userDomainMask):
        FileManager.default.temporaryDirectory

    case (.applicationSupportDirectory, .localDomainMask):
        _url(for: FOLDERID_ProgramData)

    case (.applicationSupportDirectory, .userDomainMask):
        _url(for: FOLDERID_LocalAppData)

    case (.downloadsDirectory, .userDomainMask):
        _url(for: FOLDERID_Downloads)

    case (.userDirectory, .localDomainMask):
        _url(for: FOLDERID_UserProfiles)

    case (.moviesDirectory, .userDomainMask):
        _url(for: FOLDERID_Videos)

    case (.musicDirectory, .userDomainMask):
        _url(for: FOLDERID_Music)

    case (.picturesDirectory, .userDomainMask):
        _url(for: FOLDERID_PicturesLibrary)

    case (.sharedPublicDirectory, .userDomainMask):
        _url(for: FOLDERID_Public)

    case (.trashDirectory, .userDomainMask):
        // The "Recycle Bin" is a virtual folder and we cannot get a path from
        // it directly using `SHGetKnownFolderPath`.
        // TODO: identify how to get a path, even if a namespaced PIDL, for the
        // user.
        nil

    default: nil
    }
}

#endif
