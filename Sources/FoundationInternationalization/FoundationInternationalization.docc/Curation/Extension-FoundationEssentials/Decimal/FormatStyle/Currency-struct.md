# ``FoundationInternationalization/FoundationEssentials/Decimal/FormatStyle/Currency``


## Topics


### Creating a decimal currency style

- ``init(code:locale:)``
- ``localizedCurrency(code:locale:)``

### Customizing style behavior

- ``decimalSeparator(strategy:)``
- ``grouping(_:)``
- ``locale(_:)``
- ``precision(_:)``
- ``presentation(_:)``
- ``rounded(rule:increment:)``
- ``scale(_:)``
- ``sign(strategy:)``
- ``notation(_:)``
- ``Configuration``
- ``CurrencyFormatStyleConfiguration``

### Formatting decimal currency values

- ``format(_:)``

### Creating attributed strings

- ``attributed``
- ``Decimal/FormatStyle/Attributed``

### Accessing style properties

- ``currencyCode``
- ``locale``

### Applying currency styles

- ``currency(code:)-2m7zy``
- ``currency(code:)-6v4yv``

### Applying measurement styles

- ``measurement(width:usage:numberFormatStyle:)``
- ``measurement(width:usage:hidesScaleName:numberFormatStyle:)``

### Applying list styles

- ``list(memberStyle:type:width:)``
- ``list(type:width:)``

### Parsing decimal currency values

- ``parseStrategy``

### Locating currency values in regular expressions

- ``regex``
- ``RegexOutput``
- ``consuming(_:startingAt:in:)``

