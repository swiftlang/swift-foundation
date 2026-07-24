# ``FoundationEssentials/URL``


## Topics

### Creating a URL from a string

- ``init(string:)``
- ``init(string:encodingInvalidCharacters:)``
- ``init(string:relativeTo:)``

### Creating a file URL from a string path

- ``init(filePath:directoryHint:relativeTo:)``
- ``DirectoryHint``
- ``init(fileURLWithPath:)``
- ``init(fileURLWithPath:isDirectory:)``
- ``init(fileURLWithPath:relativeTo:)``
- ``init(fileURLWithPath:isDirectory:relativeTo:)``
- ``init(fileURLWithFileSystemRepresentation:isDirectory:relativeTo:)``

### Creating a URL from a template

- ``init(template:variables:)``
- ``Template``

### Creating a file URL for a common directory

- ``FileManager/SearchPathDirectory``
- ``FileManager/SearchPathDomainMask``

### Accessing the parts of a URL

- ``fragment(percentEncoded:)``
- ``fragment``
- ``host(percentEncoded:)``
- ``host``
- ``lastPathComponent``
- ``path(percentEncoded:)``
- ``path``
- ``password(percentEncoded:)``
- ``password``
- ``pathComponents``
- ``pathExtension``
- ``port``
- ``query(percentEncoded:)``
- ``query``
- ``scheme``
- ``user(percentEncoded:)``
- ``user``

### Accessing URL representations

- ``baseURL``
- ``absoluteString``
- ``absoluteURL``
- ``relativePath``
- ``relativeString``
- ``standardized``
- ``standardizedFileURL``

### Working with the data representation of a URL

- ``init(dataRepresentation:relativeTo:isAbsolute:)``
- ``dataRepresentation``

### Working with file URLs

- ``isFileURL``
- ``hasDirectoryPath``
- ``withUnsafeFileSystemRepresentation(_:)``
- ``resolveSymlinksInPath()``
- ``resolvingSymlinksInPath()``
- ``standardize()``

### Accessing home and user directories

- ``currentDirectory()``
- ``homeDirectory``
- ``homeDirectory(forUser:)``

### Accessing common directories

- ``temporaryDirectory``

### Adding path components

- ``append(path:directoryHint:)``
- ``append(component:directoryHint:)``
- ``appendPathComponent(_:)``
- ``appendPathComponent(_:isDirectory:)``
- ``appending(path:directoryHint:)``
- ``appending(component:directoryHint:)``
- ``appendingPathComponent(_:)``
- ``appendingPathComponent(_:isDirectory:)``
- ``append(components:directoryHint:)``
- ``appending(components:directoryHint:)``

### Adding a path extension

- ``appendPathExtension(_:)``
- ``appendingPathExtension(_:)``

### Adding query items

- ``append(queryItems:)``
- ``appending(queryItems:)``
- ``URLQueryItem``

### Removing path components

- ``deleteLastPathComponent()``
- ``deletingLastPathComponent()``

### Removing a path extension

- ``deletePathExtension()``
- ``deletingPathExtension()``

### Comparing URLs

- ``==(_:_:)``
- ``!=(_:_:)``

### Hashing

- ``hash(into:)``

<!-- 
### Instance Properties

- ``absoluteString``
- ``absoluteURL``
- ``baseURL``
- ``dataRepresentation``
- ``fragment``
- ``hasDirectoryPath``
- ``host``
- ``isFileURL``
- ``lastPathComponent``
- ``password``
- ``path``
- ``pathComponents``
- ``pathExtension``
- ``port``
- ``query``
- ``relativePath``
- ``relativeString``
- ``scheme``
- ``standardized``
- ``standardizedFileURL``
- ``user``

### Instance Methods

- ``append(component:directoryHint:)``
- ``append(components:directoryHint:)``
- ``append(path:directoryHint:)``
- ``append(queryItems:)``
- ``appendPathComponent(_:)``
- ``appendPathComponent(_:isDirectory:)``
- ``appendPathExtension(_:)``
- ``appending(component:directoryHint:)``
- ``appending(components:directoryHint:)``
- ``appending(path:directoryHint:)``
- ``appending(queryItems:)``
- ``appendingPathComponent(_:)``
- ``appendingPathComponent(_:isDirectory:)``
- ``appendingPathExtension(_:)``
- ``deleteLastPathComponent()``
- ``deletePathExtension()``
- ``deletingLastPathComponent()``
- ``deletingPathExtension()``
- ``fragment(percentEncoded:)``
- ``hash(into:)``
- ``host(percentEncoded:)``
- ``password(percentEncoded:)``
- ``path(percentEncoded:)``
- ``query(percentEncoded:)``
- ``resolveSymlinksInPath()``
- ``resolvingSymlinksInPath()``
- ``standardize()``
- ``user(percentEncoded:)``
- ``withUnsafeFileSystemRepresentation(_:)``

### Type Properties

- ``homeDirectory``
- ``temporaryDirectory``

### Type Methods

- ``currentDirectory()``
- ``homeDirectory(forUser:)``

### Enumerations

- ``DirectoryHint``
-->
