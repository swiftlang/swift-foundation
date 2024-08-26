//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2014 - 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//
#if !FOUNDATION_FRAMEWORK
public struct URLResourceKey {}
#endif

#if FOUNDATION_FRAMEWORK
internal import _ForSwiftFoundation
internal import CoreFoundation_Private.CFURL

/// URLs to file system resources support the properties defined below.
///
/// Note that not all property values will exist for all file system URLs. For example, if a file is located on a volume that does not support creation dates, it is valid to request the creation date property, but the returned value will be nil, and no error will be generated.
///
/// Only the fields requested by the keys you pass into the `URL` function to receive this value will be populated. The others will return `nil` regardless of the underlying property on the file system. As a convenience, volume resource values can be requested from any file system URL. The value returned will reflect the property value for the volume on which the resource is located.
@_nonSendable
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public struct URLResourceValues {

    fileprivate var _values: [URLResourceKey: Any]
    fileprivate var _keys: Set<URLResourceKey>

    public init() {
        _values = [:]
        _keys = []
    }

#if !NO_FILESYSTEM

    fileprivate init(keys: Set<URLResourceKey>, values: [URLResourceKey: Any]) {
        _values = values
        _keys = keys
    }

    init(values: [URLResourceKey: Any]) {
        _values = values
        _keys = Set(values.keys)
    }

    private func contains(_ key: URLResourceKey) -> Bool {
        return _keys.contains(key)
    }

    private func _get<T>(_ key: URLResourceKey) -> T? {
        return _values[key] as? T
    }

    private func _get(_ key: URLResourceKey) -> Bool? {
        return (_values[key] as? NSNumber)?.boolValue
    }

    private func _get(_ key: URLResourceKey) -> Int? {
        return (_values[key] as? NSNumber)?.intValue
    }

    private mutating func _set(_ key: URLResourceKey, newValue: __owned Any?) {
        _keys.insert(key)
        _values[key] = newValue
    }

    private mutating func _set(_ key: URLResourceKey, newValue: String?) {
        _keys.insert(key)
        _values[key] = newValue as NSString?
    }

    private mutating func _set(_ key: URLResourceKey, newValue: [String]?) {
        _keys.insert(key)
        _values[key] = newValue as NSObject?
    }

    private mutating func _set(_ key: URLResourceKey, newValue: Date?) {
        _keys.insert(key)
        _values[key] = newValue as NSDate?
    }

    private mutating func _set(_ key: URLResourceKey, newValue: URL?) {
        _keys.insert(key)
        _values[key] = newValue as NSURL?
    }

    private mutating func _set(_ key: URLResourceKey, newValue: Bool?) {
        _keys.insert(key)
        if let value = newValue {
            _values[key] = NSNumber(value: value)
        } else {
            _values[key] = nil
        }
    }

    private mutating func _set(_ key: URLResourceKey, newValue: Int?) {
        _keys.insert(key)
        if let value = newValue {
            _values[key] = NSNumber(value: value)
        } else {
            _values[key] = nil
        }
    }

    /// A loosely-typed dictionary containing all keys and values.
    ///
    /// If you have set temporary keys or non-standard keys, you can find them in here.
    public var allValues: [URLResourceKey: Any] {
        return _values
    }

    /// The resource name provided by the file system.
    public var name: String? {
        get { return _get(.nameKey) }
        set { _set(.nameKey, newValue: newValue) }
    }

    /// Localized or extension-hidden name as displayed to users.
    public var localizedName: String? { return _get(.localizedNameKey) }

    /// True for regular files.
    public var isRegularFile: Bool? { return _get(.isRegularFileKey) }

    /// True for directories.
    public var isDirectory: Bool? { return _get(.isDirectoryKey) }

    /// True for symlinks.
    public var isSymbolicLink: Bool? { return _get(.isSymbolicLinkKey) }

    /// True for the root directory of a volume.
    public var isVolume: Bool? { return _get(.isVolumeKey) }

    /// True for packaged directories.
    ///
    /// - note: You can only set or clear this property on directories; if you try to set this property on non-directory objects, the property is ignored. If the directory is a package for some other reason (extension type, etc), setting this property to false will have no effect.
    public var isPackage: Bool? {
        get { return _get(.isPackageKey) }
        set { _set(.isPackageKey, newValue: newValue) }
    }

    /// True if resource is an application.
    @available(macOS 10.11, iOS 9.0, watchOS 2.0, tvOS 9.0, *)
    public var isApplication: Bool? { return _get(.isApplicationKey) }

#if os(macOS)
    /// True if the resource is scriptable. Only applies to applications.
    @available(macOS 10.11, *)
    public var applicationIsScriptable: Bool? { return _get(.applicationIsScriptableKey) }
#endif

    /// True for system-immutable resources.
    public var isSystemImmutable: Bool? { return _get(.isSystemImmutableKey) }

    /// True for user-immutable resources
    public var isUserImmutable: Bool? {
        get { return _get(.isUserImmutableKey) }
        set { _set(.isUserImmutableKey, newValue: newValue) }
    }

    /// True for resources normally not displayed to users.
    ///
    /// - note: If the resource is a hidden because its name starts with a period, setting this property to false will not change the property.
    public var isHidden: Bool? {
        get { return _get(.isHiddenKey) }
        set { _set(.isHiddenKey, newValue: newValue) }
    }

    /// True for resources whose filename extension is removed from the localized name property.
    public var hasHiddenExtension: Bool? {
        get { return _get(.hasHiddenExtensionKey) }
        set { _set(.hasHiddenExtensionKey, newValue: newValue) }
    }

    /// The date the resource was created.
    public var creationDate: Date? {
        get { return _get(.creationDateKey) }
        set { _set(.creationDateKey, newValue: newValue) }
    }

    /// The date the resource was last accessed.
    public var contentAccessDate: Date? {
        get { return _get(.contentAccessDateKey) }
        set { _set(.contentAccessDateKey, newValue: newValue) }
    }

    /// The time the resource content was last modified.
    public var contentModificationDate: Date? {
        get { return _get(.contentModificationDateKey) }
        set { _set(.contentModificationDateKey, newValue: newValue) }
    }

    /// The time the resource's attributes were last modified.
    public var attributeModificationDate: Date? { return _get(.attributeModificationDateKey) }

    /// Number of hard links to the resource.
    public var linkCount: Int? { return _get(.linkCountKey) }

    /// The resource's parent directory, if any.
    public var parentDirectory: URL? { return _get(.parentDirectoryURLKey) }

    /// URL of the volume on which the resource is stored.
    public var volume: URL? { return _get(.volumeURLKey) }

    /// Uniform type identifier (UTI) for the resource.
    @available(macOS, introduced: 10.10, deprecated: 100000.0, message: "Use .contentType instead")
    @available(iOS, introduced: 8.0, deprecated: 100000.0, message: "Use .contentType instead")
    @available(watchOS, introduced: 2.0, deprecated: 100000.0, message: "Use .contentType instead")
    @available(tvOS, introduced: 9.0, deprecated: 100000.0, message: "Use .contentType instead")
    @available(visionOS, introduced: 1.0, deprecated: 100000.0, message: "Use .contentType instead")
    public var typeIdentifier: String? { return _get(.typeIdentifierKey) }

    /// User-visible type or "kind" description.
    public var localizedTypeDescription: String? { return _get(.localizedTypeDescriptionKey) }

    /// The label number assigned to the resource.
    public var labelNumber: Int? {
        get { return _get(.labelNumberKey) }
        set { _set(.labelNumberKey, newValue: newValue) }
    }


    /// The user-visible label text.
    public var localizedLabel: String? {
        get { return _get(.localizedLabelKey) }
    }

    /// An identifier which can be used to compare two file system objects for equality using `isEqual`.
    ///
    /// Two object identifiers are equal if they have the same file system path or if the paths are linked to same inode on the same file system. This identifier is not persistent across system restarts.
    public var fileResourceIdentifier: (NSCopying & NSCoding & NSSecureCoding & NSObjectProtocol)? { return _get(.fileResourceIdentifierKey) }

    /// An identifier that can be used to identify the volume the file system object is on.
    ///
    /// Other objects on the same volume will have the same volume identifier and can be compared using for equality using `isEqual`. This identifier is not persistent across system restarts.
    public var volumeIdentifier: (NSCopying & NSCoding & NSSecureCoding & NSObjectProtocol)? { return _get(.volumeIdentifierKey) }

    /// The file system's internal inode identifier for the item. This value is not stable for all file systems or
    /// across all mounts, so it should be used sparingly and not persisted. It is useful, for example, to match URLs from
    /// the URL enumerator with paths from FSEvents.
    @available( macOS 13.3, iOS 16.4, tvOS 16.4, watchOS 9.4, *)
    public var fileIdentifier: UInt64? { return _get(.fileIdentifierKey) }

    /// A 64-bit value assigned by APFS that identifies a file's content data stream. Only cloned files and their originals can have the same identifier.
    @available(macOS 10.16, iOS 14.0, tvOS 14.0, watchOS 7.0, *)
    public var fileContentIdentifier: Int64? { return _get(.fileContentIdentifierKey) }

    /// The optimal block size when reading or writing this file's data, or nil if not available.
    public var preferredIOBlockSize: Int? { return _get(.preferredIOBlockSizeKey) }

    /// True if this process (as determined by EUID) can read the resource.
    public var isReadable: Bool? { return _get(.isReadableKey) }

    /// True if this process (as determined by EUID) can write to the resource.
    public var isWritable: Bool? { return _get(.isWritableKey) }

    /// True if this process (as determined by EUID) can execute a file resource or search a directory resource.
    public var isExecutable: Bool? { return _get(.isExecutableKey) }

    /// The file system object's security information encapsulated in a FileSecurity object.
    public var fileSecurity: NSFileSecurity? {
        get { return _get(.fileSecurityKey) }
        set { _set(.fileSecurityKey, newValue: newValue) }
    }

    /// True if resource should be excluded from backups, false otherwise.
    ///
    /// This property is only useful for excluding cache and other application support files which are not needed in a backup. Some operations commonly made to user documents will cause this property to be reset to false and so this property should not be used on user documents.
    public var isExcludedFromBackup: Bool? {
        get { return _get(.isExcludedFromBackupKey) }
        set { _set(.isExcludedFromBackupKey, newValue: newValue) }
    }

#if os(macOS)
    /// The array of Tag names.
    public var tagNames: [String]? { return _get(.tagNamesKey) }
#endif

    /// The URL's path as a file system path.
    public var path: String? { return _get(.pathKey) }

    /// The URL's path as a canonical absolute file system path.
    @available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *)
    public var canonicalPath: String? { return _get(.canonicalPathKey) }

    /// True if this URL is a file system trigger directory. Traversing or opening a file system trigger will cause an attempt to mount a file system on the trigger directory.
    public var isMountTrigger: Bool? { return _get(.isMountTriggerKey) }

    /// An opaque generation identifier which can be compared using `==` to determine if the data in a document has been modified.
    ///
    /// For URLs which refer to the same file inode, the generation identifier will change when the data in the file's data fork is changed (changes to extended attributes or other file system metadata do not change the generation identifier). For URLs which refer to the same directory inode, the generation identifier will change when direct children of that directory are added, removed or renamed (changes to the data of the direct children of that directory will not change the generation identifier). The generation identifier is persistent across system restarts. The generation identifier is tied to a specific document on a specific volume and is not transferred when the document is copied to another volume. This property is not supported by all volumes.
    @available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
    public var generationIdentifier: (NSCopying & NSCoding & NSSecureCoding & NSObjectProtocol)? { return _get(.generationIdentifierKey) }

    /// The document identifier -- a value assigned by the kernel to a document (which can be either a file or directory) and is used to identify the document regardless of where it gets moved on a volume.
    ///
    /// The document identifier survives "safe save" operations; i.e it is sticky to the path it was assigned to (`replaceItem(at:,withItemAt:,backupItemName:,options:,resultingItem:) throws` is the preferred safe-save API). The document identifier is persistent across system restarts. The document identifier is not transferred when the file is copied. Document identifiers are only unique within a single volume. This property is not supported by all volumes.
    @available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
    public var documentIdentifier: Int? { return _get(.documentIdentifierKey) }

    /// The date the resource was created, or renamed into or within its parent directory. Note that inconsistent behavior may be observed when this attribute is requested on hard-linked items. This property is not supported by all volumes.
    @available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
    public var addedToDirectoryDate: Date? { return _get(.addedToDirectoryDateKey) }

#if os(macOS)
    /// The quarantine properties as defined in LSQuarantine.h. To remove quarantine information from a file, pass `nil` as the value when setting this property.
    @available(macOS 10.10, *)
    public var quarantineProperties: [String: Any]? {
        get {
            let value = _values[.quarantinePropertiesKey]
            // If a caller has caused us to stash NSNull in the dictionary (via set), make sure to return nil instead of NSNull
            if value is NSNull {
                return nil
            } else {
                return value as? [String: Any]
            }
        }
        set {
            // Use NSNull for nil, a special case for deleting quarantine properties
            _set(.quarantinePropertiesKey, newValue: newValue ?? NSNull())
        }
    }
#endif // os(macOS)

    /// True if the file may have extended attributes. False guarantees there are none.
    @available(macOS 10.16, iOS 14.0, tvOS 14.0, watchOS 7.0, *)
    public var mayHaveExtendedAttributes: Bool? { return _get(.mayHaveExtendedAttributesKey) }

    /// True if the file can be deleted by the file system when asked to free space.
    @available(macOS 10.16, iOS 14.0, tvOS 14.0, watchOS 7.0, *)
    public var isPurgeable: Bool? { return _get(.isPurgeableKey) }

    /// True if the file has sparse regions.
    @available(macOS 10.16, iOS 14.0, tvOS 14.0, watchOS 7.0, *)
    public var isSparse: Bool? { return _get(.isSparseKey) }

    /// True for cloned files and their originals that may share all, some, or no data blocks.
    @available(macOS 10.16, iOS 14.0, tvOS 14.0, watchOS 7.0, *)
    public var mayShareFileContent: Bool? { return _get(.mayShareFileContentKey) }

    /// Returns the file system object type.
    public var fileResourceType: URLFileResourceType? { return _get(.fileResourceTypeKey) }

    /// Returns the count of file system objects contained in the directory. If the URL is not a directory or the file system cannot cheaply compute the value, `nil` is returned.
    @available( macOS 14.0, iOS 17.0, tvOS 17.0, watchOS 10.0, *)
    public var directoryEntryCount: Int? { return _get(.directoryEntryCountKey) }

    /// The user-visible volume format.
    public var volumeLocalizedFormatDescription: String? { return _get(.volumeLocalizedFormatDescriptionKey) }

    /// Total volume capacity in bytes.
    public var volumeTotalCapacity: Int? { return _get(.volumeTotalCapacityKey) }

    /// Total free space in bytes.
    public var volumeAvailableCapacity: Int? { return _get(.volumeAvailableCapacityKey) }

#if os(macOS) || os(iOS)
    /// Total available capacity in bytes for "Important" resources, including space expected to be cleared by purging non-essential and cached resources.
    ///
    /// "Important" means something that the user or application clearly expects to be present on the local system, but is ultimately replaceable. This would include items that the user has explicitly requested via the UI, and resources that an application requires in order to provide functionality.
    /// Examples: A video that the user has explicitly requested to watch but has not yet finished watching or an audio file that the user has requested to download.
    /// This value should not be used in determining if there is room for an irreplaceable resource. In the case of irreplaceable resources, always attempt to save the resource regardless of available capacity and handle failure as gracefully as possible.
    @available(macOS 10.13, iOS 11.0, *) @available(tvOS, unavailable) @available(watchOS, unavailable)
    public var volumeAvailableCapacityForImportantUsage: Int64? { return _get(.volumeAvailableCapacityForImportantUsageKey) }

    /// Total available capacity in bytes for "Opportunistic" resources, including space expected to be cleared by purging non-essential and cached resources.
    ///
    /// "Opportunistic" means something that the user is likely to want but does not expect to be present on the local system, but is ultimately non-essential and replaceable. This would include items that will be created or downloaded without an explicit request from the user on the current device.
    /// Examples: A background download of a newly available episode of a TV series that a user has been recently watching, a piece of content explicitly requested on another device, and a new document saved to a network server by the current user from another device.
    @available(macOS 10.13, iOS 11.0, *) @available(tvOS, unavailable) @available(watchOS, unavailable)
    public var volumeAvailableCapacityForOpportunisticUsage: Int64? { return _get(.volumeAvailableCapacityForOpportunisticUsageKey) }
#endif // os(macOS) || os(iOS)

    /// Total number of resources on the volume.
    public var volumeResourceCount: Int? { return _get(.volumeResourceCountKey) }

    /// True if the volume format supports persistent object identifiers and can look up file system objects by their IDs.
    public var volumeSupportsPersistentIDs: Bool? { return _get(.volumeSupportsPersistentIDsKey) }

    /// True if the volume format supports symbolic links.
    public var volumeSupportsSymbolicLinks: Bool? { return _get(.volumeSupportsSymbolicLinksKey) }

    /// True if the volume format supports hard links.
    public var volumeSupportsHardLinks: Bool? { return _get(.volumeSupportsHardLinksKey) }

    /// True if the volume format supports a journal used to speed recovery in case of unplanned restart (such as a power outage or crash). This does not necessarily mean the volume is actively using a journal.
    public var volumeSupportsJournaling: Bool? { return _get(.volumeSupportsJournalingKey) }

    /// True if the volume is currently using a journal for speedy recovery after an unplanned restart.
    public var volumeIsJournaling: Bool? { return _get(.volumeIsJournalingKey) }

    /// True if the volume format supports sparse files, that is, files which can have 'holes' that have never been written to, and thus do not consume space on disk. A sparse file may have an allocated size on disk that is less than its logical length.
    public var volumeSupportsSparseFiles: Bool? { return _get(.volumeSupportsSparseFilesKey) }

    /// For security reasons, parts of a file (runs) that have never been written to must appear to contain zeroes. True if the volume keeps track of allocated but unwritten runs of a file so that it can substitute zeroes without actually writing zeroes to the media.
    public var volumeSupportsZeroRuns: Bool? { return _get(.volumeSupportsZeroRunsKey) }

    /// True if the volume format treats upper and lower case characters in file and directory names as different. Otherwise an upper case character is equivalent to a lower case character, and you can't have two names that differ solely in the case of the characters.
    public var volumeSupportsCaseSensitiveNames: Bool? { return _get(.volumeSupportsCaseSensitiveNamesKey) }

    /// True if the volume format preserves the case of file and directory names.  Otherwise the volume may change the case of some characters (typically making them all upper or all lower case).
    public var volumeSupportsCasePreservedNames: Bool? { return _get(.volumeSupportsCasePreservedNamesKey) }

    /// True if the volume supports reliable storage of times for the root directory.
    public var volumeSupportsRootDirectoryDates: Bool? { return _get(.volumeSupportsRootDirectoryDatesKey) }

    /// True if the volume supports returning volume size values (`volumeTotalCapacity` and `volumeAvailableCapacity`).
    public var volumeSupportsVolumeSizes: Bool? { return _get(.volumeSupportsVolumeSizesKey) }

    /// True if the volume can be renamed.
    public var volumeSupportsRenaming: Bool? { return _get(.volumeSupportsRenamingKey) }

    /// True if the volume implements whole-file flock(2) style advisory locks, and the O_EXLOCK and O_SHLOCK flags of the open(2) call.
    public var volumeSupportsAdvisoryFileLocking: Bool? { return _get(.volumeSupportsAdvisoryFileLockingKey) }

    /// True if the volume implements extended security (ACLs).
    public var volumeSupportsExtendedSecurity: Bool? { return _get(.volumeSupportsExtendedSecurityKey) }

    /// True if the volume should be visible via the GUI (i.e., appear on the Desktop as a separate volume).
    public var volumeIsBrowsable: Bool? { return _get(.volumeIsBrowsableKey) }

    /// The largest file size (in bytes) supported by this file system, or nil if this cannot be determined.
    public var volumeMaximumFileSize: Int? { return _get(.volumeMaximumFileSizeKey) }

    /// True if the volume's media is ejectable from the drive mechanism under software control.
    public var volumeIsEjectable: Bool? { return _get(.volumeIsEjectableKey) }

    /// True if the volume's media is removable from the drive mechanism.
    public var volumeIsRemovable: Bool? { return _get(.volumeIsRemovableKey) }

    /// True if the volume's device is connected to an internal bus, false if connected to an external bus, or nil if not available.
    public var volumeIsInternal: Bool? { return _get(.volumeIsInternalKey) }

    /// True if the volume is automounted. Note: do not mistake this with the functionality provided by kCFURLVolumeSupportsBrowsingKey.
    public var volumeIsAutomounted: Bool? { return _get(.volumeIsAutomountedKey) }

    /// True if the volume is stored on a local device.
    public var volumeIsLocal: Bool? { return _get(.volumeIsLocalKey) }

    /// True if the volume is read-only.
    public var volumeIsReadOnly: Bool? { return _get(.volumeIsReadOnlyKey) }

    /// The volume's creation date, or nil if this cannot be determined.
    public var volumeCreationDate: Date? { return _get(.volumeCreationDateKey) }

    /// The `URL` needed to remount a network volume, or nil if not available.
    public var volumeURLForRemounting: URL? { return _get(.volumeURLForRemountingKey) }

    /// The volume's persistent `UUID` as a string, or nil if a persistent `UUID` is not available for the volume.
    public var volumeUUIDString: String? { return _get(.volumeUUIDStringKey) }

    /// The name of the volume
    public var volumeName: String? {
        get { return _get(.volumeNameKey) }
        set { _set(.volumeNameKey, newValue: newValue) }
    }

    /// The user-presentable name of the volume
    public var volumeLocalizedName: String? { return _get(.volumeLocalizedNameKey) }

    /// True if the volume is encrypted.
    @available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *)
    public var volumeIsEncrypted: Bool? { return _get(.volumeIsEncryptedKey) }

    /// True if the volume is the root filesystem.
    @available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *)
    public var volumeIsRootFileSystem: Bool? { return _get(.volumeIsRootFileSystemKey) }

    /// True if the volume supports transparent decompression of compressed files using decmpfs.
    @available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *)
    public var volumeSupportsCompression: Bool? { return _get(.volumeSupportsCompressionKey) }

    /// True if the volume supports clonefile(2).
    @available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *)
    public var volumeSupportsFileCloning: Bool? { return _get(.volumeSupportsFileCloningKey) }

    /// True if the volume supports renamex_np(2)'s RENAME_SWAP option.
    @available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *)
    public var volumeSupportsSwapRenaming: Bool? { return _get(.volumeSupportsSwapRenamingKey) }

    /// True if the volume supports renamex_np(2)'s RENAME_EXCL option.
    @available(macOS 10.12, iOS 10.0, tvOS 10.0, watchOS 3.0, *)
    public var volumeSupportsExclusiveRenaming: Bool? { return _get(.volumeSupportsExclusiveRenamingKey) }

    /// True if the volume supports making files immutable with isUserImmutable or isSystemImmutable.
    @available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    public var volumeSupportsImmutableFiles: Bool? { return _get(.volumeSupportsImmutableFilesKey) }

    /// True if the volume supports setting POSIX access permissions with fileSecurity.
    @available(macOS 10.13, iOS 11.0, tvOS 11.0, watchOS 4.0, *)
    public var volumeSupportsAccessPermissions: Bool? { return _get(.volumeSupportsAccessPermissionsKey) }

    /// Returns the name of the file system type.
    @available( macOS 13.3, iOS 16.4, tvOS 16.4, watchOS 9.4, *)
    public var volumeTypeName: String? { return _get(.volumeTypeNameKey) }

    /// Returns the file system subtype.
    @available( macOS 13.3, iOS 16.4, tvOS 16.4, watchOS 9.4, *)
    public var volumeSubtype: Int? { return _get(.volumeSubtypeKey) }

    /// Returns the file system device location.
    @available( macOS 13.3, iOS 16.4, tvOS 16.4, watchOS 9.4, *)
    public var volumeMountFromLocation: String? { return _get(.volumeMountFromLocationKey) }

    /// True if this item is synced to the cloud, false if it is only a local file.
    public var isUbiquitousItem: Bool? { return _get(.isUbiquitousItemKey) }

    /// True if this item has conflicts outstanding.
    public var ubiquitousItemHasUnresolvedConflicts: Bool? { return _get(.ubiquitousItemHasUnresolvedConflictsKey) }

    /// True if data is being downloaded for this item.
    public var ubiquitousItemIsDownloading: Bool? { return _get(.ubiquitousItemIsDownloadingKey) }

    /// True if there is data present in the cloud for this item.
    public var ubiquitousItemIsUploaded: Bool? { return _get(.ubiquitousItemIsUploadedKey) }

    /// True if data is being uploaded for this item.
    public var ubiquitousItemIsUploading: Bool? { return _get(.ubiquitousItemIsUploadingKey) }

    /// Returns the download status of this item.
    public var ubiquitousItemDownloadingStatus: URLUbiquitousItemDownloadingStatus? { return _get(.ubiquitousItemDownloadingStatusKey) }

    /// Returns the error when downloading the item from iCloud failed, see the NSUbiquitousFile section in FoundationErrors.h
    public var ubiquitousItemDownloadingError: NSError? { return _get(.ubiquitousItemDownloadingErrorKey) }

    /// Returns the error when uploading the item to iCloud failed, see the NSUbiquitousFile section in FoundationErrors.h
    public var ubiquitousItemUploadingError: NSError? { return _get(.ubiquitousItemUploadingErrorKey) }

    /// Returns whether a download of this item has already been requested with an API like `startDownloadingUbiquitousItem(at:) throws`.
    @available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
    public var ubiquitousItemDownloadRequested: Bool? { return _get(.ubiquitousItemDownloadRequestedKey) }

    /// Returns the name of this item's container as displayed to users.
    @available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
    public var ubiquitousItemContainerDisplayName: String? { return _get(.ubiquitousItemContainerDisplayNameKey) }

    /// True if the item is excluded from sync, which means it is locally on disk but won't be available on the server. An excluded item is no longer ubiquitous.
    @available(macOS 11.3, iOS 14.5, watchOS 7.4, tvOS 14.5, *)
    public var ubiquitousItemIsExcludedFromSync: Bool? {
        get { return _get(.ubiquitousItemIsExcludedFromSyncKey) }
        set { _set(.ubiquitousItemIsExcludedFromSyncKey, newValue: newValue) }
    }

#if os(macOS) || os(iOS)
    /// True if ubiquitous item is shared.
    @available(macOS 10.13, iOS 11.0, *) @available(tvOS, unavailable) @available(watchOS, unavailable)
    public var ubiquitousItemIsShared: Bool? { return _get(.ubiquitousItemIsSharedKey) }

    /// The current user's role for this shared item, or nil if not shared.
    @available(macOS 10.13, iOS 11.0, *) @available(tvOS, unavailable) @available(watchOS, unavailable)
    public var ubiquitousSharedItemCurrentUserRole: URLUbiquitousSharedItemRole? { return _get(.ubiquitousSharedItemCurrentUserRoleKey) }

    /// The permissions for the current user, or nil if not shared.
    @available(macOS 10.13, iOS 11.0, *) @available(tvOS, unavailable) @available(watchOS, unavailable)
    public var ubiquitousSharedItemCurrentUserPermissions: URLUbiquitousSharedItemPermissions? { return _get(.ubiquitousSharedItemCurrentUserPermissionsKey) }

    /// The name components for the owner, or nil if not shared.
    @available(macOS 10.13, iOS 11.0, *) @available(tvOS, unavailable) @available(watchOS, unavailable)
    public var ubiquitousSharedItemOwnerNameComponents: PersonNameComponents? { return _get(.ubiquitousSharedItemOwnerNameComponentsKey) }

    /// The name components for the most recent editor, or nil if not shared.
    @available(macOS 10.13, iOS 11.0, *) @available(tvOS, unavailable) @available(watchOS, unavailable)
    public var ubiquitousSharedItemMostRecentEditorNameComponents: PersonNameComponents? { return _get(.ubiquitousSharedItemMostRecentEditorNameComponentsKey) }
#endif // os(macOS) || os(iOS)

    /// The protection level for this file
    @available(macOS 10.16, iOS 9.0, *)
    public var fileProtection: URLFileProtection? { return _get(.fileProtectionKey) }

    /// Total file size in bytes
    ///
    /// - note: Only applicable to regular files.
    public var fileSize: Int? { return _get(.fileSizeKey) }

    /// Total size allocated on disk for the file in bytes (number of blocks times block size)
    ///
    /// - note: Only applicable to regular files.
    public var fileAllocatedSize: Int? { return _get(.fileAllocatedSizeKey) }

    /// Total displayable size of the file in bytes (this may include space used by metadata), or nil if not available.
    ///
    /// - note: Only applicable to regular files.
    public var totalFileSize: Int? { return _get(.totalFileSizeKey) }

    /// Total allocated size of the file in bytes (this may include space used by metadata), or nil if not available. This can be less than the value returned by `totalFileSize` if the resource is compressed.
    ///
    /// - note: Only applicable to regular files.
    public var totalFileAllocatedSize: Int? { return _get(.totalFileAllocatedSizeKey) }

    /// true if the resource is a Finder alias file or a symlink, false otherwise
    ///
    /// - note: Only applicable to regular files.
    public var isAliasFile: Bool? { return _get(.isAliasFileKey) }

#endif // !NO_FILESYSTEM
}
#endif // FOUNDATION_FRAMEWORK

#if FOUNDATION_FRAMEWORK_NSURL
internal func foundation_swift_url_enabled() -> Bool {
    return _foundation_swift_url_feature_enabled()
}
#elseif FOUNDATION_FRAMEWORK
internal func foundation_swift_url_enabled() -> Bool { return true }
#endif

/// A URL is a type that can potentially contain the location of a resource on a remote server, the path of a local file on disk, or even an arbitrary piece of encoded data.
///
/// You can construct URLs and access their parts. For URLs that represent local files, you can also manipulate properties of those files directly, such as changing the file's last modification date. Finally, you can pass URLs to other APIs to retrieve the contents of those URLs. For example, you can use the URLSession classes to access the contents of remote resources, as described in URL Session Programming Guide.
///
/// URLs are the preferred way to refer to local files. Most objects that read data from or write data to a file have methods that accept a URL instead of a pathname as the file reference. For example, you can get the contents of a local file URL as `String` by calling `func init(contentsOf:encoding:) throws`, or as a `Data` by calling `func init(contentsOf:options:) throws`.
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
public struct URL: Equatable, Sendable, Hashable {

#if FOUNDATION_FRAMEWORK

    private var _url: NSURL

    private static func _nsURL(from parseInfo: URLParseInfo, baseParseInfo: URLParseInfo?) -> NSURL {
        var baseURL: CFURL?
        if let baseParseInfo {
            baseURL = _cfURL(from: baseParseInfo, baseURL: nil)
        }
        return _cfURL(from: parseInfo, baseURL: baseURL) as NSURL
    }

    struct _CFURLFlags: OptionSet {
        let rawValue: UInt32

        // These must match the CFURL flags defined in CFURL.m
        static let hasScheme            = _CFURLFlags(rawValue: 0x00000001)
        static let hasUser              = _CFURLFlags(rawValue: 0x00000002)
        static let hasPassword          = _CFURLFlags(rawValue: 0x00000004)
        static let hasHost              = _CFURLFlags(rawValue: 0x00000008)
        static let hasPort              = _CFURLFlags(rawValue: 0x00000010)
        static let hasPath              = _CFURLFlags(rawValue: 0x00000020)
        static let hasParameters        = _CFURLFlags(rawValue: 0x00000040) // Unused
        static let hasQuery             = _CFURLFlags(rawValue: 0x00000080)
        static let hasFragment          = _CFURLFlags(rawValue: 0x00000100)
        static let isIPLiteral          = _CFURLFlags(rawValue: 0x00000400)
        static let isDirectory          = _CFURLFlags(rawValue: 0x00000800)
        static let isCanonicalFileURL   = _CFURLFlags(rawValue: 0x00001000) // Unused
        static let pathHasFileID        = _CFURLFlags(rawValue: 0x00002000)
        static let isDecomposable       = _CFURLFlags(rawValue: 0x00004000)
        static let posixAndURLPathsMatch        = _CFURLFlags(rawValue: 0x00008000)
        static let originalAndURLStringsMatch   = _CFURLFlags(rawValue: 0x00010000)
    }

    private static func _cfURL(from parseInfo: URLParseInfo, baseURL: CFURL?) -> CFURL {
        let string = parseInfo.urlString
        var ranges = [CFRange]()
        var flags: _CFURLFlags = [
            .isDecomposable,
            .originalAndURLStringsMatch,
        ]

        if let schemeRange = parseInfo.schemeRange {
            flags.insert(.hasScheme)
            let nsRange = string._toRelativeNSRange(schemeRange)
            ranges.append(CFRange(location: nsRange.location, length: nsRange.length))
        }

        if let userRange = parseInfo.userRange {
            flags.insert(.hasUser)
            let nsRange = string._toRelativeNSRange(userRange)
            ranges.append(CFRange(location: nsRange.location, length: nsRange.length))
        }

        if let passwordRange = parseInfo.passwordRange {
            flags.insert(.hasPassword)
            let nsRange = string._toRelativeNSRange(passwordRange)
            ranges.append(CFRange(location: nsRange.location, length: nsRange.length))
        }

        if parseInfo.portRange != nil {
            flags.insert(.hasPort)
        }

        // CFURL considers an empty host nil unless there's another authority component
        if let hostRange = parseInfo.hostRange,
           (!hostRange.isEmpty || !flags.isDisjoint(with: [.hasUser, .hasPassword, .hasPort])) {
            flags.insert(.hasHost)
            let nsRange = string._toRelativeNSRange(hostRange)
            ranges.append(CFRange(location: nsRange.location, length: nsRange.length))
        }

        if let portRange = parseInfo.portRange {
            let nsRange = string._toRelativeNSRange(portRange)
            ranges.append(CFRange(location: nsRange.location, length: nsRange.length))
        }

        flags.insert(.hasPath)
        if let pathRange = parseInfo.pathRange {
            let nsRange = string._toRelativeNSRange(pathRange)
            ranges.append(CFRange(location: nsRange.location, length: nsRange.length))
        } else {
            ranges.append(CFRange(location: kCFNotFound, length: 0))
        }

        if let queryRange = parseInfo.queryRange {
            flags.insert(.hasQuery)
            let nsRange = string._toRelativeNSRange(queryRange)
            ranges.append(CFRange(location: nsRange.location, length: nsRange.length))
        }

        if let fragmentRange = parseInfo.fragmentRange {
            flags.insert(.hasFragment)
            let nsRange = string._toRelativeNSRange(fragmentRange)
            ranges.append(CFRange(location: nsRange.location, length: nsRange.length))
        }

        let path = parseInfo.path.utf8
        let isDirectory = path.last == UInt8(ascii: "/")

        if parseInfo.isIPLiteral {
            flags.insert(.isIPLiteral)
        }
        if isDirectory {
            flags.insert(.isDirectory)
        }

        let fileIDPrefix = [UInt8(ascii: "/"), UInt8(ascii: "."), UInt8(ascii: "f"), UInt8(ascii: "i"), UInt8(ascii: "l"), UInt8(ascii: "e"), UInt8(ascii: "/"), UInt8(ascii: "i"), UInt8(ascii: "d"), UInt8(ascii: "=")]

        if path.starts(with: fileIDPrefix) {
            flags.insert(.pathHasFileID)
        }
        if !isDirectory && !parseInfo.pathHasPercent {
            flags.insert(.posixAndURLPathsMatch)
        }

        return ranges.withUnsafeBufferPointer {
            _CFURLCreateWithRangesAndFlags(string as CFString, $0.baseAddress!, UInt8($0.count), flags.rawValue, baseURL)
        }
    }

#if !NO_FILESYSTEM
    public typealias BookmarkResolutionOptions = NSURL.BookmarkResolutionOptions
    public typealias BookmarkCreationOptions = NSURL.BookmarkCreationOptions
#endif // !NO_FILESYSTEM

#endif // FOUNDATION_FRAMEWORK

    typealias Parser = RFC3986Parser
    internal var _parseInfo: URLParseInfo!
    private var _baseParseInfo: URLParseInfo?

    internal init(parseInfo: URLParseInfo, relativeTo url: URL? = nil) {
        _parseInfo = parseInfo
        if parseInfo.scheme == nil {
            _baseParseInfo = url?.absoluteURL._parseInfo
        }
        #if FOUNDATION_FRAMEWORK
        _url = URL._nsURL(from: _parseInfo, baseParseInfo: _baseParseInfo)
        #endif // FOUNDATION_FRAMEWORK
    }

    /// Initialize with string.
    ///
    /// Returns `nil` if a `URL` cannot be formed with the string (for example, if the string contains characters that are illegal in a URL, or is an empty string).
    public init?(string: __shared String) {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            guard !string.isEmpty, let inner = NSURL(string: string) else { return nil }
            _url = URL._converted(from: inner)
            return
        }
        #endif // FOUNDATION_FRAMEWORK
        guard let parseInfo = Parser.parse(urlString: string, encodingInvalidCharacters: true) else {
            return nil
        }
        _parseInfo = parseInfo
        #if FOUNDATION_FRAMEWORK
        _url = URL._nsURL(from: _parseInfo, baseParseInfo: _baseParseInfo)
        #endif // FOUNDATION_FRAMEWORK
    }

    /// Initialize with string, relative to another URL.
    ///
    /// Returns `nil` if a `URL` cannot be formed with the string (for example, if the string contains characters that are illegal in a URL, or is an empty string).
    public init?(string: __shared String, relativeTo url: __shared URL?) {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            guard !string.isEmpty, let inner = NSURL(string: string, relativeTo: url) else { return nil }
            _url = URL._converted(from: inner)
            return
        }
        #endif // FOUNDATION_FRAMEWORK
        guard let parseInfo = Parser.parse(urlString: string, encodingInvalidCharacters: true) else {
            return nil
        }
        _parseInfo = parseInfo
        if parseInfo.scheme == nil {
            _baseParseInfo = url?.absoluteURL._parseInfo
        }
        #if FOUNDATION_FRAMEWORK
        _url = URL._nsURL(from: _parseInfo, baseParseInfo: _baseParseInfo)
        #endif // FOUNDATION_FRAMEWORK
    }

    /// Initialize with a URL string and the option to add (or skip) IDNA- and percent-encoding of invalid characters.
    ///
    /// If `encodingInvalidCharacters` is false, and the URL string is invalid according to RFC 3986, `nil` is returned.
    /// If `encodingInvalidCharacters` is true, `URL` will try to encode the string to create a valid URL.
    /// If the URL string is still invalid after encoding, `nil` is returned.
    @available(macOS 14.0, iOS 17.0, watchOS 10.0, tvOS 17.0, *)
    public init?(string: __shared String, encodingInvalidCharacters: Bool) {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            guard !string.isEmpty, let inner = NSURL(string: string, encodingInvalidCharacters: encodingInvalidCharacters) else { return nil }
            _url = URL._converted(from: inner)
            return
        }
        #endif // FOUNDATION_FRAMEWORK
        guard let parseInfo = Parser.parse(urlString: string, encodingInvalidCharacters: encodingInvalidCharacters) else {
            return nil
        }
        _parseInfo = parseInfo
        #if FOUNDATION_FRAMEWORK
        _url = URL._nsURL(from: _parseInfo, baseParseInfo: _baseParseInfo)
        #endif // FOUNDATION_FRAMEWORK
    }

    /// Initializes a newly created file URL referencing the local file or directory at path, relative to a base URL.
    ///
    /// If an empty string is used for the path, then the path is assumed to be ".".
    /// - note: This function avoids an extra file system access to check if the file URL is a directory. You should use it if you know the answer already.
    @available(macOS, introduced: 10.10, deprecated: 100000.0, message: "Use init(filePath:directoryHint:relativeTo:) instead")
    @available(iOS, introduced: 8.0, deprecated: 100000.0, message: "Use init(filePath:directoryHint:relativeTo:) instead")
    @available(tvOS, introduced: 9.0, deprecated: 100000.0, message: "Use init(filePath:directoryHint:relativeTo:) instead")
    @available(watchOS, introduced: 2.0, deprecated: 100000.0, message: "Use init(filePath:directoryHint:relativeTo:) instead")
    @available(visionOS, introduced: 1.0, deprecated: 100000.0, message: "Use init(filePath:directoryHint:relativeTo:) instead")
    public init(fileURLWithPath path: __shared String, isDirectory: Bool, relativeTo base: __shared URL?) {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            let url = URL._converted(from: NSURL(fileURLWithPath: path.isEmpty ? "." : path, isDirectory: isDirectory, relativeTo: base))
            self.init(convertedReference: url)
            return
        }
        #endif
        let directoryHint: DirectoryHint = isDirectory ? .isDirectory : .notDirectory
        self.init(filePath: path, directoryHint: directoryHint, relativeTo: base)
    }

    /// Initializes a newly created file URL referencing the local file or directory at path, relative to a base URL.
    ///
    /// If an empty string is used for the path, then the path is assumed to be ".".
    @available(macOS, introduced: 10.10, deprecated: 100000.0, message: "Use init(filePath:directoryHint:relativeTo:) instead")
    @available(iOS, introduced: 8.0, deprecated: 100000.0, message: "Use init(filePath:directoryHint:relativeTo:) instead")
    @available(tvOS, introduced: 9.0, deprecated: 100000.0, message: "Use init(filePath:directoryHint:relativeTo:) instead")
    @available(watchOS, introduced: 2.0, deprecated: 100000.0, message: "Use init(filePath:directoryHint:relativeTo:) instead")
    @available(visionOS, introduced: 1.0, deprecated: 100000.0, message: "Use init(filePath:directoryHint:relativeTo:) instead")
    public init(fileURLWithPath path: __shared String, relativeTo base: __shared URL?) {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            let url = URL._converted(from: NSURL(fileURLWithPath: path.isEmpty ? "." : path, relativeTo: base))
            self.init(convertedReference: url)
            return
        }
        #endif
        self.init(filePath: path, directoryHint: .checkFileSystem, relativeTo: base)
    }

    /// Initializes a newly created file URL referencing the local file or directory at path.
    ///
    /// If an empty string is used for the path, then the path is assumed to be ".".
    /// - note: This function avoids an extra file system access to check if the file URL is a directory. You should use it if you know the answer already.
    @available(macOS, introduced: 10.10, deprecated: 100000.0, message: "Use init(filePath:directoryHint:relativeTo:) instead")
    @available(iOS, introduced: 8.0, deprecated: 100000.0, message: "Use init(filePath:directoryHint:relativeTo:) instead")
    @available(tvOS, introduced: 9.0, deprecated: 100000.0, message: "Use init(filePath:directoryHint:relativeTo:) instead")
    @available(watchOS, introduced: 2.0, deprecated: 100000.0, message: "Use init(filePath:directoryHint:relativeTo:) instead")
    @available(visionOS, introduced: 1.0, deprecated: 100000.0, message: "Use init(filePath:directoryHint:relativeTo:) instead")
    public init(fileURLWithPath path: __shared String, isDirectory: Bool) {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            let url = URL._converted(from: NSURL(fileURLWithPath: path.isEmpty ? "." : path, isDirectory: isDirectory))
            self.init(convertedReference: url)
            return
        }
        #endif
        let directoryHint: DirectoryHint = isDirectory ? .isDirectory : .notDirectory
        self.init(filePath: path, directoryHint: directoryHint)
    }

    /// Initializes a newly created file URL referencing the local file or directory at path.
    ///
    /// If an empty string is used for the path, then the path is assumed to be ".".
    @available(macOS, introduced: 10.10, deprecated: 100000.0, message: "Use init(filePath:directoryHint:relativeTo:) instead")
    @available(iOS, introduced: 8.0, deprecated: 100000.0, message: "Use init(filePath:directoryHint:relativeTo:) instead")
    @available(tvOS, introduced: 9.0, deprecated: 100000.0, message: "Use init(filePath:directoryHint:relativeTo:) instead")
    @available(watchOS, introduced: 2.0, deprecated: 100000.0, message: "Use init(filePath:directoryHint:relativeTo:) instead")
    @available(visionOS, introduced: 1.0, deprecated: 100000.0, message: "Use init(filePath:directoryHint:relativeTo:) instead")
    public init(fileURLWithPath path: __shared String) {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            let url = URL._converted(from: NSURL(fileURLWithPath: path.isEmpty ? "." : path))
            self.init(convertedReference: url)
            return
        }
        #endif
        self.init(filePath: path, directoryHint: .checkFileSystem)
    }
    
    // NSURL(fileURLWithPath:) can return nil incorrectly for some malformed paths
    // This is only to be used by FileManager when dealing with potentially malformed paths, and only when truly necessary
    internal init?(_fileManagerFailableFileURLWithPath path: __shared String) {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            let url = URL._converted(from: NSURL(fileURLWithPath: path.isEmpty ? "." : path, isDirectory: path.utf8.last == ._slash))
            guard unsafeBitCast(url, to: UnsafeRawPointer?.self) != nil else {
                return nil
            }
            self.init(convertedReference: url)
            return
        }
        #endif
        // Infer from the path to prevent a file system check for what is likely a non-existant, malformed, or inaccessible path
        self.init(filePath: path, directoryHint: .inferFromPath)
    }

    /// Initializes a newly created URL using the contents of the given data, relative to a base URL.
    ///
    /// If the data representation is not a legal URL string as ASCII bytes, the URL object may not behave as expected. If the URL cannot be formed then this will return nil.
    @available(macOS 10.11, iOS 9.0, watchOS 2.0, tvOS 9.0, *)
    public init?(dataRepresentation: __shared Data, relativeTo url: __shared URL?, isAbsolute: Bool = false) {
        guard !dataRepresentation.isEmpty else { return nil }
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            if isAbsolute {
                _url = URL._converted(from: NSURL(absoluteURLWithDataRepresentation: dataRepresentation, relativeTo: url))
            } else {
                _url = URL._converted(from: NSURL(dataRepresentation: dataRepresentation, relativeTo: url))
            }
            return
        }
        #endif
        var url: URL?
        if let string = String(data: dataRepresentation, encoding: .utf8) {
            url = URL(string: string, relativeTo: url)
        }
        if url == nil, let string = String(data: dataRepresentation, encoding: .isoLatin1) {
            url = URL(string: string, relativeTo: url)
        }
        guard let url else {
            return nil
        }
        if isAbsolute {
            self = url.absoluteURL
        } else {
            self = url
        }
    }

#if !NO_FILESYSTEM && FOUNDATION_FRAMEWORK

    /// Initializes a URL that refers to a location specified by resolving bookmark data.
    @available(swift, obsoleted: 4.2)
    public init?(resolvingBookmarkData data: __shared Data, options: BookmarkResolutionOptions = [], relativeTo url: __shared URL? = nil, bookmarkDataIsStale: inout Bool) throws {
        var stale: ObjCBool = false
        _url = URL._converted(from: try NSURL(resolvingBookmarkData: data, options: options, relativeTo: url, bookmarkDataIsStale: &stale))
        bookmarkDataIsStale = stale.boolValue
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            return
        }
        #endif
        guard let parseInfo = Parser.parse(urlString: _url.relativeString, encodingInvalidCharacters: true) else {
            return nil
        }
        _parseInfo = parseInfo
        if parseInfo.scheme == nil {
            _baseParseInfo = url?.absoluteURL._parseInfo
        }
    }

    /// Initializes a URL that refers to a location specified by resolving bookmark data.
    @available(swift, introduced: 4.2)
    public init(resolvingBookmarkData data: __shared Data, options: BookmarkResolutionOptions = [], relativeTo url: __shared URL? = nil, bookmarkDataIsStale: inout Bool) throws {
        var stale: ObjCBool = false
        _url = URL._converted(from: try NSURL(resolvingBookmarkData: data, options: options, relativeTo: url, bookmarkDataIsStale: &stale))
        bookmarkDataIsStale = stale.boolValue
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            return
        }
        #endif
        bookmarkDataIsStale = stale.boolValue
        let parseInfo = Parser.parse(urlString: _url.relativeString, encodingInvalidCharacters: true)!
        _parseInfo = parseInfo
        if parseInfo.scheme == nil {
            _baseParseInfo = url?.absoluteURL._parseInfo
        }
    }

    /// Creates and initializes a URL that refers to the location specified by resolving the alias file at `url`. If the `url` argument does not refer to an alias file as defined by the `.isAliasFileKey` property, the URL returned is the same as the `url` argument. This method fails and returns `nil` if the `url` argument is unreachable, or if the original file or directory could not be located or is not reachable, or if the original file or directory is on a volume that could not be located or mounted. The `URLBookmarkResolutionWithSecurityScope` option is not supported by this method.
    @available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
    public init(resolvingAliasFileAt url: __shared URL, options: BookmarkResolutionOptions = []) throws {
        self.init(reference: try NSURL(resolvingAliasFileAt: url, options: options))
    }

#endif // !NO_FILESYSTEM && FOUNDATION_FRAMEWORK

    /// Initializes a newly created URL referencing the local file or directory at the file system representation of the path. File system representation is a null-terminated C string with canonical UTF-8 encoding.
    public init(fileURLWithFileSystemRepresentation path: UnsafePointer<Int8>, isDirectory: Bool, relativeTo baseURL: __shared URL?) {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            let url = URL._converted(from: NSURL(fileURLWithFileSystemRepresentation: path, isDirectory: isDirectory, relativeTo: baseURL))
            self.init(convertedReference: url)
            return
        }
        #endif
        let pathString = String(cString: path)
        let directoryHint: DirectoryHint = isDirectory ? .isDirectory : .notDirectory
        self.init(filePath: pathString, directoryHint: directoryHint, relativeTo: baseURL)
    }

    /// Returns the data representation of the URL's relativeString.
    ///
    /// If the URL was initialized with `init?(dataRepresentation:relativeTo:isAbsolute:)`, the data representation returned are the same bytes as those used at initialization; otherwise, the data representation returned are the bytes of the `relativeString` encoded with UTF8 string encoding.
    @available(macOS 10.11, iOS 9.0, watchOS 2.0, tvOS 9.0, *)
    public var dataRepresentation: Data {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            return _url.dataRepresentation
        }
        #endif
        return Data(_parseInfo.urlString.utf8)
    }

    private func mergedPath(for relativePath: String) -> String {
        precondition(relativePath.utf8.first != UInt8(ascii: "/"))
        guard let _baseParseInfo else {
            return relativePath
        }
        let basePath = String(_baseParseInfo.path)
        if _baseParseInfo.hasAuthority && basePath.isEmpty {
            return "/" + relativePath
        }
        return basePath.merging(relativePath: relativePath)
    }

    /// Calculate the "merged" path that is resovled against the base URL
    private var mergedPath: String {
        return mergedPath(for: relativePath())
    }

    /// Returns the absolute string for the URL.
    public var absoluteString: String {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            // This should never fail for non-file reference URLs
            return _url.absoluteString ?? ""
        }
        #endif
        guard let _baseParseInfo else {
            return relativeString
        }
        var result = URLComponents(parseInfo: _parseInfo)

        if _parseInfo.scheme != nil {
            result.percentEncodedPath = relativePath().removingDotSegments
            return result.string ?? relativeString
        }

        if let baseScheme = _baseParseInfo.scheme {
            result.scheme = String(baseScheme)
        }

        if hasAuthority {
            return result.string ?? relativeString
        }

        if let baseUser = _baseParseInfo.user {
            result.percentEncodedUser = String(baseUser)
        }
        if let basePassword = _baseParseInfo.password {
            result.percentEncodedPassword = String(basePassword)
        }
        if let baseHost = _baseParseInfo.host {
            result.encodedHost = String(baseHost)
        }
        if let basePort = _baseParseInfo.port {
            result.port = basePort
        }

        if relativePath().isEmpty {
            result.percentEncodedPath = String(_baseParseInfo.path)
            if _parseInfo.query == nil, let baseQuery = _baseParseInfo.query {
                result.percentEncodedQuery = String(baseQuery)
            }
        } else {
            if relativePath().utf8.first == UInt8(ascii: "/") {
                result.percentEncodedPath = relativePath().removingDotSegments
            } else {
                result.percentEncodedPath = mergedPath.removingDotSegments
            }
        }
        return result.string ?? relativeString
    }

    /// Returns the relative portion of a URL.
    ///
    /// If `baseURL` is nil, or if the receiver is itself absolute, this is the same as `absoluteString`.
    public var relativeString: String {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            return _url.relativeString
        }
        #endif
        return _parseInfo.urlString
    }

    /// Returns the base URL.
    ///
    /// If the URL is itself absolute, then this value is nil.
    public var baseURL: URL? {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            return _url.baseURL
        }
        #endif
        guard let _baseParseInfo else {
            return nil
        }
        return URL(parseInfo: _baseParseInfo)
    }

    /// Returns the absolute URL.
    ///
    /// If the URL is itself absolute, this will return self.
    public var absoluteURL: URL {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            // This should never fail for non-file reference URLs
            return _url.absoluteURL ?? self
        }
        #endif
        guard _baseParseInfo != nil else {
            return self
        }
        return URL(string: absoluteString) ?? self
    }

    /// Returns the scheme of the URL.
    public var scheme: String? {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            return _url.scheme
        }
        #endif
        guard let scheme = _parseInfo.scheme ?? _baseParseInfo?.scheme else { return nil }
        return String(scheme)
    }

    /// Returns true if the scheme is `file:`.
    public var isFileURL: Bool {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            return _url.isFileURL
        }
        #endif
        guard let scheme else { return false }
        return scheme.lowercased() == "file"
    }

    private var hasAuthority: Bool {
        return _parseInfo.hasAuthority
    }

    private var encodedHost: String? {
        let encodedHost = hasAuthority ? _parseInfo.host : _baseParseInfo?.host
        guard let encodedHost else { return nil }
        return String(encodedHost)
    }

    /// Returns the host component of the URL if present, otherwise returns `nil`.
    ///
    /// - note: This function will resolve against the base `URL`.
    @available(macOS, introduced: 10.10, deprecated: 100000.0, message: "Use host(percentEncoded:) instead")
    @available(iOS, introduced: 8.0, deprecated: 100000.0, message: "Use host(percentEncoded:) instead")
    @available(tvOS, introduced: 9.0, deprecated: 100000.0, message: "Use host(percentEncoded:) instead")
    @available(watchOS, introduced: 2.0, deprecated: 100000.0, message: "Use host(percentEncoded:) instead")
    @available(visionOS, introduced: 1.0, deprecated: 100000.0, message: "Use host(percentEncoded:) instead")
    public var host: String? {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            return _url.host
        }
        #endif
        return host()
    }

    /// Returns the host component of the URL if present, otherwise returns `nil`.
    ///
    /// - Parameter percentEncoded: Whether the host should be percent encoded,
    ///   defaults to `true`.
    /// - Returns: The host component of the URL
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public func host(percentEncoded: Bool = true) -> String? {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            let cf = _url._cfurl().takeUnretainedValue()
            if let host = _CFURLCopyHostName(cf, !percentEncoded) {
                return host.takeRetainedValue() as String
            }
            return nil
        }
        #endif
        guard let encodedHost else { return nil }
        let didPercentEncodeHost = hasAuthority ? _parseInfo.didPercentEncodeHost : _baseParseInfo?.didPercentEncodeHost ?? false
        if percentEncoded {
            if didPercentEncodeHost {
                return String(encodedHost)
            }
            guard let decoded = Parser.IDNADecodeHost(encodedHost) else {
                return encodedHost
            }
            return Parser.percentEncode(decoded, component: .host)
        } else {
            if didPercentEncodeHost {
                return Parser.percentDecode(encodedHost)
            }
            return String(encodedHost)
        }
    }

    /// Returns the port component of the URL if present, otherwise returns `nil`.
    ///
    /// - note: This function will resolve against the base `URL`.
    public var port: Int? {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            return _url.port?.intValue
        }
        #endif
        return hasAuthority ? _parseInfo.port : _baseParseInfo?.port
    }

    /// Returns the user component of the URL if present, otherwise returns `nil`.
    ///
    /// - note: This function will resolve against the base `URL`.
    @available(macOS, introduced: 10.10, deprecated: 100000.0, message: "Use user(percentEncoded:) instead")
    @available(iOS, introduced: 8.0, deprecated: 100000.0, message: "Use user(percentEncoded:) instead")
    @available(tvOS, introduced: 9.0, deprecated: 100000.0, message: "Use user(percentEncoded:) instead")
    @available(watchOS, introduced: 2.0, deprecated: 100000.0, message: "Use user(percentEncoded:) instead")
    @available(visionOS, introduced: 1.0, deprecated: 100000.0, message: "Use user(percentEncoded:) instead")
    public var user: String? {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            return _url.user
        }
        #endif
        return user()
    }

    /// Returns the user component of the URL if present, otherwise returns `nil`.
    /// - Parameter percentEncoded: Whether the user should be percent encoded,
    ///   defaults to `true`.
    /// - Returns: The user component of the URL.
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public func user(percentEncoded: Bool = true) -> String? {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            let cf = _url._cfurl().takeUnretainedValue()
            if let username = _CFURLCopyUserName(cf, !percentEncoded) {
                return username.takeRetainedValue() as String
            }
            return nil
        }
        #endif
        let user = hasAuthority ? _parseInfo.user : _baseParseInfo?.user
        guard let user else { return nil }
        if percentEncoded {
            return String(user)
        } else {
            return Parser.percentDecode(user)
        }
    }

    /// Returns the password component of the URL if present, otherwise returns `nil`.
    ///
    /// - note: This function will resolve against the base `URL`.
    @available(macOS, introduced: 10.10, deprecated: 100000.0, message: "Use password(percentEncoded:) instead")
    @available(iOS, introduced: 8.0, deprecated: 100000.0, message: "Use password(percentEncoded:) instead")
    @available(tvOS, introduced: 9.0, deprecated: 100000.0, message: "Use password(percentEncoded:) instead")
    @available(watchOS, introduced: 2.0, deprecated: 100000.0, message: "Use password(percentEncoded:) instead")
    @available(visionOS, introduced: 1.0, deprecated: 100000.0, message: "Use password(percentEncoded:) instead")
    public var password: String? {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            return _url.password
        }
        #endif
        return password()
    }

    /// Returns the password component of the URL if present, otherwise returns `nil`.
    /// - Parameter percentEncoded: Whether the password should be percent encoded,
    ///   defaults to `true`.
    /// - Returns: The password component of the URL.
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public func password(percentEncoded: Bool = true) -> String? {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            let cf = _url._cfurl().takeUnretainedValue()
            if let password = _CFURLCopyPassword(cf, !percentEncoded) {
                return password.takeRetainedValue() as String
            }
            return nil
        }
        #endif
        let password = hasAuthority ? _parseInfo.password : _baseParseInfo?.password
        guard let password else { return nil }
        if percentEncoded {
            return String(password)
        } else {
            return Parser.percentDecode(password)
        }
    }

    private static func fileSystemPath(for urlPath: String) -> String {
        var result = urlPath
        if result.count > 1 && result.utf8.last == UInt8(ascii: "/") {
            _ = result.popLast()
        }
        let charsToLeaveEncoded: Set<UInt8> = [._slash, 0]
        return Parser.percentDecode(result, excluding: charsToLeaveEncoded) ?? ""
    }

    var fileSystemPath: String {
        return URL.fileSystemPath(for: path())
    }

    /// Returns the path component of the URL if present, otherwise returns an empty string.
    ///
    /// - note: This function will resolve against the base `URL`.
    /// - returns: The path, or an empty string if the URL has an empty path.
    @available(macOS, introduced: 10.10, deprecated: 100000.0, message: "Use path(percentEncoded:) instead")
    @available(iOS, introduced: 8.0, deprecated: 100000.0, message: "Use path(percentEncoded:) instead")
    @available(tvOS, introduced: 9.0, deprecated: 100000.0, message: "Use path(percentEncoded:) instead")
    @available(watchOS, introduced: 2.0, deprecated: 100000.0, message: "Use path(percentEncoded:) instead")
    @available(visionOS, introduced: 1.0, deprecated: 100000.0, message: "Use path(percentEncoded:) instead")
    public var path: String {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            if let parameterString = _url._parameterString {
                if __NSURLSupportDeprecatedParameterComponent(),
                   let path = _url.path {
                    return path + ";" + parameterString
                } else {
                    return ";" + parameterString
                }
            } else if let path = _url.path {
                return path
            } else {
                return ""
            }
        }
        #endif
        return fileSystemPath
    }

    /// Returns the path component of the URL if present, otherwise returns an empty string.
    /// - note: This function will resolve against the base `URL`.
    /// - Parameter percentEncoded: Whether the path should be percent encoded,
    ///   defaults to `true`.
    /// - Returns: The path component of the URL.
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public func path(percentEncoded: Bool = true) -> String {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            let cf = _url._cfurl().takeUnretainedValue()
            if let path = _CFURLCopyPath(cf, !percentEncoded) {
                return path.takeRetainedValue() as String
            }
            return ""
        }
        #endif
        if _baseParseInfo != nil {
            return absoluteURL.path(percentEncoded: percentEncoded)
        }
        if percentEncoded {
            return String(_parseInfo.path)
        } else {
            return Parser.percentDecode(_parseInfo.path) ?? ""
        }
    }

    /// Returns the relative path of the URL if present, otherwise returns an empty string. This is the same as `path` if `baseURL` is `nil`.
    ///
    /// - returns: The relative path, or an empty string if the URL has an empty path.
    public var relativePath: String {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            if __NSURLSupportDeprecatedParameterComponent(),
               let parameterString = _url._parameterString {
                if let path = _url.relativePath {
                    return path + ";" + parameterString
                } else {
                    return ";" + parameterString
                }
            } else if let path = _url.relativePath {
                return path
            } else {
                return ""
            }
        }
        #endif
        return URL.fileSystemPath(for: relativePath())
    }

    private func relativePath(percentEncoded: Bool = true) -> String {
        if percentEncoded {
            return String(_parseInfo.path)
        } else {
            return Parser.percentDecode(_parseInfo.path) ?? ""
        }
    }

    /// Returns the query component of the URL if present, otherwise returns `nil`.
    ///
    /// - note: This function will resolve against the base `URL`.
    @available(macOS, introduced: 10.10, deprecated: 100000.0, message: "Use query(percentEncoded:) instead")
    @available(iOS, introduced: 8.0, deprecated: 100000.0, message: "Use query(percentEncoded:) instead")
    @available(tvOS, introduced: 9.0, deprecated: 100000.0, message: "Use query(percentEncoded:) instead")
    @available(watchOS, introduced: 2.0, deprecated: 100000.0, message: "Use query(percentEncoded:) instead")
    @available(visionOS, introduced: 1.0, deprecated: 100000.0, message: "Use query(percentEncoded:) instead")
    public var query: String? {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            return _url.query
        }
        #endif
        return query()
    }

    /// Returns the password component of the URL if present, otherwise returns `nil`.
    /// - Parameter percentEncoded: Whether the query should be percent encoded,
    ///   defaults to `true`.
    /// - Returns: The query component of the URL.
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public func query(percentEncoded: Bool = true) -> String? {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            let cf = _url._cfurl().takeUnretainedValue()
            if let queryString = _CFURLCopyQueryString(cf, !percentEncoded) {
                return queryString.takeRetainedValue() as String
            }
            return nil
        }
        #endif
        var query = _parseInfo.query
        if query == nil && relativePath().isEmpty {
            query = _baseParseInfo?.query
        }
        guard let query else { return nil }
        if percentEncoded {
            return String(query)
        } else {
            return Parser.percentDecode(query)
        }
    }

    /// Returns the fragment component of the URL if present, otherwise returns `nil`.
    ///
    /// - note: This function will resolve against the base `URL`.
    @available(macOS, introduced: 10.10, deprecated: 100000.0, message: "Use fragment(percentEncoded:) instead")
    @available(iOS, introduced: 8.0, deprecated: 100000.0, message: "Use fragment(percentEncoded:) instead")
    @available(tvOS, introduced: 9.0, deprecated: 100000.0, message: "Use fragment(percentEncoded:) instead")
    @available(watchOS, introduced: 2.0, deprecated: 100000.0, message: "Use fragment(percentEncoded:) instead")
    @available(visionOS, introduced: 1.0, deprecated: 100000.0, message: "Use fragment(percentEncoded:) instead")
    public var fragment: String? {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            return _url.fragment
        }
        #endif
        return fragment()
    }

    /// Returns the password component of the URL if present, otherwise returns `nil`.
    /// - Parameter percentEncoded: Whether the fragment should be percent encoded,
    ///   defaults to `true`.
    /// - Returns: The fragment component of the URL.
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public func fragment(percentEncoded: Bool = true) -> String? {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            let cf = _url._cfurl().takeUnretainedValue()
            if let fragment = _CFURLCopyFragment(cf, !percentEncoded) {
                return fragment.takeRetainedValue() as String
            }
            return nil
        }
        #endif
        guard let fragment = _parseInfo.fragment else { return nil }
        if percentEncoded {
            return String(fragment)
        } else {
            return Parser.percentDecode(fragment)
        }
    }

    /// Passes the URL's path in file system representation to `block`.
    ///
    /// File system representation is a null-terminated C string with canonical UTF-8 encoding.
    /// - note: The pointer is not valid outside the context of the block.
    @available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
    public func withUnsafeFileSystemRepresentation<ResultType>(_ block: (UnsafePointer<Int8>?) throws -> ResultType) rethrows -> ResultType {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            return try block(_url.fileSystemRepresentation)
        }
        #endif
        return try fileSystemPath.withFileSystemRepresentation { try block($0) }
    }

    // MARK: - Path manipulation
    /// Returns true if the URL path represents a directory.
    @available(macOS 10.11, iOS 9.0, watchOS 2.0, tvOS 9.0, *)
    public var hasDirectoryPath: Bool {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            return _url.hasDirectoryPath
        }
        #endif
        return path().utf8.last == UInt8(ascii: "/")
    }

    /// Returns the path components of the URL, or an empty array if the path is an empty string.
    public var pathComponents: [String] {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            // In accordance with our change to never return a nil path, here we return an empty array.
            return _url.pathComponents ?? []
        }
        #endif
        var result = path().pathComponents.map { Parser.percentDecode($0) ?? "" }
        if result.count > 1 && result.last == "/" {
            _ = result.popLast()
        }
        return result
    }

    /// Returns the last path component of the URL, or an empty string if the path is an empty string.
    public var lastPathComponent: String {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            return _url.lastPathComponent ?? ""
        }
        #endif
        return fileSystemPath.lastPathComponent
    }

    /// Returns the path extension of the URL, or an empty string if the path is an empty string.
    public var pathExtension: String {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            return _url.pathExtension ?? ""
        }
        #endif
        return fileSystemPath.pathExtension
    }

    /// Returns a URL constructed by appending the given path component to self.
    ///
    /// - parameter pathComponent: The path component to add.
    /// - parameter isDirectory: If `true`, then a trailing `/` is added to the resulting path.
    @available(macOS, introduced: 10.10, deprecated: 100000.0, message: "Use appending(path:directoryHint:) instead")
    @available(iOS, introduced: 8.0, deprecated: 100000.0, message: "Use appending(path:directoryHint:) instead")
    @available(tvOS, introduced: 9.0, deprecated: 100000.0, message: "Use appending(path:directoryHint:) instead")
    @available(watchOS, introduced: 2.0, deprecated: 100000.0, message: "Use appending(path:directoryHint:) instead")
    @available(visionOS, introduced: 1.0, deprecated: 100000.0, message: "Use appending(path:directoryHint:) instead")
    public func appendingPathComponent(_ pathComponent: String, isDirectory: Bool) -> URL {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            if let result = _url.appendingPathComponent(pathComponent, isDirectory: isDirectory) {
                return result
            }
            // Now we need to do something more expensive
            if var c = URLComponents(url: self, resolvingAgainstBaseURL: true) {
                let path = (c.path as NSString).appendingPathComponent(pathComponent)
                c.path = isDirectory ? path + "/" : path
                return c.url ?? self
            } else {
                // Ultimate fallback:
                return self
            }
        }
        #endif
        let directoryHint: DirectoryHint = isDirectory ? .isDirectory : .notDirectory
        return appending(path: pathComponent, directoryHint: directoryHint)
    }

    /// Returns a URL constructed by appending the given path component to self.
    ///
    /// - note: This function performs a file system operation to determine if the path component is a directory. If so, it will append a trailing `/`. If you know in advance that the path component is a directory or not, then use `func appendingPathComponent(_:isDirectory:)`.
    /// - parameter pathComponent: The path component to add.
    @available(macOS, introduced: 10.10, deprecated: 100000.0, message: "Use appending(path:directoryHint:) instead")
    @available(iOS, introduced: 8.0, deprecated: 100000.0, message: "Use appending(path:directoryHint:) instead")
    @available(tvOS, introduced: 9.0, deprecated: 100000.0, message: "Use appending(path:directoryHint:) instead")
    @available(watchOS, introduced: 2.0, deprecated: 100000.0, message: "Use appending(path:directoryHint:) instead")
    @available(visionOS, introduced: 1.0, deprecated: 100000.0, message: "Use appending(path:directoryHint:) instead")
    public func appendingPathComponent(_ pathComponent: String) -> URL {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            if let result = _url.appendingPathComponent(pathComponent) {
                return result
            }
            // Now we need to do something more expensive
            if var c = URLComponents(url: self, resolvingAgainstBaseURL: true) {
                c.path = (c.path as NSString).appendingPathComponent(pathComponent)
                return c.url ?? self
            } else {
                // Ultimate fallback:
                return self
            }
        }
        #endif
        return appending(path: pathComponent, directoryHint: .checkFileSystem)
    }

    /// Returns a URL constructed by removing the last path component of self.
    ///
    /// This function may either remove a path component or append `/..`.
    /// If the URL has an empty path (e.g., `http://www.example.com`), then this function will return the URL unchanged.
    public func deletingLastPathComponent() -> URL {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            // This is a slight behavior change from NSURL, but better than returning "http://www.example.com../".
            guard !path.isEmpty, let result = _url.deletingLastPathComponent.map({ URL(reference: $0 as NSURL) }) else { return self }
            return result
        }
        #endif
        guard !relativePath().isEmpty else { return self }
        var components = URLComponents(parseInfo: _parseInfo)
        var newPath = components.percentEncodedPath.deletingLastPathComponent()
        // .deletingLastPathComponent() removes the trailing "/", but we know it's a directory
        if !newPath.isEmpty, newPath.utf8.last != UInt8(ascii: "/") {
            newPath += "/"
        }
        components.percentEncodedPath = newPath
        return components.url(relativeTo: baseURL)!
    }

    /// Returns a URL constructed by appending the given path extension to self.
    ///
    /// If the URL has an empty path (e.g., `http://www.example.com`), then this function will return the URL unchanged.
    ///
    /// Certain special characters (for example, Unicode Right-To-Left marks) cannot be used as path extensions. If any of those are contained in `pathExtension`, the function will return the URL unchanged.
    /// - parameter pathExtension: The extension to append.
    public func appendingPathExtension(_ pathExtension: String) -> URL {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            guard !path.isEmpty, let result = _url.appendingPathExtension(pathExtension) else { return self }
            return result
        }
        #endif
        guard !relativePath().isEmpty else { return self }
        var components = URLComponents(parseInfo: _parseInfo)
        // pathExtension might need to be percent-encoded, so use .path
        let newPath = components.path.appendingPathExtension(pathExtension)
        components.path = newPath
        return components.url(relativeTo: baseURL)!
    }

    /// Returns a URL constructed by removing any path extension.
    ///
    /// If the URL has an empty path (e.g., `http://www.example.com`), then this function will return the URL unchanged.
    public func deletingPathExtension() -> URL {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            guard !path.isEmpty, let result = _url.deletingPathExtension.map({ URL(reference: $0 as NSURL) }) else { return self }
            return result
        }
        #endif
        guard !relativePath().isEmpty else { return self }
        var components = URLComponents(parseInfo: _parseInfo)
        let newPath = components.percentEncodedPath.deletingPathExtension()
        components.percentEncodedPath = newPath
        return components.url(relativeTo: baseURL)!
    }

    /// Appends a path component to the URL.
    ///
    /// - parameter pathComponent: The path component to add.
    /// - parameter isDirectory: Use `true` if the resulting path is a directory.
    @available(macOS, introduced: 10.10, deprecated: 100000.0, message: "Use append(path:directoryHint:) instead")
    @available(iOS, introduced: 8.0, deprecated: 100000.0, message: "Use append(path:directoryHint:) instead")
    @available(tvOS, introduced: 9.0, deprecated: 100000.0, message: "Use append(path:directoryHint:) instead")
    @available(watchOS, introduced: 2.0, deprecated: 100000.0, message: "Use append(path:directoryHint:) instead")
    @available(visionOS, introduced: 1.0, deprecated: 100000.0, message: "Use appending(path:directoryHint:) instead")
    public mutating func appendPathComponent(_ pathComponent: String, isDirectory: Bool) {
        self = appendingPathComponent(pathComponent, isDirectory: isDirectory)
    }

    /// Appends a path component to the URL.
    ///
    /// - note: This function performs a file system operation to determine if the path component is a directory. If so, it will append a trailing `/`. If you know in advance that the path component is a directory or not, then use `func appendingPathComponent(_:isDirectory:)`.
    /// - parameter pathComponent: The path component to add.
    @available(macOS, introduced: 10.10, deprecated: 100000.0, message: "Use append(path:directoryHint:) instead")
    @available(iOS, introduced: 8.0, deprecated: 100000.0, message: "Use append(path:directoryHint:) instead")
    @available(tvOS, introduced: 9.0, deprecated: 100000.0, message: "Use append(path:directoryHint:) instead")
    @available(watchOS, introduced: 2.0, deprecated: 100000.0, message: "Use append(path:directoryHint:) instead")
    @available(visionOS, introduced: 1.0, deprecated: 100000.0, message: "Use appending(path:directoryHint:) instead")
    public mutating func appendPathComponent(_ pathComponent: String) {
        self = appendingPathComponent(pathComponent)
    }

    /// Appends the given path extension to self.
    ///
    /// If the URL has an empty path (e.g., `http://www.example.com`), then this function will do nothing.
    /// Certain special characters (for example, Unicode Right-To-Left marks) cannot be used as path extensions. If any of those are contained in `pathExtension`, the function will return the URL unchanged.
    /// - parameter pathExtension: The extension to append.
    public mutating func appendPathExtension(_ pathExtension: String) {
        self = appendingPathExtension(pathExtension)
    }

    /// Returns a URL constructed by removing the last path component of self.
    ///
    /// This function may either remove a path component or append `/..`.
    ///
    /// If the URL has an empty path (e.g., `http://www.example.com`), then this function will do nothing.
    public mutating func deleteLastPathComponent() {
        self = deletingLastPathComponent()
    }

    /// Returns a URL constructed by removing any path extension.
    ///
    /// If the URL has an empty path (e.g., `http://www.example.com`), then this function will do nothing.
    public mutating func deletePathExtension() {
        self = deletingPathExtension()
    }

    /// Returns a `URL` with any instances of ".." or "." removed from its path.
    /// - note: This method does not consult the file system.
    public var standardized: URL {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            // NSURL should not return nil here unless this is a file reference URL, which should be impossible
            guard let result = _url.standardized.map({ URL(reference: $0 as NSURL) }) else { return self }
            return result
        }
        #endif
        guard !path.isEmpty else { return self }
        var components = URLComponents(parseInfo: _parseInfo)
        let newPath = components.percentEncodedPath.removingDotSegments
        components.percentEncodedPath = newPath
        return components.url(relativeTo: baseURL)!
    }

    /// Standardizes the path of a file URL by removing dot segments.
    public mutating func standardize() {
        self = self.standardized
    }

#if !NO_FILESYSTEM

    /// Standardizes the path of a file URL.
    ///
    /// If the `isFileURL` is false, this method returns `self`.
    /// - note: This method consults the file system.
    public var standardizedFileURL: URL {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            // NSURL should not return nil here unless this is a file reference URL, which should be impossible
            guard let result = _url.standardizingPath.map({ URL(reference: $0 as NSURL) }) else { return self }
            return result
        }
        #endif
        guard isFileURL && !fileSystemPath.isEmpty else { return self }
        return URL(filePath: fileSystemPath.standardizingPath, directoryHint: hasDirectoryPath ? .isDirectory : .notDirectory)
    }

    /// Resolves any symlinks in the path of a file URL.
    ///
    /// If the `isFileURL` is false, this method returns `self`.
    public func resolvingSymlinksInPath() -> URL {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            // NSURL should not return nil here unless this is a file reference URL, which should be impossible
            guard let result = _url.resolvingSymlinksInPath.map({ URL(reference: $0 as NSURL) }) else { return self }
            return result
        }
        #endif
        guard isFileURL && !fileSystemPath.isEmpty else { return self }
        return URL(filePath: fileSystemPath.resolvingSymlinksInPath, directoryHint: hasDirectoryPath ? .isDirectory : .notDirectory)
    }

    /// Resolves any symlinks in the path of a file URL.
    ///
    /// If the `isFileURL` is false, this method does nothing.
    public mutating func resolveSymlinksInPath() {
        self = self.resolvingSymlinksInPath()
    }

#if FOUNDATION_FRAMEWORK // These APIs will eventually be available in swift-foundation.

    // MARK: - Reachability

    /// Returns whether the URL's resource exists and is reachable.
    ///
    /// This method synchronously checks if the resource's backing store is reachable. Checking reachability is appropriate when making decisions that do not require other immediate operations on the resource, e.g. periodic maintenance of UI state that depends on the existence of a specific document. When performing operations such as opening a file or copying resource properties, it is more efficient to simply try the operation and handle failures. This method is currently applicable only to URLs for file system resources. For other URL types, `false` is returned.
    public func checkResourceIsReachable() throws -> Bool {
        var error: NSError?
        let result = _url.checkResourceIsReachableAndReturnError(&error)
        if let e = error {
            throw e
        } else {
            return result
        }
    }

    /// Returns whether the promised item URL's resource exists and is reachable.
    ///
    /// This method synchronously checks if the resource's backing store is reachable. Checking reachability is appropriate when making decisions that do not require other immediate operations on the resource, e.g. periodic maintenance of UI state that depends on the existence of a specific document. When performing operations such as opening a file or copying resource properties, it is more efficient to simply try the operation and handle failures. This method is currently applicable only to URLs for file system resources. For other URL types, `false` is returned.
    @available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
    public func checkPromisedItemIsReachable() throws -> Bool {
        var error: NSError?
        let result = _url.checkPromisedItemIsReachableAndReturnError(&error)
        if let e = error {
            throw e
        } else {
            return result
        }
    }

    // MARK: - Resource Values

    /// Sets the resource value identified by a given resource key.
    ///
    /// This method writes the new resource values out to the backing store. Attempts to set a read-only resource property or to set a resource property not supported by the resource are ignored and are not considered errors. This method is currently applicable only to URLs for file system resources.
    ///
    /// `URLResourceValues` keeps track of which of its properties have been set. Those values are the ones used by this function to determine which properties to write.
    public mutating func setResourceValues(_ values: URLResourceValues) throws {
        try _url.setResourceValues(values._values)
    }

    /// Return a collection of resource values identified by the given resource keys.
    ///
    /// This method first checks if the URL object already caches the resource value. If so, it returns the cached resource value to the caller. If not, then this method synchronously obtains the resource value from the backing store, adds the resource value to the URL object's cache, and returns the resource value to the caller. The type of the resource value varies by resource property (see resource key definitions). If this method does not throw and the resulting value in the `URLResourceValues` is populated with nil, it means the resource property is not available for the specified resource and no errors occurred when determining the resource property was not available. This method is currently applicable only to URLs for file system resources.
    ///
    /// When this function is used from the main thread, resource values cached by the URL (except those added as temporary properties) are removed the next time the main thread's run loop runs. `func removeCachedResourceValue(forKey:)` and `func removeAllCachedResourceValues()` also may be used to remove cached resource values.
    ///
    /// Only the values for the keys specified in `keys` will be populated.
    public func resourceValues(forKeys keys: Set<URLResourceKey>) throws -> URLResourceValues {
        return URLResourceValues(keys: keys, values: try _url.resourceValues(forKeys: Array(keys)))
    }

    /// Sets a temporary resource value on the URL object.
    ///
    /// Temporary resource values are for client use. Temporary resource values exist only in memory and are never written to the resource's backing store. Once set, a temporary resource value can be copied from the URL object with `func resourceValues(forKeys:)`. The values are stored in the loosely-typed `allValues` dictionary property.
    ///
    /// To remove a temporary resource value from the URL object, use `func removeCachedResourceValue(forKey:)`. Care should be taken to ensure the key that identifies a temporary resource value is unique and does not conflict with system defined keys (using reverse domain name notation in your temporary resource value keys is recommended). This method is currently applicable only to URLs for file system resources.
    @preconcurrency
    public mutating func setTemporaryResourceValue(_ value: Sendable, forKey key: URLResourceKey) {
        _url.setTemporaryResourceValue(value, forKey: key)
    }

    /// Removes all cached resource values and all temporary resource values from the URL object.
    ///
    /// This method is currently applicable only to URLs for file system resources.
    public mutating func removeAllCachedResourceValues() {
        _url.removeAllCachedResourceValues()
    }

    /// Removes the cached resource value identified by a given resource value key from the URL object.
    ///
    /// Removing a cached resource value may remove other cached resource values because some resource values are cached as a set of values, and because some resource values depend on other resource values (temporary resource values have no dependencies). This method is currently applicable only to URLs for file system resources.
    public mutating func removeCachedResourceValue(forKey key: URLResourceKey) {
        _url.removeCachedResourceValue(forKey: key)
    }

    /// Get resource values from URLs of 'promised' items.
    ///
    /// A promised item is not guaranteed to have its contents in the file system until you use `FileCoordinator` to perform a coordinated read on its URL, which causes the contents to be downloaded or otherwise generated. Promised item URLs are returned by various APIs, including currently:
    ///     NSMetadataQueryUbiquitousDataScope
    ///     NSMetadataQueryUbiquitousDocumentsScope
    ///     A `FilePresenter` presenting the contents of the directory located by -URLForUbiquitousContainerIdentifier: or a subdirectory thereof
    ///
    /// The following methods behave identically to their similarly named methods above (`func resourceValues(forKeys:)`, etc.), except that they allow you to get resource values and check for presence regardless of whether the promised item's contents currently exist at the URL. You must use these APIs instead of the normal URL resource value APIs if and only if any of the following are true:
    ///     You are using a URL that you know came directly from one of the above APIs
    ///     You are inside the accessor block of a coordinated read or write that used NSFileCoordinatorReadingImmediatelyAvailableMetadataOnly, NSFileCoordinatorWritingForDeleting, NSFileCoordinatorWritingForMoving, or NSFileCoordinatorWritingContentIndependentMetadataOnly
    ///
    /// Most of the URL resource value keys will work with these APIs. However, there are some that are tied to the item's contents that will not work, such as `contentAccessDateKey` or `generationIdentifierKey`. If one of these keys is used, the method will return a `URLResourceValues` value, but the value for that property will be nil.
    @available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
    public func promisedItemResourceValues(forKeys keys: Set<URLResourceKey>) throws -> URLResourceValues {
        return URLResourceValues(keys: keys, values: try _url.promisedItemResourceValues(forKeys: Array(keys)))
    }

#endif // FOUNDATION_FRAMEWORK

#if FOUNDATION_FRAMEWORK // These APIs are Darwin-specific.

    // MARK: - Bookmarks and Alias Files

    /// Returns bookmark data for the URL, created with specified options and resource values.
    public func bookmarkData(options: BookmarkCreationOptions = [], includingResourceValuesForKeys keys: Set<URLResourceKey>? = nil, relativeTo url: URL? = nil) throws -> Data {
        let result = try _url.bookmarkData(options: options, includingResourceValuesForKeys: keys.flatMap { Array($0) }, relativeTo: url)
        return result
    }

    /// Returns the resource values for properties identified by a specified array of keys contained in specified bookmark data. If the result dictionary does not contain a resource value for one or more of the requested resource keys, it means those resource properties are not available in the bookmark data.
    public static func resourceValues(forKeys keys: Set<URLResourceKey>, fromBookmarkData data: Data) -> URLResourceValues? {
        return NSURL.resourceValues(forKeys: Array(keys), fromBookmarkData: data).map { URLResourceValues(keys: keys, values: $0) }
    }

    /// Creates an alias file on disk at a specified location with specified bookmark data. bookmarkData must have been created with the URLBookmarkCreationSuitableForBookmarkFile option. bookmarkFileURL must either refer to an existing file (which will be overwritten), or to location in an existing directory.
    public static func writeBookmarkData(_ data: Data, to url: URL) throws {
        // Options are unused
        try NSURL.writeBookmarkData(data, to: url, options: 0)
    }

    /// Initializes and returns bookmark data derived from an alias file pointed to by a specified URL. If bookmarkFileURL refers to an alias file created prior to OS X v10.6 that contains Alias Manager information but no bookmark data, this method synthesizes bookmark data for the file.
    public static func bookmarkData(withContentsOf url: URL) throws -> Data {
        let result = try NSURL.bookmarkData(withContentsOf: url)
        return result
    }

    /// Given an NSURL created by resolving a bookmark data created with security scope, make the resource referenced by the url accessible to the process. When access to this resource is no longer needed the client must call stopAccessingSecurityScopedResource. Each call to startAccessingSecurityScopedResource must be balanced with a call to stopAccessingSecurityScopedResource (Note: this is not reference counted).
    @available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
    public func startAccessingSecurityScopedResource() -> Bool {
        return _url.startAccessingSecurityScopedResource()
    }

    /// Revokes the access granted to the url by a prior successful call to startAccessingSecurityScopedResource.
    @available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
    public func stopAccessingSecurityScopedResource() {
        _url.stopAccessingSecurityScopedResource()
    }

#endif // FOUNDATION_FRAMEWORK
#endif // !NO_FILESYSTEM

#if FOUNDATION_FRAMEWORK

    // MARK: - Bridging Support

    /// We must not store an NSURL without running it through this function. This makes sure that we do not hold a file reference URL, which changes the nullability of many NSURL functions.
    private static func _converted(from url: NSURL) -> NSURL {
        #if NO_FILESYSTEM
        return url
        #else
        // Future readers: file reference URL here is not the same as playgrounds "file reference"
        if url.isFileReferenceURL() {
            // Convert to a file path URL, or use an invalid scheme
            return (url.filePathURL ?? URL(string: "com-apple-unresolvable-file-reference-url:")!) as NSURL
        } else {
            return url
        }
        #endif
    }

    private init(convertedReference: __shared NSURL) {
        _url = convertedReference
    }

    private init(reference: __shared NSURL) {
        _url = URL._converted(from: reference).copy() as! NSURL
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            return
        }
        #endif
        _parseInfo = Parser.parse(urlString: _url.relativeString, encodingInvalidCharacters: true)!
        _baseParseInfo = reference.baseURL?._parseInfo
    }

    private var reference: NSURL {
        return _url
    }

#endif // FOUNDATION_FRAMEWORK

    public func hash(into hasher: inout Hasher) {
        #if FOUNDATION_FRAMEWORK
        hasher.combine(_url)
        guard foundation_swift_url_enabled() else {
            return
        }
        #endif
        hasher.combine(_parseInfo.urlString)
        hasher.combine(_baseParseInfo?.urlString)
    }

    public static func ==(lhs: URL, rhs: URL) -> Bool {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            return lhs.reference.isEqual(rhs.reference)
        }
        #endif // FOUNDATION_FRAMEWORK
        let isEqual = (
            lhs._parseInfo.urlString == rhs._parseInfo.urlString &&
            lhs._baseParseInfo?.urlString == rhs._baseParseInfo?.urlString
        )
        #if FOUNDATION_FRAMEWORK
        return isEqual && lhs.reference.isEqual(rhs.reference)
        #else
        return isEqual
        #endif // FOUNDATION_FRAMEWORK
    }
}

extension URL {
#if FOUNDATION_FRAMEWORK
    /// Initialize a URL with a String literal. This initializer **requires** the
    /// string literal contains a URL scheme such as `file://` or `https://` to correctly
    /// interpret the URL. For web addresses (URLs that doesn't start with the `file` scheme),
    /// it will `precondition` that the addresses are valid.
    /// - precondition: `string` must contain a URL scheme and is not malformed.
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    /* public */ private init(_ string: StaticString) {
        // If the string has the file scheme (starts with "file:"),
        // parse it as file path, otherwise parse it as web address
        let str = "\(string)"
        if str.starts(with: "file:") {
            self = URL(filePath: str)
        } else {
            let webAddress = URL(string: str)
            precondition(webAddress != nil && webAddress!.scheme != nil)
            self = webAddress!
        }
    }
#endif // FOUNDATION_FRAMEWORK

#if !NO_FILESYSTEM
    private static func isDirectory(_ path: String) -> Bool {
#if !FOUNDATION_FRAMEWORK
        var isDirectory: Bool = false
        _ = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        return isDirectory
#else
        var isDirectory: ObjCBool = false
        _ = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        return isDirectory.boolValue
#endif
    }
#endif // !NO_FILESYSTEM

    /// Checks if a file path is absolute and standardizes the inputted file path on Windows
    internal static func isAbsolute(standardizing filePath: inout String) -> Bool {
        #if os(Windows)
        var isAbsolute = false
        let utf8 = filePath.utf8
        if utf8.first == ._backslash {
            // Either an absolute path or a UNC path
            isAbsolute = true
        } else if utf8.count >= 3 {
            // Check if this is a drive letter
            let first = utf8.first!
            let secondIndex = utf8.index(after: utf8.startIndex)
            let second = utf8[secondIndex]
            let thirdIndex = utf8.index(after: secondIndex)
            let third = utf8[thirdIndex]
            isAbsolute = (
                first.isAlpha
                && (second == ._colon || second == ._pipe)
                && third == ._backslash
            )

            if isAbsolute {
                // Standardize to "\[drive-letter]:\..."
                if second == ._pipe {
                    var filePathArray = Array(utf8)
                    filePathArray[1] = ._colon
                    filePathArray.insert(._backslash, at: 0)
                    filePath = String(decoding: filePathArray, as: UTF8.self)
                } else {
                    filePath = "\\" + filePath
                }
            }
        }
        #else
        let isAbsolute = filePath.utf8.first == UInt8(ascii: "/") || filePath.utf8.first == UInt8(ascii: "~")
        #endif
        return isAbsolute
    }

    /// Initializes a newly created file URL referencing the local file or directory at path, relative to a base URL.
    ///
    /// If an empty string is used for the path, then the path is assumed to be ".".
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public init(filePath path: String, directoryHint: DirectoryHint = .inferFromPath, relativeTo base: URL? = nil) {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            let filePath = path.isEmpty ? "./" : path
            let url: NSURL
            switch directoryHint {
            case .isDirectory:
                url = URL._converted(from: NSURL(fileURLWithPath: filePath, isDirectory: true, relativeTo: base))
            case .notDirectory:
                url = URL._converted(from: NSURL(fileURLWithPath: filePath, isDirectory: false, relativeTo: base))
            case .checkFileSystem:
                url = URL._converted(from: NSURL(fileURLWithPath: filePath, relativeTo: base))
            case .inferFromPath:
                let isDirectory = filePath.hasSuffix("/")
                url = URL._converted(from: NSURL(fileURLWithPath: filePath, isDirectory: isDirectory, relativeTo: base))
            }
            self.init(convertedReference: url)
            return
        }
        #endif // FOUNDATION_FRAMEWORK
        var baseURL = base
        guard !path.isEmpty else {
            #if !NO_FILESYSTEM
            baseURL = baseURL ?? .currentDirectoryOrNil()
            #endif
            self.init(string: "", relativeTo: baseURL)!
            return
        }

        #if os(Windows)
        let slash = UInt8(ascii: "\\")
        var filePath = path.replacing(UInt8(ascii: "/"), with: slash)
        #else
        let slash = UInt8(ascii: "/")
        var filePath = path
        #endif

        let isAbsolute = URL.isAbsolute(standardizing: &filePath)

        #if !NO_FILESYSTEM
        if !isAbsolute {
            baseURL = baseURL ?? .currentDirectoryOrNil()
        }
        #endif

        func absoluteFilePath() -> String {
            guard !isAbsolute, let baseURL else {
                return filePath
            }
            let basePath = baseURL.path()
            #if os(Windows)
            let urlPath = filePath.replacing(UInt8(ascii: "\\"), with: UInt8(ascii: "/"))
            return URL.fileSystemPath(for: basePath.merging(relativePath: urlPath)).replacing(UInt8(ascii: "/"), with: UInt8(ascii: "\\"))
            #else
            return URL.fileSystemPath(for: basePath.merging(relativePath: filePath))
            #endif
        }

        let isDirectory: Bool
        switch directoryHint {
        case .isDirectory:
            isDirectory = true
        case .notDirectory:
            isDirectory = false
        case .checkFileSystem:
            #if !NO_FILESYSTEM
            isDirectory = URL.isDirectory(absoluteFilePath())
            #else
            isDirectory = filePath.utf8.last == slash
            #endif
        case .inferFromPath:
            isDirectory = filePath.utf8.last == slash
        }

        #if os(Windows)
        // Convert any "\" back to "/" before storing the URL parse info
        filePath = filePath.replacing(UInt8(ascii: "\\"), with: UInt8(ascii: "/"))
        #endif

        if !filePath.isEmpty && filePath.utf8.last != UInt8(ascii: "/") && isDirectory {
            filePath += "/"
        }
        var components = URLComponents()
        if isAbsolute {
            components.scheme = "file"
            components.encodedHost = ""
        }
        components.path = filePath

        if !isAbsolute {
            self = components.url(relativeTo: baseURL)!
        } else {
            // Drop the baseURL if the URL is absolute
            self = components.url!
        }
    }

    private func appending<S: StringProtocol>(path: S, directoryHint: DirectoryHint, encodingSlashes: Bool) -> URL {
        #if os(Windows)
        var path = path.replacing(._backslash, with: ._slash)
        #else
        var path = String(path)
        #endif

        var newPath = relativePath()
        var insertedSlash = false
        if !newPath.isEmpty && path.utf8.first != ._slash {
            // Don't treat as first path segment when encoding
            path = "/" + path
            insertedSlash = true
        }

        guard var pathToAppend = Parser.percentEncode(path, component: .path) else {
            return self
        }
        if encodingSlashes {
            var utf8 = Array(pathToAppend.utf8)
            utf8[(insertedSlash ? 1 : 0)...].replace([._slash], with: [UInt8(ascii: "%"), UInt8(ascii: "2"), UInt8(ascii: "F")])
            pathToAppend = String(decoding: utf8, as: UTF8.self)
        }

        if newPath.utf8.last != ._slash && pathToAppend.utf8.first != ._slash {
            newPath += "/"
        } else if newPath.utf8.last == ._slash && pathToAppend.utf8.first == ._slash {
            _ = newPath.popLast()
        }

        newPath += pathToAppend

        let hasTrailingSlash = newPath.utf8.last == ._slash
        let isDirectory: Bool
        switch directoryHint {
        case .isDirectory:
            isDirectory = true
        case .notDirectory:
            isDirectory = false
        case .checkFileSystem:
            #if !NO_FILESYSTEM
            // We can only check file system if the URL is a file URL
            if isFileURL {
                let filePath: String
                if newPath.utf8.first == ._slash {
                    filePath = URL.fileSystemPath(for: newPath)
                } else {
                    filePath = URL.fileSystemPath(for: mergedPath(for: newPath))
                }
                isDirectory = URL.isDirectory(filePath)
            } else {
                // For web addresses, trust the trailing slash
                isDirectory = hasTrailingSlash
            }
            #else // !NO_FILESYSTEM
            isDirectory = hasTrailingSlash
            #endif // !NO_FILESYSTEM
        case .inferFromPath:
            isDirectory = hasTrailingSlash
        }
        if isDirectory && newPath.utf8.last != ._slash {
            newPath += "/"
        }

        var components = URLComponents(parseInfo: _parseInfo)
        components.percentEncodedPath = newPath
        return components.url(relativeTo: baseURL) ?? self
    }

    /// Returns a URL constructed by appending the given path to self.
    /// - Parameters:
    ///   - path: The path to add
    ///   - directoryHint: A hint to whether this URL will point to a directory
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public func appending<S: StringProtocol>(path: S, directoryHint: DirectoryHint = .inferFromPath) -> URL {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            let isDirectory: Bool?
            let hasTrailingSlash = path.hasSuffix("/")
            switch directoryHint {
            case .isDirectory:
                isDirectory = true
            case .notDirectory:
                isDirectory = false
            case .checkFileSystem:
                // We can only check file system if the URL is a file URL
                if self.isFileURL {
                    isDirectory = nil
                } else {
                    // For web addresses we'll have to trust the caller to
                    // do the right ting with the trailing slash
                    isDirectory = hasTrailingSlash
                }
            case .inferFromPath:
                isDirectory = hasTrailingSlash
            }

            let result: URL?
            if let isDirectory {
                result = _url.appendingPathComponent(String(path), isDirectory: isDirectory)
            } else {
                result = _url.appendingPathComponent(String(path))
            }

            if let result {
                return result
            }
            // Now we need to do something more expensive
            if var c = URLComponents(url: self, resolvingAgainstBaseURL: true) {
                let newPath = (c.path as NSString).appendingPathComponent(String(path))
                c.path = newPath
                if let isDirectory, isDirectory, !newPath.hasSuffix("/") {
                    c.path = newPath + "/"
                }
                return c.url ?? self
            } else {
                // Ultimate fallback:
                return self
            }
        }
        #endif // FOUNDATION_FRAMEWORK
        return appending(path: path, directoryHint: directoryHint, encodingSlashes: false)
    }

    /// Appends a path to the receiver.
    ///
    /// - parameter path: The path to add.
    /// - parameter directoryHint: A hint to whether this URL will point to a directory
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public mutating func append<S: StringProtocol>(path: S, directoryHint: DirectoryHint = .inferFromPath) {
        self = appending(path: path, directoryHint: directoryHint)
    }

    /// Returns a URL constructed by appending the given path component to self. The path component
    /// is first percent-encoded before being appended to the receiver.
    /// - Parameters:
    ///   - component: A path component to append to the receiver.
    ///   - directoryHint: A hint to whether this URL will point to a directory.
    /// - Returns: The new URL
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public func appending<S: StringProtocol>(component: S, directoryHint: DirectoryHint = .inferFromPath) -> URL {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            let pathComponent = String(component)
            let hasTrailingSlash = pathComponent.hasSuffix("/")
            let isDirectory: Bool?
            switch directoryHint {
            case .isDirectory: isDirectory = true
            case .notDirectory: isDirectory = false
            case .inferFromPath: isDirectory = hasTrailingSlash
            case .checkFileSystem:
                // We can only check file system if the URL is a file URL
                if self.isFileURL {
                    isDirectory = nil
                } else {
                    // For web addresses we'll have to trust the caller to
                    // do the right ting with the trailing slash
                    isDirectory = hasTrailingSlash
                }
            }
            if let isDirectory {
                let cf = _url._cfurl().takeUnretainedValue()
                return _CFURLCreateCopyAppendingPathComponent(cf, pathComponent as CFString, isDirectory).takeRetainedValue() as URL
            }
            // We need to check the file system. This is the same behavior
            // as `NSURL.URLByAppendingPathComponent`
            // Crate a new URL without the trailing slash
            let result = self.appending(component: component, directoryHint: .notDirectory)
            // See if it refers to a directory
            #if NO_FILESYSTEM
            // Fall back to `inferFromPath`
            let cf = _url._cfurl().takeUnretainedValue()
            return _CFURLCreateCopyAppendingPathComponent(cf, pathComponent as CFString, hasTrailingSlash).takeRetainedValue() as URL
            #else // NO_FILESYSTEM
            if let resourceValues = try? result.resourceValues(forKeys: [.isDirectoryKey]),
               let isDirectoryValue = resourceValues.isDirectory {
                let cf = _url._cfurl().takeUnretainedValue()
                return _CFURLCreateCopyAppendingPathComponent(cf, pathComponent as CFString, isDirectoryValue).takeRetainedValue() as URL
            } else {
                // Fall back to `inferFromPath`
                let cf = _url._cfurl().takeUnretainedValue()
                return _CFURLCreateCopyAppendingPathComponent(cf, pathComponent as CFString, hasTrailingSlash).takeRetainedValue() as URL
            }
            #endif // NO_FILESYSTEM
        }
        #endif // FOUNDATION_FRAMEWORK
        return appending(path: component, directoryHint: directoryHint, encodingSlashes: true)
    }

    /// Appends a path component to the receiver. The path component is first
    /// percent-encoded before being appended to the receiver.
    /// - Parameters:
    ///   - component: A path component to append to the receiver.
    ///   - directoryHint: A hint to whether this URL will point to a directory.
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public mutating func append<S: StringProtocol>(component: S, directoryHint: DirectoryHint = .inferFromPath) {
        self = appending(component: component, directoryHint: directoryHint)
    }

    /// Returns a URL constructed by appending the given list of `URLQueryItem` to self.
    /// - Parameter queryItems: A list of `URLQueryItem` to append to the receiver.
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public func appending(queryItems: [URLQueryItem]) -> URL {
        if var c = URLComponents(url: self, resolvingAgainstBaseURL: true) {
            var newItems = c.queryItems ?? []
            newItems.append(contentsOf: queryItems)
            c.queryItems = newItems
            if let url = c.url {
                return url
            }
        }
        return self
    }

    /// Appends a list of `URLQueryItem` to the receiver.
    /// - Parameter queryItems: A list of `URLQueryItem` to append to the receiver.
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public mutating func append(queryItems: [URLQueryItem]) {
        self = appending(queryItems: queryItems)
    }

    /// Returns a URL constructed by appending the given varidic list of path components to self.
    ///
    /// - Parameters:
    ///   - components: The list of components to add.
    ///   - directoryHint: A hint to whether this URL will point to a directory.
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public func appending<S: StringProtocol>(components: S..., directoryHint: DirectoryHint = .inferFromPath) -> URL {
        return _appending(components: components, directoryHint: directoryHint)
    }

    /// Appends a varidic list of path components to the URL.
    ///
    /// - parameter components: The list of components to add.
    /// - parameter directoryHint: A hint to whether this URL will point to a directory.
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public mutating func append<S: StringProtocol>(components: S..., directoryHint: DirectoryHint = .inferFromPath) {
        self = _appending(components: components, directoryHint: directoryHint)
    }

    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    private func _appending<S: StringProtocol>(components: [S], directoryHint: DirectoryHint) -> URL {
        var result = self
        var pathComponents = Array(components)
        let lastComponent = pathComponents.removeLast()
        for component in pathComponents {
            result = result.appending(component: String(component), directoryHint: .isDirectory)
        }
        result = result.appending(component: String(lastComponent), directoryHint: directoryHint)
        return result
    }
}

#if !NO_FILESYSTEM
extension URL {
    private static func currentDirectoryOrNil() -> URL? {
        let path: String? = FileManager.default.currentDirectoryPath
        guard var filePath = path else {
            return nil
        }
        guard URL.isAbsolute(standardizing: &filePath) else {
            return nil
        }
        return URL(filePath: filePath, directoryHint: .isDirectory)
    }

    /// The working directory of the current process.
    /// Calling this property will issue a `getcwd` syscall.
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public static func currentDirectory() -> URL {
        return URL(filePath: FileManager.default.currentDirectoryPath, directoryHint: .isDirectory)
    }

    /// The home directory for the current user (~/).
    /// Complexity: O(1)
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public static var homeDirectory: URL {
        #if FOUNDATION_FRAMEWORK && !os(macOS)
        URL(filePath: NSHomeDirectory(), directoryHint: .isDirectory)
        #elseif FOUNDATION_FRAMEWORK
        if foundation_swift_url_enabled() {
            return FileManager.default.homeDirectoryForCurrentUser
        }
        return URL(filePath: NSHomeDirectory(), directoryHint: .isDirectory)
        #else
        FileManager.default.homeDirectoryForCurrentUser
        #endif
    }

    /// Returns the home directory for the specified user.
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public static func homeDirectory(forUser user: String) -> URL? {
        #if FOUNDATION_FRAMEWORK && !os(macOS)
        guard let path = NSHomeDirectoryForUser(user) else {
            return nil
        }
        return URL(filePath: path, directoryHint: .isDirectory)
        #elseif FOUNDATION_FRAMEWORK
        if foundation_swift_url_enabled() {
            return FileManager.default.homeDirectory(forUser: user)
        }
        guard let path = NSHomeDirectoryForUser(user) else {
            return nil
        }
        return URL(filePath: path, directoryHint: .isDirectory)
        #else
        return FileManager.default.homeDirectory(forUser: user)
        #endif
    }

    /// The temporary directory for the current user.
    /// Complexity: O(1)
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public static var temporaryDirectory: URL {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            return URL(filePath: NSTemporaryDirectory(), directoryHint: .isDirectory)
        }
        #endif
        return FileManager.default.temporaryDirectory
    }

#if FOUNDATION_FRAMEWORK
    /// Discardable cache files directory for the
    /// current user. (~/Library/Caches).
    /// Complexity: O(n) where n is the number of significant directories
    /// specified by `FileManager.SearchPathDirectory`
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public static var cachesDirectory: URL { url(for: .cachesDirectory, in: .userDomainMask) }

    /// Supported applications (/Applications).
    /// Complexity: O(n) where n is the number of significant directories
    /// specified by `FileManager.SearchPathDirectory`
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public static var applicationDirectory: URL { url(for: .applicationDirectory, in: .localDomainMask) }

    /// Various user-visible documentation, support, and configuration
    /// files for the current user (~/Library).
    /// Complexity: O(n) where n is the number of significant directories
    /// specified by `FileManager.SearchPathDirectory`
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public static var libraryDirectory: URL { url(for: .libraryDirectory, in: .userDomainMask) }

    /// User home directories (/Users).
    /// Complexity: O(n) where n is the number of significant directories
    /// specified by `FileManager.SearchPathDirectory`
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public static var userDirectory: URL { url(for: .userDirectory, in: .localDomainMask) }

    /// Documents directory for the current user (~/Documents)
    /// Complexity: O(n) where n is the number of significant directories
    /// specified by `FileManager.SearchPathDirectory`
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public static var documentsDirectory: URL { url(for: .documentDirectory, in: .userDomainMask) }

    /// Desktop directory for the current user (~/Desktop)
    /// Complexity: O(n) where n is the number of significant directories
    /// specified by `FileManager.SearchPathDirectory`
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public static var desktopDirectory: URL { url(for: .desktopDirectory, in: .userDomainMask) }

    /// Application support files for the current
    /// user (~/Library/Application Support)
    /// Complexity: O(n) where n is the number of significant directories
    /// specified by `FileManager.SearchPathDirectory`
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public static var applicationSupportDirectory: URL { url(for: .applicationSupportDirectory, in: .userDomainMask) }

    /// Downloads directory for the current user (~/Downloads)
    /// Complexity: O(n) where n is the number of significant directories
    /// specified by `FileManager.SearchPathDirectory`
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public static var downloadsDirectory: URL { url(for: .downloadsDirectory, in: .userDomainMask) }

    /// Movies directory for the current user (~/Movies)
    /// Complexity: O(n) where n is the number of significant directories
    /// specified by `FileManager.SearchPathDirectory`
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public static var moviesDirectory: URL { url(for: .moviesDirectory, in: .userDomainMask) }

    /// Music directory for the current user (~/Music)
    /// Complexity: O(n) where n is the number of significant directories
    /// specified by `FileManager.SearchPathDirectory`
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public static var musicDirectory: URL { url(for: .musicDirectory, in: .userDomainMask) }

    /// Pictures directory for the current user (~/Pictures)
    /// Complexity: O(n) where n is the number of significant directories
    /// specified by `FileManager.SearchPathDirectory`
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public static var picturesDirectory: URL { url(for: .picturesDirectory, in: .userDomainMask) }

    /// The user’s Public sharing directory (~/Public)
    /// Complexity: O(n) where n is the number of significant directories
    /// specified by `FileManager.SearchPathDirectory`
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public static var sharedPublicDirectory: URL { url(for: .sharedPublicDirectory, in: .userDomainMask) }

    /// Trash directory for the current user (~/.Trash)
    /// Complexity: O(n) where n is the number of significant directories
    /// specified by `FileManager.SearchPathDirectory`
    @available(macOS 13.0, iOS 16.0, *)
    @available(tvOS, unavailable)
    @available(watchOS, unavailable)
    public static var trashDirectory: URL { url(for: .trashDirectory, in: .userDomainMask) }

    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public init(
        for directory: FileManager.SearchPathDirectory,
        in domain: FileManager.SearchPathDomainMask,
        appropriateFor url: URL? = nil,
        create shouldCreate: Bool = false
    ) throws {
        self = try FileManager.default.url(
            for: directory,
            in: domain,
            appropriateFor: url,
            create: shouldCreate
        )
    }

    @inline(__always)
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    private static func url(for directory: FileManager.SearchPathDirectory, in domain: FileManager.SearchPathDomainMask) -> URL {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            return URL(
                filePath: NSSearchPathForDirectoriesInDomains(directory, domain, true)[0],
                directoryHint: .isDirectory
            )
        }
        #endif
        return FileManager.default.urls(for: directory, in: domain).first!
    }
#endif // FOUNDATION_FRAMEWORK
}
#endif // !NO_FILESYSTEM

extension URL {
    @available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
    public enum DirectoryHint: Sendable {
        /// Specifies that the `URL` does reference a directory
        case isDirectory
        /// Specifies that the `URL` does **not** reference a directory
        case notDirectory
        /// Specifies that `URL` should check with the file system to determine whether it references a directory
        case checkFileSystem
        /// Specifies that `URL` should infer whether it references a directory based on whether it has a trailing slash
        case inferFromPath
    }
}

#if FOUNDATION_FRAMEWORK
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
extension URL /* : ExpressibleByStringLiteral */ {
    /* public */ internal typealias StringLiteralType = StaticString

    /// Initialize a URL with a String literal. This initializer **requires** the
    /// string literal contains a URL scheme such as `file://` or `https://` to correctly
    /// interpret the URL. For web addresses (URLs that doesn't start with the `file` scheme),
    /// it will `precondition` that the addresses are valid.
    /// - precondition: `string` must contain a URL scheme and is not malformed.
    /* public */ internal init(stringLiteral value: StringLiteralType) {
        self.init(value)
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension URL: ReferenceConvertible, _ObjectiveCBridgeable {

    public typealias ReferenceType = NSURL

    @_semantics("convertToObjectiveC")
    public func _bridgeToObjectiveC() -> NSURL {
        return _url
    }

    public static func _forceBridgeFromObjectiveC(_ source: NSURL, result: inout URL?) {
        if !_conditionallyBridgeFromObjectiveC(source, result: &result) {
            fatalError("Unable to bridge \(_ObjectiveCType.self) to \(self)")
        }
    }

    public static func _conditionallyBridgeFromObjectiveC(_ source: NSURL, result: inout URL?) -> Bool {
        result = URL(reference: source)
        return true
    }

    @_effects(readonly)
    public static func _unconditionallyBridgeFromObjectiveC(_ source: NSURL?) -> URL {
        var result: URL?
        _forceBridgeFromObjectiveC(source!, result: &result)
        return result!
    }
}
#endif // FOUNDATION_FRAMEWORK

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension URL: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            return _url.description
        }
        #endif
        let urlString: String
        if scheme?.lowercased() == "data" && relativeString.count > 128 {
            urlString = "\(relativeString.prefix(120)) ... \(relativeString.suffix(8))"
        } else {
            urlString = relativeString
        }
        if let baseURL {
            return "\(urlString) -- \(baseURL)"
        }
        return urlString
    }

    public var debugDescription: String {
        #if FOUNDATION_FRAMEWORK
        guard foundation_swift_url_enabled() else {
            return _url.debugDescription
        }
        #endif
        return description
    }
}

#if FOUNDATION_FRAMEWORK
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension NSURL: _HasCustomAnyHashableRepresentation {
    // Must be @nonobjc to avoid infinite recursion during bridging.
    @nonobjc
    public func _toCustomAnyHashable() -> AnyHashable? {
        return AnyHashable(self as URL)
    }
}

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension URL: _CustomPlaygroundQuickLookable {
    @available(*, deprecated, message: "URL.customPlaygroundQuickLook will be removed in a future Swift version")
    public var customPlaygroundQuickLook: PlaygroundQuickLook {
        return .url(absoluteString)
    }
}
#endif // FOUNDATION_FRAMEWORK

@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension URL: Codable {
    private enum CodingKeys: Int, CodingKey {
        case base
        case relative
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let relative = try container.decode(String.self, forKey: .relative)
        let base = try container.decodeIfPresent(URL.self, forKey: .base)

        guard let url = URL(string: relative, relativeTo: base) else {
            throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: decoder.codingPath,
                                                                    debugDescription: "Invalid URL string."))
        }

        self = url
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(self.relativeString, forKey: .relative)
        if let base = self.baseURL {
            try container.encode(base, forKey: .base)
        }
    }
}

#if FOUNDATION_FRAMEWORK
//===----------------------------------------------------------------------===//
// File references, for playgrounds.
//===----------------------------------------------------------------------===//
@available(macOS 10.10, iOS 8.0, watchOS 2.0, tvOS 9.0, *)
extension URL: _ExpressibleByFileReferenceLiteral {
    public init(fileReferenceLiteralResourceName name: String) {
        self = Bundle.main.url(forResource: name, withExtension: nil)!
    }
}

public typealias _FileReferenceLiteralType = URL
#endif // FOUNDATION_FRAMEWORK

fileprivate extension UInt8 {
    var isAlpha: Bool {
        switch self {
        case UInt8(ascii: "A")...UInt8(ascii: "Z"), UInt8(ascii: "a")...UInt8(ascii: "z"):
            return true
        default:
            return false
        }
    }
}
