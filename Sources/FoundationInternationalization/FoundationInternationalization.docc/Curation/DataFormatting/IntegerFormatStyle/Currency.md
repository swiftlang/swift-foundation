# ``/FoundationInternationalization/IntegerFormatStyle/Currency``


## Topics



### Creating an integer currency format style

- ``init(code:locale:)``
- ``localizedIntegerCurrency(code:locale:)``

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

### Formatting integer currency values

- ``format(_:)``

### Creating attributed strings

- ``attributed``
- ``IntegerFormatStyle/Attributed``

### Accessing style properties

- ``currencyCode``
- ``locale``


### Applying measurement styles

- ``Measurement/FormatStyle``

### Applying list styles

- ``list(memberStyle:type:width:)``
- ``list(type:width:)``

### Parsing integer currency values

- ``parseStrategy``

### Locating currency values in regular expressions

- ``regex``
- ``RegexOutput``
- ``consuming(_:startingAt:in:)``

### Encoding and decoding

- ``init(from:)``
