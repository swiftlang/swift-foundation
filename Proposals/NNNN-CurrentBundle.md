# Introduce `#bundle`


* Proposal: [SF-NNNN](NNNN-filename.md)
* Authors:[Matt Seaman](https://github.com/matthewseaman), [Andreas Neusuess](https://github.com/Tantalum73)
* Review Manager: TBD
* Status: **Awaiting review**


## Revision history

* **v1** Initial version

## Introduction

API which loads localized strings assumes `Bundle.main` by default. This works for apps, but code that runs in a framework, or was defined in a Swift package, needs to specify a different bundle. The ultimate goal is to remove this requirement in the future. One step towards that goal is to provide an easy accessor to the bundle that stores localized resources: `#bundle`.

## Motivation

Developers writing code in a framework or a Swift package need to repeat the `bundle` parameter for every localized string.  
Without any shortcuts, loading a localized string from a framework looks like this:

```swift
label.text = String(
    localized: "She didn't clean the camera!",
    bundle: Bundle(for: MyViewController.self),
    comment: "Comment of astonished bystander"
    )
```

Because of its impracticalities, developers often write accessors to the framework's bundle:

```swift
private class LookupClass {}
extension Bundle {
    static let framework = Bundle(for: LookupClass.self)
    
    // Or worse yet, they lookup the bundle using its bundle identifier, which while tempting is actually rather inefficient.
}

label.text = String(
    localized: "She didn't clean the camera!",
    bundle: .framework,
    comment: "Comment of astonished bystander"
    )
```

While this solution requires less boilerplate, each framework target has to write some boilerplate still.

In the context of a localized Swift package, the build system takes care of creating an extension on `Bundle` called `Bundle.module` at build time. While this reduces the need for boilerplate already, it makes it complicated to move code from a framework or app target into a Swift package. Each call to a localization API needs to be audited and changed to `bundle: .module`.


## Proposed solution and example

We propose a macro that handles locating the right bundle with localized resources. It will work in all contexts: apps, framework targets, and Swift packages.

```swift
label.text = String(
    localized: "She didn't clean the camera!",
    bundle: #bundle,
    comment: "Comment of astonished bystander"
    )
```

We will also introduce an equivalent macro for usage with `LocalizedStringResource.BundleDescription`.

```swift
let string = LocalizedStringResource(
    "She didn't clean the camera!",
    bundle: #bundleDescription,
    comment: "Comment of astonished bystander"
    )
```

## Detailed design

We propose introducing a `#bundle` macro as follows:

```swift
/// Returns the bundle most likely to contain resources for the calling code.
///
/// Code in an app, app extension, framework, etc. will return the bundle associated with that target.
/// Code in a Swift Package target will return the resource bundle associated with that target.
@available(macOS 10.0, iOS 2.0, tvOS 9.0, watchOS 2.0, *)
@freestanding(expression)
public macro bundle() -> Bundle = #externalMacro(module: "FoundationMacros", type: "CurrentBundleMacro")
```

`#bundle` would expand to:

```swift
{
#if SWIFT_MODULE_RESOURCE_BUNDLE_AVAILABLE
    return Bundle.module
#elseif SWIFT_MODULE_RESOURCE_BUNDLE_UNAVAILABLE
    #error("No resource bundle is available for this module. If resources are included elsewhere, specify the bundle manually.")
#else
    return Bundle(_dsoHandle: #dsohandle) ?? .main
#endif
}()
```

We also propose a `#bundleDescription` macro:

```swift
/// Returns the bundle description most likely to contain resources for the calling code.
///
/// Code in an app, app extension, framework, etc. will return the bundle associated with that target.
/// Code in a Swift Package target will return the resource bundle associated with that target.
@available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *)
@freestanding(expression)
public macro bundleDescription() -> LocalizedStringResource.BundleDescription = #externalMacro(module: "FoundationMacros", type: "CurrentBundleDescriptionMacro")
```

which would expand to:

```swift
{
#if SWIFT_MODULE_RESOURCE_BUNDLE_AVAILABLE
    return LocalizedStringResource.BundleDescription.atURL(Bundle.module.bundleURL)
#elseif SWIFT_MODULE_RESOURCE_BUNDLE_UNAVAILABLE
    #error("No resource bundle is available for this module. If resources are included elsewhere, specify the bundle manually.")
#else
    return .atURL((Bundle(_dsoHandle: #dsohandle) ?? .main).bundleURL)
#endif
}()
```

Both macros rely on `SWIFT_MODULE_RESOURCE_BUNDLE_AVAILABLE `, a new `-D`-defined conditional that will be passed by SwiftBuild, SwiftPM, and potential 3rd party build systems under the same conditions where `Bundle.module` would be generated.

The preprocessor macro `SWIFT_MODULE_RESOURCE_BUNDLE_UNAVAILABLE` should be set by build systems when `Bundle.module` is not generated and the fallback `#dsohandle` approach would not retrieve the correct bundle for resources. A Swift Package without any resource files would be an example of this. Under this scenario, usage of `#bundle` presents an error.


Both macros call into new API on `Bundle`, which will be back-deployed so that using the macro isn't overly limited by the project's deployment target.

```swift
extension Bundle {
    /// Creates an instance of `Bundle` from the current value for `#dsohandle`.
    ///
    /// - warning: Don't call this method directly, and use `#bundle` instead.
    ///
    /// In the context of a Swift Package or other static library,
    /// the result is the bundle that contains the produced binary, which may be
    /// different from where resources are stored.
    ///
    /// - Parameter dsoHandle: `dsohandle` of the current binary.
    public convenience init?(_dsoHandle: UnsafeRawPointer)
```

## Impact on existing code

This change is purely additive.

## Alternatives considered

### Not using a macro

We chose a macro because it gives us the most flexibility to update the implementation later.
This will allow us to eventually use `#bundle` (or a wrapping macro) as the default argument for the bundle parameter, which (since [SE-0422](https://github.com/swiftlang/swift-evolution/blob/main/proposals/0422-caller-side-default-argument-macro-expression.md)) will get expanded in the caller.

Also, only a macro lets us properly implement this for Swift Package targets since we need to either call `Bundle.module` (which only exists as a code-gen'd, internal symbol in clients) or access build-time information such as the name of the target.

### Not doing this change

Without this macro, developers will continue to have to write extensions on `Bundle` or repeat calling `Bundle(for: )` in their code.


### Using the name `#currentResourceBundle`

Previously we discussed using the name `#currentResourceBundle` for the proposed new macro. It has been determined that `ResourceBundle` and `Bundle` describe the same thing in terms of loading resources. This macro will be used to load resources from the current bundle, repeating the fact that the current "resource bundle" is not necessary.

### Using the name `#currentBundle`

Previously we discussed using the name `#currentBundle` for the proposed new macro. It was pointed out that Swift already uses macros like `#filePath` or `#line`, which also imply "current".

While `#filePath` and `#line` are unambiguous, `#bundle` could be perceived as another way to spell `Bundle.main`. Calling it `#currentBundle` would help differentiate it from `Bundle.main`.

However, in the context of loading resources, `#bundle` is more accurate than `Bundle.main`, as it's correct in the majority of scenarios. Developers specifying `Bundle.main` when loading resources often want what `#bundle` offers, and calling the macro `#bundle` makes it easier to discover.

We think that consistency with existing Swift macros overweighs, and that the similarity to `Bundle.main` is an advantage for discoverability.

## Future Directions

## Infer `currentBundle` by default

This change is the first step towards not having to specify a bundle at all. Ideally, localizing a string should not require more work than using a type or method call that expresses localizability (i.e. `String.LocalizationValue`, `LocalizedStringResource`, or `String(localized: )`).


## Compute Package resource bundles without Bundle.module

If we enhance `MacroExpansionContext` to include some additional information from the build system (such as target name and type), we can change the implementation of `#bundle` to compute the bundle on its own.

This would be desirable so that the build system can inform Foundation about the bundle it creates on disk. Foundation's `#bundle` macro can ingest that information at build time, to produce code that loads the bundle in the current context.

`Bundle.module` can't be fully removed without breaking existing code, though it could be generated as deprecated and/or gated behind a build setting.
