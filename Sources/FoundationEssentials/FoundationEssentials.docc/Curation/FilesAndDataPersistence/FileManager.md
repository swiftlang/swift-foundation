# ``/FoundationEssentials/FileManager``


## Topics

### Creating a file manager

- ``init()``
- ``default``

### Accessing user directories

- ``homeDirectoryForCurrentUser``
- ``homeDirectory(forUser:)``
- ``temporaryDirectory``

### Locating system directories

- ``urls(for:in:)``
- ``url(for:in:appropriateFor:create:)``
- ``SearchPathDirectory``
- ``SearchPathDomainMask``


### Discovering directory contents

- ``contentsOfDirectory(atPath:)``
- ``subpathsOfDirectory(atPath:)``

### Creating and deleting items

- ``createDirectory(at:withIntermediateDirectories:attributes:)``
- ``createDirectory(atPath:withIntermediateDirectories:attributes:)``
- ``createFile(atPath:contents:attributes:)``
- ``removeItem(at:)``
- ``removeItem(atPath:)``

### Moving and copying items

- ``copyItem(at:to:)``
- ``copyItem(atPath:toPath:)``
- ``moveItem(at:to:)``
- ``moveItem(atPath:toPath:)``

### Working with symbolic and hard links

- ``createSymbolicLink(at:withDestinationURL:)``
- ``createSymbolicLink(atPath:withDestinationPath:)``
- ``linkItem(at:to:)``
- ``linkItem(atPath:toPath:)``
- ``destinationOfSymbolicLink(atPath:)``

### Determining access to files

- ``fileExists(atPath:)``
- ``fileExists(atPath:isDirectory:)``
- ``isReadableFile(atPath:)``
- ``isWritableFile(atPath:)``
- ``isExecutableFile(atPath:)``
- ``isDeletableFile(atPath:)``

### Getting and setting attributes

- ``attributesOfItem(atPath:)``
- ``setAttributes(_:ofItemAtPath:)``
- ``attributesOfFileSystem(forPath:)``

### Getting and comparing file contents

- ``contents(atPath:)``
- ``contentsEqual(atPath:andPath:)``

### Converting file paths to strings

- ``string(withFileSystemRepresentation:length:)``
- ``withFileSystemRepresentation(for:_:)``


### Working with a delegate

- ``delegate``

### Working with the current directory

- ``currentDirectoryPath``
- ``changeCurrentDirectoryPath(_:)``

### Supporting types

- ``DirectoryEnumerationOptions``
- ``FileAttributeKey``
- ``FileAttributeType``
- ``FileProtectionType``
- ``ItemReplacementOptions``
- ``UnmountOptions``
- ``URLRelationship``
