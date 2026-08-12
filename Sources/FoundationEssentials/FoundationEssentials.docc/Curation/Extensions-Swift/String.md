# ``Swift/String``

Methods that extend the Swift string type.

## Overview

Foundation adds support for creating Swift strings from ``AttributedString`` and related types. It also adds support for initializing a string from the contents of a URL, a file indicated by a path, a ``Data`` instance, or a sequence of bytes.

## Topics

### Creating a string from an attributed string

- ``init(_:)-(AttributedString.CharacterView)``
- ``init(_:)-(Slice<AttributedString.CharacterView>)``

### Creating a string from data

- ``init(data:encoding:)``
- ``init(bytes:encoding:)``

### Creating a string from a URL

- ``init(contentsOf:encoding:)``
- ``init(contentsOf:usedEncoding:)``
- ``init(_:)-(URL.Template.VariableName)``

### Creating a string from a file path

- ``init(contentsOfFile:encoding:)``
- ``init(contentsOfFile:usedEncoding:)``

### Retrieving data from a string

- ``data(using:allowLossyConversion:)``

### Supporting types

- ``CompareOptions``
- ``Encoding``
- ``Index``
