# ``/FoundationEssentials/URLComponents``


## Topics


### Creating URL components

- ``init()``
- ``init(string:)``
- ``init(string:encodingInvalidCharacters:)``
- ``init(url:resolvingAgainstBaseURL:)``

### Getting the URL

- ``url``
- ``url(relativeTo:)``
- ``string``

### Accessing components in native format

- ``fragment``
- ``host``
- ``encodedHost``
- ``password``
- ``path``
- ``port``
- ``query``
- ``queryItems``
- ``scheme``
- ``user``

### Accessing components in URL-encoded format

- ``percentEncodedFragment``
- ``percentEncodedHost``
- ``percentEncodedPassword``
- ``percentEncodedPath``
- ``percentEncodedQuery``
- ``percentEncodedQueryItems``
- ``percentEncodedUser``

### Locating components in the URL string representation
- ``rangeOfFragment``
- ``rangeOfHost``
- ``rangeOfPassword``
- ``rangeOfPath``
- ``rangeOfPort``
- ``rangeOfQuery``
- ``rangeOfScheme``
- ``rangeOfUser``

### Comparing URL components

- ``==(_:_:)``

### Hashing

- ``hash(into:)``

### Supporting types

- ``URLQueryItem``
