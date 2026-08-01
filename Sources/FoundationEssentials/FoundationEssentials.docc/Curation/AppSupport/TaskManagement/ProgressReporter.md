# ``/FoundationEssentials/ProgressReporter``


## Topics

### Inspecting progress 

- ``totalCount``
- ``completedCount``
- ``fractionCompleted``
- ``isIndeterminate``
- ``isFinished``

### Working with progress properties

- ``subscript(dynamicMember:)->Int``      <!-- subscript<P>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> Int where P : ProgressManager.Property, P.Summary == Int, P.Value == Int { get } -->
- ``subscript(dynamicMember:)->P.Value``  <!-- subscript<P>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> P.Value where P : ProgressManager.Property, P.Summary == Double, P.Value == Double { get } -->
- ``subscript(dynamicMember:)->Duration`` <!-- subscript<P>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> Duration where P : ProgressManager.Property, P.Summary == Duration, P.Value == Duration { get } -->
- ``subscript(dynamicMember:)-9h12w``     <!-- subscript<P>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> UInt64 where P : ProgressManager.Property, P.Summary == UInt64, P.Value == UInt64 { get } -->
- ``subscript(dynamicMember:)-3mn8d``     <!-- subscript<P>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> UInt64 where P : ProgressManager.Property, P.Summary == [UInt64], P.Value == UInt64 { get } -->
- ``subscript(dynamicMember:)->String?``  <!-- subscript<P>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> String? where P : ProgressManager.Property, P.Summary == [String?], P.Value == String? { get } -->
- ``subscript(dynamicMember:)->URL?``     <!-- subscript<P>(dynamicMember key: KeyPath<ProgressManager.Properties, P.Type>) -> URL? where P : ProgressManager.Property, P.Summary == [URL?], P.Value == URL? { get } -->
- ``Property``

### Summarizing progress

- ``summary(of:)->Int``       <!-- func summary<P>(of property: KeyPath<ProgressManager.Properties, P.Type>) -> Int where P : ProgressManager.Property, P.Summary == Int, P.Value == Int -->
- ``summary(of:)->Double``    <!-- func summary<P>(of property: KeyPath<ProgressManager.Properties, P.Type>) -> Double where P : ProgressManager.Property, P.Summary == Double, P.Value == Double -->
- ``summary(of:)->Duration``  <!-- func summary<P>(of property: KeyPath<ProgressManager.Properties, P.Type>) -> Duration where P : ProgressManager.Property, P.Summary == Duration, P.Value == Duration -->
- ``summary(of:)->UInt64``    <!-- func summary<P>(of property: KeyPath<ProgressManager.Properties, P.Type>) -> UInt64 where P : ProgressManager.Property, P.Summary == UInt64, P.Value == UInt64 -->
- ``summary(of:)->[UInt64]``  <!-- func summary<P>(of property: KeyPath<ProgressManager.Properties, P.Type>) -> [UInt64] where P : ProgressManager.Property, P.Summary == [UInt64], P.Value == UInt64 -->
- ``summary(of:)->[String?]`` <!-- func summary<P>(of property: KeyPath<ProgressManager.Properties, P.Type>) -> [String?] where P : ProgressManager.Property, P.Summary == [String?], P.Value == String? -->
- ``summary(of:)->[URL?]``    <!-- func summary<P>(of property: KeyPath<ProgressManager.Properties, P.Type>) -> [URL?] where P : ProgressManager.Property, P.Summary == [URL?], P.Value == URL? -->

### Comparing progress reporters

- ``==(_:_:)``

### Describing the progress reporter

- ``description``
- ``debugDescription``

### Hashing

- ``hash(into:)``
