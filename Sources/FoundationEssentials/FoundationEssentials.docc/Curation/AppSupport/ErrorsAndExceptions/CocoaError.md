# ``/FoundationEssentials/CocoaError``


## Topics

### Structures


### Creating an error

- ``init(_:userInfo:)``
- ``error(_:userInfo:url:)``

### Inspecting the error

- ``code``
- ``Code``
- ``errorDomain``
- ``filePath``
- ``stringEncoding``
- ``underlying``
- ``underlyingErrors``
- ``url``
- ``userInfo``

### Inspecting error causes

- ``isCoderError``
- ``isExecutableError``
- ``isFileError``
- ``isFormattingError``
- ``isPropertyListError``
- ``isValidationError``


### Indentifying file errors

- ``fileLocking``
- ``fileManagerUnmountBusy``
- ``fileManagerUnmountUnknown``
- ``fileNoSuchFile``
- ``fileReadCorruptFile``
- ``fileReadInapplicableStringEncoding``
- ``fileReadInvalidFileName``
- ``fileReadNoPermission``
- ``fileReadNoSuchFile``
- ``fileReadTooLarge``
- ``fileReadUnknown``
- ``fileReadUnknownStringEncoding``
- ``fileReadUnsupportedScheme``
- ``fileWriteFileExists``
- ``fileWriteInapplicableStringEncoding``
- ``fileWriteInvalidFileName``
- ``fileWriteNoPermission``
- ``fileWriteOutOfSpace``
- ``fileWriteUnknown``
- ``fileWriteUnsupportedScheme``
- ``fileWriteVolumeReadOnly``

### Identifying executable errors

- ``executableArchitectureMismatch``
- ``executableLink``
- ``executableLoad``
- ``executableNotLoadable``
- ``executableRuntimeMismatch``

### Identifying archiving errors

- ``propertyListReadCorrupt``
- ``propertyListReadStream``
- ``propertyListReadUnknownVersion``
- ``propertyListWriteInvalid``
- ``propertyListWriteStream``

### Identifying key-value coding errors

- ``keyValueValidation``

### Identifying miscellaneous errors

- ``featureUnsupported``
- ``formatting``

### Identifying cancellation

- ``userCancelled``
