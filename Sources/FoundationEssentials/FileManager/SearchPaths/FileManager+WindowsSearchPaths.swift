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

private func _url(for id: KNOWNFOLDERID) -> URL {
    var pszPath: PWSTR?
    let hrResult: HRESULT = withUnsafePointer(to: id) { id in
        SHGetKnownFolderPath(id, KF_FLAG_DEFAULT, nil, &pszPath)
    }
    precondition(SUCCEEDED(hrResult), "SHGetKnownFolderpath failed \(GetLastError())")
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
        _url(for: FOLDERID_RecycleBinFolder)

    default: nil
    }
}

#endif
