# ``/FoundationEssentials/JSONDecoder``


## Topics

### Creating a decoder

- ``init()``

### Decoding

- ``decode(_:from:)``

### Customizing decoding

- ``keyDecodingStrategy``
- ``KeyDecodingStrategy``
- ``userInfo``
- ``allowsJSON5``
- ``assumesTopLevelDictionary``

### Decoding dates

- ``dateDecodingStrategy``
- ``DateDecodingStrategy``

### Decoding raw data

- ``dataDecodingStrategy``
- ``DataDecodingStrategy``

### Decoding exceptional numbers

- ``nonConformingFloatDecodingStrategy``
- ``NonConformingFloatDecodingStrategy``

### Decoding with a configuration

- ``decode(_:from:configuration:)-(_,_,C.Type)``                  <!-- func decode<T, C>(_ type: T.Type, from data: Data, configuration: C.Type) throws -> T where T : DecodableWithConfiguration, C : DecodingConfigurationProviding, T.DecodingConfiguration == C.DecodingConfiguration -->
- ``decode(_:from:configuration:)-(_,_,T.DecodingConfiguration)`` <!-- func decode<T>(_ type: T.Type, from data: Data, configuration: T.DecodingConfiguration) throws -> T where T : DecodableWithConfiguration -->

