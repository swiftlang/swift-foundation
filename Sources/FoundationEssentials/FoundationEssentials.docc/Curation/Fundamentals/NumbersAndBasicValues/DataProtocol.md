# ``FoundationEssentials/DataProtocol``

## Topics

### Accessing backing storage

- ``regions``
- ``Regions``

### Copying underlying bytes

- ``copyBytes(to:)-(UnsafeMutableRawBufferPointer)``               <!-- @discardableResult func copyBytes(to ptr: UnsafeMutableRawBufferPointer) -> Int -->
- ``copyBytes(to:)-(UnsafeMutableBufferPointer<DestinationType>)`` <!-- @discardableResult func copyBytes<DestinationType>(to ptr: UnsafeMutableBufferPointer<DestinationType>) -> Int -->
- ``copyBytes(to:count:)-3sxf4``                                   <!-- @discardableResult func copyBytes(to: UnsafeMutableRawBufferPointer, count: Int) -> Int -->
- ``copyBytes(to:count:)-zacf``                                    <!-- @discardableResult func copyBytes<DestinationType>(to: UnsafeMutableBufferPointer<DestinationType>, count: Int) -> Int -->
- ``copyBytes(to:from:)-5xfiu``                                    <!-- @discardableResult func copyBytes<DestinationType, R>(to: UnsafeMutableBufferPointer<DestinationType>, from: R) -> Int where R : RangeExpression, Self.Index == R.Bound -->
- ``copyBytes(to:from:)-9uwtx``                                    <!-- @discardableResult func copyBytes<R>(to: UnsafeMutableRawBufferPointer, from: R) -> Int where R : RangeExpression, Self.Index == R.Bound -->


### Searching within data

- ``firstRange(of:)``
- ``firstRange(of:in:)``
- ``lastRange(of:)``
- ``lastRange(of:in:)``
