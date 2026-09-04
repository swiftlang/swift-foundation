# ``FoundationEssentials/Decimal``

## Topics


### Creating an empty decimal

- ``init()``

### Creating a decimal from components

- ``init(sign:exponent:significand:)``

### Creating a decimal from a floating-point number

- ``init(_:)-31n60``
- ``init(floatLiteral:)``
- ``init(_:)-(Double)``                                          <!-- init(_ value: Double) -->

### Creating a decimal from an integer

- ``init(_:)-1u803``
- ``init(exactly:)``
- ``init(integerLiteral:)``
- ``init(_:)-(Int)``                                             <!-- init(_ value: Int) -->
- ``init(_:)-(Int8)``                                            <!-- init(_ value: Int8) -->
- ``init(_:)-(Int16)``                                           <!-- init(_ value: Int16) -->
- ``init(_:)-(Int32)``                                           <!-- init(_ value: Int32) -->
- ``init(_:)-(Int64)``                                           <!-- init(_ value: Int64) -->

### Creating a decimal from an unsigned integer

- ``init(_:)-(UInt)``                                            <!-- init(_ value: UInt) -->
- ``init(_:)-(UInt8)``                                           <!-- init(_ value: UInt8) -->
- ``init(_:)-(UInt16)``                                          <!-- init(_ value: UInt16) -->
- ``init(_:)-(UInt32)``                                          <!-- init(_ value: UInt32) -->
- ``init(_:)-(UInt64)``                                          <!-- init(_ value: UInt64) -->

### Creating a decimal from another decimal

- ``init(signOf:magnitudeOf:)``

### Creating a decimal by parsing a string

- ``init(string:locale:)``

### Performing arithmetic

- ``+(_:_:)``
- ``+=(_:_:)``
- ``-(_:_:)``
- ``-=(_:_:)``
- ``*(_:_:)``
- ``*=(_:_:)``
- ``/(_:_:)``
- ``/=(_:_:)``
- ``pow(_:_:)``

### Getting a decimal's characteristics

- ``sign``
- ``exponent``
- ``significand``
- ``magnitude``
- ``floatingPointClass``
- ``isCanonical``
- ``isFinite``
- ``isInfinite``
- ``isNaN``
- ``isNormal``
- ``isSignMinus``
- ``isSignaling``
- ``isSignalingNaN``
- ``isSubnormal``
- ``isZero``
- ``nextDown``
- ``nextUp``
- ``ulp``

### Getting particular decimals

- ``greatestFiniteMagnitude``
- ``leastFiniteMagnitude``
- ``leastNonzeroMagnitude``
- ``leastNormalMagnitude``
- ``pi``
- ``nan``
- ``quietNaN``
- ``radix``

### Comparing decimals

- ``isEqual(to:)``
- ``isLess(than:)``
- ``isLessThanOrEqualTo(_:)``
- ``isTotallyOrdered(belowOrEqualTo:)``
- ``distance(to:)``
- ``advanced(by:)``

### Encoding and decoding

- ``init(from:)``

### Describing a decimal

- ``description``

### Supporting types

- ``CalculationError``
- ``RoundingMode``
