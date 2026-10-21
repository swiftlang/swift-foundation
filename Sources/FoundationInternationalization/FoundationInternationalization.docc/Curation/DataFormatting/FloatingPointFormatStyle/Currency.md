# ``/FoundationInternationalization/FloatingPointFormatStyle/Currency``


## Topics


### Creating a floating-point currency style

- ``init(code:locale:)``
- ``IntegerFormatStyle/Currency/localizedIntegerCurrency(code:locale:)``

### Customizing style behavior

- ``decimalSeparator(strategy:)``
- ``grouping(_:)``
- ``locale(_:)``
- ``notation(_:)``
- ``precision(_:)``
- ``presentation(_:)``
- ``rounded(rule:increment:)``
- ``scale(_:)``
- ``sign(strategy:)``
- ``Configuration``
- ``CurrencyFormatStyleConfiguration``

### Formatting floating-point currency values

- ``format(_:)``

### Creating attributed strings

- ``attributed``
- ``FloatingPointFormatStyle/Attributed``

### Accessing style properties

- ``currencyCode``
- ``locale``

### Applying list styles

- ``list(memberStyle:type:width:)``
- ``list(type:width:)``
- ``ListFormatStyle``

### Parsing floating-point currency values

- ``parseStrategy``

### Locating currency values in regular expressions

- ``regex``
- ``RegexOutput``
- ``consuming(_:startingAt:in:)``

### Encoding and decoding

- ``init(from:)``

