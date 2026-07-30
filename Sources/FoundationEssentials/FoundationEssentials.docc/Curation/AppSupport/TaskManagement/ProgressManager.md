# ``/FoundationEssentials/ProgressManager``

## Topics

### Protocols


### Creating a progress manager

- ``init(totalCount:)``

### Inspecting progress 

- ``totalCount``
- ``completedCount``
- ``fractionCompleted``
- ``isIndeterminate``
- ``isFinished``

### Reporting progress

- ``reporter``

### Adjusting progress

- ``complete(count:)``
- ``setCounts(_:)``

### Working with progress properties

- ``subscript(dynamicMember:)->Int``      <!-- subscript<P>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> Int where P : ProgressManager.Property, P.Summary == Int, P.Value == Int { get set } -->
- ``subscript(dynamicMember:)->P.Value``  <!-- subscript<P>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> P.Value where P : ProgressManager.Property, P.Summary == Double, P.Value == Double { get set } -->
- ``subscript(dynamicMember:)->Duration`` <!-- subscript<P>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> Duration where P : ProgressManager.Property, P.Summary == Duration, P.Value == Duration { get set } -->
- ``subscript(dynamicMember:)-92r6b``     <!-- subscript<P>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> UInt64 where P : ProgressManager.Property, P.Summary == UInt64, P.Value == UInt64 { get set } -->
- ``subscript(dynamicMember:)-her7``      <!-- subscript<P>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> UInt64 where P : ProgressManager.Property, P.Summary == [UInt64], P.Value == UInt64 { get set } -->
- ``subscript(dynamicMember:)->String?``  <!-- subscript<P>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> String? where P : ProgressManager.Property, P.Summary == [String?], P.Value == String? { get set } -->
- ``subscript(dynamicMember:)->URL?``     <!-- subscript<P>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> URL? where P : ProgressManager.Property, P.Summary == [URL?], P.Value == URL? { get set } -->
- ``Property``
- ``Properties``

### Working with other progress reporters

- ``subprogress(assigningCount:)``
- ``Subprogress``
- ``assign(count:to:)``

### Summarizing progress

- ``summary(of:)-7hs91``           <!-- func summary<P>(of property: KeyPath<ProgressManager.Properties, P.Type>) -> P.Summary where P : ProgressManager.Property, P.Summary == Int, P.Value == Int -->
- ``summary(of:)-78m4y``           <!-- func summary<P>(of property: KeyPath<ProgressManager.Properties, P.Type>) -> P.Summary where P : ProgressManager.Property, P.Summary == Double, P.Value == Double -->
- ``summary(of:)-9b5r0``           <!-- func summary<P>(of property: KeyPath<ProgressManager.Properties, P.Type>) -> P.Summary where P : ProgressManager.Property, P.Summary == Duration, P.Value == Duration -->
- ``summary(of:)-38wdy``           <!-- func summary<P>(of property: KeyPath<ProgressManager.Properties, P.Type>) -> P.Summary where P : ProgressManager.Property, P.Summary == UInt64, P.Value == UInt64 -->
- ``summary(of:)-8nal7``           <!-- func summary<P>(of property: KeyPath<ProgressManager.Properties, P.Type>) -> P.Summary where P : ProgressManager.Property, P.Summary == [UInt64], P.Value == UInt64 -->
- ``summary(of:)-4tfj5``           <!-- func summary<P>(of property: KeyPath<ProgressManager.Properties, P.Type>) -> P.Summary where P : ProgressManager.Property, P.Summary == [String?], P.Value == String? -->
- ``summary(of:)-7lkjk``           <!-- func summary<P>(of property: KeyPath<ProgressManager.Properties, P.Type>) -> P.Summary where P : ProgressManager.Property, P.Summary == [URL?], P.Value == URL? -->
