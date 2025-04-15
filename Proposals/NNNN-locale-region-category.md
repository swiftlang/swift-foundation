# `Locale.Region.Category` 

* Proposal: [SF-NNNN](NNNN-locale-region-category.md)
* Authors: [Tina Liu](https://github.com/itingliu)
* Review Manager: TBD
* Status: **Awaiting review**

## Introduction

Currently, `Locale.Region` offers a few functionalities to query information about a region:

```swift
extension Locale.Region {
    /// An array of regions defined by ISO.
    public static var isoRegions: [Locale.Region]
    
    /// The region that contains this region, if any.
    public var containingRegion: Locale.Region? { get }
    
    /// The continent that contains this region, if any.
    public var continent: Locale.Region? { get }
    
    /// An array of all the sub-regions of the region.
    public var subRegions: [Locale.Region] { get }
}
```

Here are some examples of how you can use it:

```swift
let argentina = Locale.Region.argentina

_ = argentina.continent // "019" (Americas)
_ = argentina.containingRegion // "005" (South America)
```

We'd like to propose extending `Locale.Region` to support grouping the return result by types, such as whether it's a territory or continent. 

One use case for this is for UI applications to display supported regions or offer UI to select a region, similar to the Language & Region system settings on mac and iOS. Instead of showing all supported regions returned by `Locale.Region.isoRegions` as a flat list, clients will be able to have a hierarchical list that groups the regions by types such as continents.

## Proposed solution and example

We propose adding `struct Locale.Region.Category` to represent different categories of `Locale.Region`, and companion methods to return results matching the specified category. There are also a few existing API that provides information about the region. We propose adding `subcontinent` to complement the existing `.continent` property.

You can use it to get regions of specific categories:

```swift
let argentina = Locale.Region.argentina
_ = argentina.category // .territory
_ = argentina.subcontinent // "005" (South America)

let americas = Locale.Region("019")
_ = americas.category // .continent
_ = americas.subRegions(ofCategory: .subcontinent) // All subcontinents in Americas: ["005", "013", "021", "029"] (South America, Central America, Northern America, Caribbean)
_ = americas.subRegions(ofCategory: .territory) // All territories in Americas

_ = Locale.Region.isoRegions(ofCategory: .continent) // All continents: ["002", "009", "019", "142", "150"] (Africa, Oceania, Americas, Asia, Europe)
```


## Detailed design

```swift
@available(FoundationPreview 6.2, *)
extension Locale.Region {

    /// Categories of a region. See https://www.unicode.org/reports/tr35/tr35-35/tr35-info.html#Territory_Data
    public struct Category: Codable, Sendable, Hashable, CustomDebugStringConvertible {
        /// Category representing the whole world.
        public static let world: Category

        /// Category representing a continent, regions contained directly by world.
        public static let continent: Category

        /// Category representing a sub-continent, regions contained directly by a continent. 
        public static let subcontinent: Category

        /// Category representing a territory.
        public static let territory: Category

        /// Category representing a grouping, regions that has a well defined membership.
        public static let grouping: Category
    }
    
    /// An array of regions matching the specified categories.
    public static func isoRegions(ofCategory category: Category) -> [Locale.Region]
    
    /// The category of the region, if any.
    public var category: Category? { get }

    /// An array of the sub-regions, matching the specified category of the region.
    /// If `category` is higher in the hierarchy than `self`, returns an empty array.
    public func subRegions(ofCategory category: Category) -> [Locale.Region]
    
    /// The subcontinent that contains this region, if any.
    public var subcontinent: Locale.Region?
}
```

### `Locale.Region.Category`

This type represents the territory containment levels as defined in [Unicode LDML #35](https://www.unicode.org/reports/tr35/tr35-35/tr35-info.html#Territory_Data). An overview of the latest categorization is available [here](https://www.unicode.org/cldr/charts/46/supplemental/territory_containment_un_m_49.html). 

Currently, `.world` is only associated with `Locale.Region("001")`. `.territory` includes, but is not limited to, countries, as it also includes regions such as Antarctica (code "AQ"). `.grouping` is a region that has well defined membership, such as European Union (code "EU") and Eurozone (code "EZ"). It isn't part of the hierarchy formed by other categories. 

### Getting sub-regions matching the specified category

```swift
extension Locale.Region {
    public func subRegions(ofCategory category: Category) -> [Locale.Region]
}
```

If the value is higher up in the hierarchy than that of `self`, the function returns an empty array. 

```swift
argentina.subRegions(in: .world) // []
```

On the other hand, the specified `category` that is more than one level down than that of `self` is still valid, as seen previously in the ["Proposed solution and example" section](#proposed-solution-and-example)

```swift
// Passing both `.subcontinent` and `.territory` as the argument are valid
_ = americas.subRegions(ofCategory: .subcontinent)  // All subcontinents in Americas
_ = americas.subRegions(ofCategory: .territory) // All territories in Americas
```

## Impact on existing code

### `Locale.Region.isoRegions` starts to include regions of the "grouping" category

Currently `Locale.Region.isoRegions` does not return regions that fall into the `.grouping` category. Those fall under the grouping category don't fit into the tree-structured containment hierarchy like the others. Given that it is not yet possible to filter ISO regions by category, these regions are not included in the return values of API.

With the introduction of `Locale.Region.isoRegions(ofCategory:)`, we propose changing the behavior of `Locale.Region.isoRegions` to include all ISO regions, including those of the grouping category. Those who wish to exclude those of the "grouping" category can do so with `Locale.Region.isoRegions(of:)`.

Please refer to the Alternative Considered section for more discussion.

## Alternatives considered

### Naming consideration: `Locale.Region.Category`

ICU uses `URegionType` to represent the categories, while Unicode uses the term "territory containment (level)". We considered introducing `Category` as `Type`, `Containment`, `ContainmentLevel`, or `GroupingLevel`. 

`Type` was not the optimal choice because not only it is a language keyword, but also overloaded. `Containment`, `ContainmentLevel` or `GroupingLevel` would all be good fits for modeling regions as a tree hierarchy, but we never intend to force the hierarchy idea onto `Locale.Region`, and the "grouping" category is not strictly a containment level either.

`Category` shares similar meanings to `Type`, with less strict containment notion, and is typically used in API names. 

### Introduce `containingRegion(ofCategory:)` 

An alternative is to introduce a method such as `containingRegion(ofCategory:)` to return the containing region of the specified category:

```swift
extension Locale.Region {
    /// The containing region, matching the specified category of the region.
    public func containingRegion(ofCategory category: Category) -> Locale.Region?
} 
```

Developers would use it like this:
 
```swift
// The continent containing Argentina, equivalent to `argentina.continent`
_ = argentina.containingRegion(ofCategory: .continent) // "019" (Americas)

// The sub-continent containing Argentina, equivalent to `argentina.subcontinent`
_ = argentina.containingRegion(ofCategory: .subcontinent) // "005" (South America)
```

Functionally it would be equivalent to existing `public var continent: Locale.Region?`. Having two entry points for the same purpose would be more confusing than helpful, so it was left out for simplicity.

### Naming consideration: `ofCategory` argument label

Since the "category" in the argument label in the proposed functions is the name of the type, it would be acceptable to omit it from the label, so 

```swift
public func subRegions(ofCategory category: Category) -> [Locale.Region]
```

would become

```swift
public func subRegions(of category: Category) -> [Locale.Region]
```

However, this reads less fluent from the call-site:

```swift
let continent = Locale.Region(<some continentCode>)
let territories = continent.subRegions(of: .territory)
```

It seems to indicate `territories` is "the continent's subregions of (some) territory", as opposed to the intended "the content's subregions **of category** 'territory'". Therefore it is left in place to promote fluent usage.

### Do not change the behavior of `Locale.Region.isoRegions`

It was considered to continue to omit regions that fall into the "grouping" category from `Locale.Region.isoRegions` for compatibility. However, just like all the other Locale related API, the list of ISO regions is never guaranteed to be constant. We do not expect users to rely on its exact values, so compatibility isn't a concern.
