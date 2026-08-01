# ``/FoundationEssentials/PropertyListEncoder``


## Topics

### Creating an encoder

- ``init()``

### Encoding

- ``encode(_:)``

### Customizing encoding

- ``outputFormat``
- ``userInfo``

### Encoding with a configuration

- ``encode(_:configuration:)-(_,T.EncodingConfiguration)`` <!-- func encode<T>(_ value: T, configuration: T.EncodingConfiguration) throws -> Data where T : EncodableWithConfiguration -->
- ``encode(_:configuration:)-(_,C.Type)``                  <!-- func encode<T, C>(_ value: T, configuration: C.Type) throws -> Data where T : EncodableWithConfiguration, C : EncodingConfigurationProviding, T.EncodingConfiguration == C.EncodingConfiguration -->
