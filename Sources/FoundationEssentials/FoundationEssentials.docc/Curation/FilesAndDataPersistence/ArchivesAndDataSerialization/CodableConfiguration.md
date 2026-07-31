# ``/FoundationEssentials/CodableConfiguration``


## Topics

### Creating a codable configuration

- ``init(wrappedValue:)``
- ``init(wrappedValue:from:)-(_,ConfigurationProvider.Type)``                          <!-- init(wrappedValue: T, from configurationProvider: ConfigurationProvider.Type) -->
- ``init(wrappedValue:from:)-(_,KeyPath<AttributeScopes,ConfigurationProvider.Type>)`` <!-- init(wrappedValue: T, from keyPath: KeyPath<AttributeScopes, ConfigurationProvider.Type>) -->

### Accessing the wrapped value

- ``wrappedValue``

### Encoding and decoding

- ``init(from:)``
- ``encode(to:)``
