# ``/FoundationEssentials/PropertyListDecoder``

<!-- The content below this line is auto-generated and is redundant. You should either incorporate it into your content above this line or delete it. -->

## Topics

### Creating a decoder

- ``init()``

### Decoding

- ``decode(_:from:)``
- ``decode(_:from:format:)``
- ``PropertyListFormat-enum``

### Customizing decoding

- ``userInfo``

### Decoding with a configuration

- ``decode(_:from:configuration:)-(_,_,C.Type)``                           <!-- func decode<T, C>(_ type: T.Type, from data: Data, configuration: C.Type) throws -> T where T : DecodableWithConfiguration, C : DecodingConfigurationProviding, T.DecodingConfiguration == C.DecodingConfiguration -->
- ``decode(_:from:configuration:)-(_,_,T.DecodingConfiguration)``          <!-- func decode<T>(_ type: T.Type, from data: Data, configuration: T.DecodingConfiguration) throws -> T where T : DecodableWithConfiguration -->
- ``decode(_:from:format:configuration:)-(_,_,_,T.DecodingConfiguration)`` <!-- func decode<T>(_ type: T.Type, from data: Data, format: inout PropertyListDecoder.PropertyListFormat, configuration: T.DecodingConfiguration) throws -> T where T : DecodableWithConfiguration -->
- ``decode(_:from:format:configuration:)-(_,_,_,C.Type)``                  <!-- func decode<T, C>(_ type: T.Type, from data: Data, format: inout PropertyListDecoder.PropertyListFormat, configuration: C.Type) throws -> T where T : DecodableWithConfiguration, C : DecodingConfigurationProviding, T.DecodingConfiguration == C.DecodingConfiguration -->

