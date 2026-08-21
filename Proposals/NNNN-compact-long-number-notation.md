# Compact Long Number Notation

* Proposal: [SF-NNNN](NNNN-compact-long-number-notation.md)
* Authors: [Gary Wade](https://github.com/garywade)
* Review Manager: TBD
* Status: **Awaiting review**
* Implementation: TBD

## Introduction/Motivation

When formatting numbers, percents, or currencies, Foundation already supports a compact notation that abbreviates large values using locale-appropriate symbols or short suffixes:

```swift
let count = 1_500_000
let result = count.formatted(.number.notation(.compactName))
assert(result == "1.5M")
```

ICU's number-skeleton syntax supports two flavors of compact notation: `compact-short` (which `.compactName` already uses) and `compact-long`, which spells out the same magnitude using full unit names instead of abbreviated symbols, e.g. "1.5 million" instead of "1.5M". Foundation does not currently expose `compact-long`.

The long form is useful whenever an abbreviated symbol is ambiguous, unfamiliar, or simply less appropriate for the context than a spelled-out word — for example, some locales' abbreviated compact symbols are already combined or overloaded at very large magnitudes, where the spelled-out form reads more clearly.

## Proposed solution

Add a `compactLong` notation option alongside the existing `compactName` option, available anywhere `Notation` is used today (integer, floating-point, and currency format styles):

```swift
let compactLongFormatted = 1234.formatted(.number
    .locale(Locale(identifier: "en_US"))
    .notation(.compactLong)) // "1.2 thousand"
```

## Detailed design

```swift
extension NumberFormatStyleConfiguration.Notation {
    /// A locale-appropriate compact long name notation.
    ///
    /// A compact long name notation, when available in the format style's locale, that uses the full-length
    /// unit names corresponding to powers of ten, such as "thousand" or "million", instead of the abbreviated
    /// symbols that ``compactName`` uses. The following example shows a compact long name notation in the
    /// `en_US` locale:
    ///
    /// ```swift
    /// let compactLongFormatted = 1234.formatted(.number
    ///     .locale(Locale(identifier: "en_US"))
    ///     .notation(.compactLong)) // "1.2 thousand"
    /// ```
    ///
    /// - note: We do not support parsing a number string containing localized prefixes or suffixes.
    /// - note: When combined with a currency format style, this currently falls back to the same abbreviated
    ///   output as ``compactName``, since ICU does not yet provide long-form compact patterns for currency;
    ///   this is expected to improve as upstream ICU/CLDR gains that support.
    @available(FoundationPreview 6.6, *)
    public static var compactLong: Self { .init(option: .compactLong) }
}
```

Since `CurrencyFormatStyleConfiguration.Notation` is a `typealias` for `NumberFormatStyleConfiguration.Notation` (added in [SF-0008](0008-notation-formatting-for-currencies.md)), this single addition is automatically available to the integer, floating-point, and decimal currency format styles as well, with no further API surface needed:

```swift
let price = Decimal(1_500_000.59)
let result = price.formatted(.currency(code: "USD").notation(.compactLong))
assert(result == "$1.5M") // short-form fallback, not "$1.5 million" — see "Known limitation" below
```

Internally, this maps to ICU's `compact-long` number-skeleton stem, the direct sibling of the `compact-short` stem that `.compactName` already uses — no new ICU data or plumbing is required for the plain-number case.

### Known limitation: currency formatting falls back to short form

ICU/CLDR currently ships long-form (`patternsLong`) compact pattern data only for plain decimal formatting, not for currency formatting (only `patternsShort` exists for currencies, across all locales). As a result, `notation(.compactLong)` applied to a currency format style silently produces the same output as `notation(.compactName)` today (e.g. `"$1.5M"` rather than `"$1.5 million"`), rather than an error. This is an ICU/CLDR-level gap, not something this proposal's implementation can work around at the Foundation layer — there's no ICU skeleton combination that yields symbol-prefixed currency amounts with spelled-out magnitude words. Plain number and percent formatting are unaffected and get genuine long-form output.

This is called out explicitly in the API's documentation (see `Detailed design` above) so it isn't a silent surprise for adopters. Improving this is tracked as a future direction, contingent on upstream ICU/CLDR support.

## Source compatibility

This change is additive only and is not expected to have an impact on source compatibility.

## Implications on adoption

This new API will have `FoundationPreview 6.6` availability. This feature can be freely adopted and un-adopted in source code with no deployment constraints and without affecting source compatibility.

## Alternatives considered

**Naming it something other than `compactLong`.** `compactName` already establishes the "compact" + descriptor naming pattern for this family of options, so `compactLong` (paired with `compactName` remaining the short form) keeps the two symmetric and discoverable together, rather than introducing an unrelated name for the same family.

**Withholding this from currency format styles until ICU/CLDR gains long-form currency patterns.** Since `Notation` is shared via the `CurrencyFormatStyleConfiguration.Notation` typealias, restricting `compactLong` to only the non-currency format styles would require diverging that typealias relationship, adding real API surface and complexity to work around a temporary upstream data gap. Documenting the known fallback (see Detailed design) is simpler and keeps the option available and consistent across all format styles once ICU/CLDR does add the missing data — no follow-up API change would be needed at that point.

**Folding this into a broader "expose more ICU compact/currency options" proposal.** ICU also exposes other formatting options Foundation doesn't yet surface (e.g. the "cash" currency rounding behavior used by currencies like TWD that don't circulate sub-unit denominations in practice). That is a materially different, currency-rounding-behavior problem — orthogonal to notation — with its own open design question (how a developer would discover and choose between a cash-rounding configuration and the standard one) that has not yet reached consensus. Bundling it here would block this small, uncontroversial notation addition on an unrelated, unresolved design discussion. It's left as a future direction instead.

## Future directions

Exposing ICU's cash-currency rounding behavior (e.g. for currencies like TWD that are formally subdivided but never show fractional amounts in practice) is a natural follow-on, but is a separate proposal: it changes rounding behavior rather than adding a notation option, and needs its own design discussion about discoverability before it's ready to pitch.

Resolving the currency fallback described in "Known limitation" above requires no follow-up API change — once ICU/CLDR ships the missing data, `notation(.compactLong)` on currency format styles will automatically start producing genuine long-form output.

## Acknowledgments

Thanks to everyone who weighed in on the ICU compact-notation gaps that motivated this proposal.
