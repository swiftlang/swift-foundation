# Data formatting

Convert numbers, dates, measurements, and other values to and from locale-aware string representations.

FoundationEssentials defines the ``FormatStyle`` protocol to establish conventions for formatting a given type as some kind of output type, typically a `String`.
Similarly, the ``ParseStrategy`` protocol provides an API for converting a representation back to the represented type, such as converting a numeric string to an `Int` or ``Decimal``.

While FoundationEssentials defines the core protocols, most implementations of ``FormatStyle`` and ``ParseStrategy`` exist in the `FoundationInternationalization` module.
`FoundationInternationalization` also extends types in both `FoundationEssentials` and the Swift Standard Library to add formatting and parsing support.

When you import `FoundationInternationalization`, you have two general approaches to perform formatting of supported types:

* Call `formatted()` or `formatted(_:)` on an instance of the type, optionally passing in a customized `FormatStyle` appropriate to the type. These methods, defined by extensions in `FoundationInternationalization`, are useful for performing one-off formatting with default styles or slightly-customized styles. For example, `var string123 = Double(1.23).formatted()` creates the string `1.23`.
* Call `format(_:)` on an instance of the `FormatStyle`, passing in the type you want to format. This method, defined by the `FormatStyle` itself, makes sense when you customize a style and want to format many instances with it. For example, `var string456 = FloatingPointFormatStyle<Double>().format(4.56)` creates the string `4.56`.

The arrangement is similar with parsing:

* Call `init(strategy:)` or `init(_:format:lenient:)` to create instance of a type from its formatted representation. For example, to create a `Double` from the string `1.23`, you could use `var oneTwoThree = try Double("1.23", format: FloatingPointFormatStyle<Double>())`.
* Call `parse(_:)` on an instance of the `ParseStrategy` to initialize an instance of the output type. For example, `var fourFiveSix = try FloatingPointFormatStyle<Double>().parseStrategy.parse("4.56")` creates a `Double` equal to `4.56`.

## Topics

### Data formatting

- ``FormatStyle``
- ``DiscreteFormatStyle``
- ``ParseableFormatStyle``

### Data parsing

- ``ParseableFormatStyle``
- ``ParseStrategy``
