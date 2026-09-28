# ``Swift/StringProtocol``

Methods and properties that extend the Swift string protocol.


## Overview

Foundation extends the Swift string protocol type by adding convenient features, including:

* Writing the contents of the string to a file indicated by a ``URL`` or a string path.
* Returning ranges of the string representing lines or paragraphs.
* Converting the contents of the string to a ``Data`` instance.

## Topics

### Writing string contents to a file

- ``write(to:atomically:encoding:)``
- ``write(toFile:atomically:encoding:)``

### Finding ranges

- ``lineRange(for:)``
- ``paragraphRange(for:)``

### Retrieving string contents

- ``data(using:allowLossyConversion:)``
- ``components(separatedBy:)``

### Applying capitalization

- ``capitalized``
