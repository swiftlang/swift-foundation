# ``FoundationInternationalization/FoundationEssentials/FormatStyle``

Methods and properties that extend the FoundationEssentials format style type.



## Topics

### Applying numeric styles for integers

- ``number-lcr9``   <!-- static var number: IntegerFormatStyle<Int> { get } -->
- ``number-487t``   <!-- static var number: IntegerFormatStyle<UInt> { get } -->
- ``number-yun5``   <!-- static var number: IntegerFormatStyle<Int8> { get } -->
- ``number-9bg9h``  <!-- static var number: IntegerFormatStyle<UInt8> { get } -->
- ``number-7i3u4``  <!-- static var number: IntegerFormatStyle<Int16> { get } -->
- ``number-6yy7j``  <!-- static var number: IntegerFormatStyle<UInt16> { get } -->
- ``number-1ckr8``  <!-- static var number: IntegerFormatStyle<Int32> { get } -->
- ``number-jpax``   <!-- static var number: IntegerFormatStyle<UInt32> { get } -->
- ``number-45bcj``  <!-- static var number: IntegerFormatStyle<Int64> { get } -->
- ``number-941kj``  <!-- static var number: IntegerFormatStyle<UInt64> { get } -->

### Applying numeric styles for floating-point values

- ``number-3uj64``  <!-- static var number: FloatingPointFormatStyle<Float> { get } -->
- ``number-68g5v``  <!-- static var number: FloatingPointFormatStyle<Double> { get } -->
- ``number-4o6vr``  <!-- static var number: FloatingPointFormatStyle<Float16> { get } -->

### Applying numeric styles for decimals

- ``number-90oqn``  <!-- static var number: Decimal.FormatStyle { get } -->

### Applying percentage styles for integers``

- ``percent-5w7qa`` <!-- static var percent: IntegerFormatStyle<Int>.Percent { get } -->
- ``percent-25orb`` <!-- static var percent: IntegerFormatStyle<UInt>.Percent { get } -->
- ``percent-5kn56`` <!-- static var percent: IntegerFormatStyle<Int8>.Percent { get } -->
- ``percent-430ba`` <!-- static var percent: IntegerFormatStyle<UInt8>.Percent { get } -->
- ``percent-1ht3n`` <!-- static var percent: IntegerFormatStyle<Int16>.Percent { get } -->
- ``percent-2hbwe`` <!-- static var percent: IntegerFormatStyle<UInt16>.Percent { get } -->
- ``percent-2jpr``  <!-- static var percent: IntegerFormatStyle<Int32>.Percent { get } -->
- ``percent-4dmvr`` <!-- static var percent: IntegerFormatStyle<UInt32>.Percent { get } -->
- ``percent-4dcmu`` <!-- static var percent: IntegerFormatStyle<Int64>.Percent { get } -->
- ``percent-jfh6``  <!-- static var percent: IntegerFormatStyle<UInt64>.Percent { get } -->


### Applying percentage styles for floating-point values``

- ``percent-5bvv7`` <!-- static var percent: FloatingPointFormatStyle<Float>.Percent { get } -->
- ``percent-23opr`` <!-- static var percent: FloatingPointFormatStyle<Double>.Percent { get } -->
- ``percent-13e3d`` <!-- static var percent: FloatingPointFormatStyle<Float16>.Percent { get } -->

### Applying percentage styles for decimals``

- ``percent-7bdy8`` <!-- static var percent: Decimal.FormatStyle.Percent { get } -->
- ``Decimal/FormatStyle/Percent``

### Applying date and time styles 

- ``time(pattern:)``
- ``dateTime``
- ``Date/FormatStyle``
- ``interval``
- ``Date/IntervalFormatStyle``
- ``relative(presentation:unitsStyle:)``
- ``Date/RelativeFormatStyle``
- ``verbatim(_:locale:timeZone:calendar:)``
- ``Date/VerbatimFormatStyle``

### Applying duration styles

- ``units(allowed:width:maximumUnitCount:zeroValueUnits:valueLength:fractionalPart:)``
- ``units(allowed:width:maximumUnitCount:zeroValueUnits:valueLengthLimits:fractionalPart:)``


### Applying currency styles 

- ``currency(code:)-yeeu``                                                                   <!-- static func currency(code: String) -> Self -->
- ``currency(code:)-9j47r``                                                                  <!-- static func currency<V>(code: String) -> Self where Self == IntegerFormatStyle<V>.Currency, V : BinaryInteger -->
- ``currency(code:)-4ngfi``                                                                  <!-- static func currency<Value>(code: String) -> Self where Self == FloatingPointFormatStyle<Value>.Currency, Value : BinaryFloatingPoint -->

### Applying list styles

- ``list(memberStyle:type:width:)``
- ``list(type:width:)``

### Applying byte count styles

- ``byteCount(style:allowedUnits:spellsOutZero:includesActualByteCount:)``
- ``ByteCountFormatStyle``

### Applying URL format styles

- ``url``

