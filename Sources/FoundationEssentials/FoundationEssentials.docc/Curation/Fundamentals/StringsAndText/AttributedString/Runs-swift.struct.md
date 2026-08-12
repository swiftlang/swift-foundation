# ``/FoundationEssentials/AttributedString/Runs``


## Topics

### Accessing attribute runs

- ``subscript(_:)-(AttributedString.Index)``                            <!-- subscript(position: AttributedString.Index) -> AttributedString.Runs.Run { get } -->
- ``Run``

### Accessing attribute slices

- ``subscript(_:)-(KeyPath<AttributeDynamicLookup,T>)``                 <!-- @preconcurrency subscript<T>(keyPath: KeyPath<AttributeDynamicLookup, T>) -> AttributedString.Runs.AttributesSlice1<T> where T : AttributedStringKey, T.Value : Sendable { get } -->
- ``subscript(_:)-(T.Type)``                                            <!-- @preconcurrency subscript<T>(t: T.Type) -> AttributedString.Runs.AttributesSlice1<T> where T : AttributedStringKey, T.Value : Sendable { get } -->
- ``AttributesSlice1``
- ``subscript(_:_:)-(T.Type,_)``                                        <!-- @preconcurrency subscript<T, U>(t: T.Type, u: U.Type) -> AttributedString.Runs.AttributesSlice2<T, U> where T : AttributedStringKey, U : AttributedStringKey, T.Value : Sendable, U.Value : Sendable { get } -->
- ``subscript(_:_:)-(KeyPath<AttributeDynamicLookup,T>,_)``             <!-- @preconcurrency subscript<T, U>(t: KeyPath<AttributeDynamicLookup, T>, u: KeyPath<AttributeDynamicLookup, U>) -> AttributedString.Runs.AttributesSlice2<T, U> where T : AttributedStringKey, U : AttributedStringKey, T.Value : Sendable, U.Value : Sendable { get } -->
- ``AttributesSlice2``
- ``subscript(_:_:_:)-(T.Type,_,_)``                                    <!-- @preconcurrency subscript<T, U, V>(t: T.Type, u: U.Type, v: V.Type) -> AttributedString.Runs.AttributesSlice3<T, U, V> where T : AttributedStringKey, U : AttributedStringKey, V : AttributedStringKey, T.Value : Sendable, U.Value : Sendable, V.Value : Sendable { get } -->
- ``subscript(_:_:_:)-(KeyPath<AttributeDynamicLookup,T>,_,_)``         <!-- @preconcurrency subscript<T, U, V>(t: KeyPath<AttributeDynamicLookup, T>, u: KeyPath<AttributeDynamicLookup, U>, v: KeyPath<AttributeDynamicLookup, V>) -> AttributedString.Runs.AttributesSlice3<T, U, V> where T : AttributedStringKey, U : AttributedStringKey, V : AttributedStringKey, T.Value : Sendable, U.Value : Sendable, V.Value : Sendable { get } -->
- ``AttributesSlice3``
- ``subscript(_:_:_:_:)-(T.Type,_,_,_)``                                <!-- @preconcurrency subscript<T, U, V, W>(t: T.Type, u: U.Type, v: V.Type, w: W.Type) -> AttributedString.Runs.AttributesSlice4<T, U, V, W> where T : AttributedStringKey, U : AttributedStringKey, V : AttributedStringKey, W : AttributedStringKey, T.Value : Sendable, U.Value : Sendable, V.Value : Sendable, W.Value : Sendable { get } -->
- ``subscript(_:_:_:_:)-(KeyPath<AttributeDynamicLookup,T>,_,_,_)``     <!-- @preconcurrency subscript<T, U, V, W>(t: KeyPath<AttributeDynamicLookup, T>, u: KeyPath<AttributeDynamicLookup, U>, v: KeyPath<AttributeDynamicLookup, V>, w: KeyPath<AttributeDynamicLookup, W>) -> AttributedString.Runs.AttributesSlice4<T, U, V, W> where T : AttributedStringKey, U : AttributedStringKey, V : AttributedStringKey, W : AttributedStringKey, T.Value : Sendable, U.Value : Sendable, V.Value : Sendable, W.Value : Sendable { get } -->
- ``AttributesSlice4``
- ``subscript(_:_:_:_:_:)-(KeyPath<AttributeDynamicLookup,T>,_,_,_,_)`` <!-- @preconcurrency subscript<T, U, V, W, X>(t: KeyPath<AttributeDynamicLookup, T>, u: KeyPath<AttributeDynamicLookup, U>, v: KeyPath<AttributeDynamicLookup, V>, w: KeyPath<AttributeDynamicLookup, W>, x: KeyPath<AttributeDynamicLookup, X>) -> AttributedString.Runs.AttributesSlice5<T, U, V, W, X> where T : AttributedStringKey, U : AttributedStringKey, V : AttributedStringKey, W : AttributedStringKey, X : AttributedStringKey, T.Value : Sendable, U.Value : Sendable, V.Value : Sendable, W.Value : Sendable, X.Value : Sendable { get } -->
- ``subscript(_:_:_:_:_:)-(T.Type,_,_,_,_)``                            <!-- @preconcurrency subscript<T, U, V, W, X>(t: T.Type, u: U.Type, v: V.Type, w: W.Type, x: X.Type) -> AttributedString.Runs.AttributesSlice5<T, U, V, W, X> where T : AttributedStringKey, U : AttributedStringKey, V : AttributedStringKey, W : AttributedStringKey, X : AttributedStringKey, T.Value : Sendable, U.Value : Sendable, V.Value : Sendable, W.Value : Sendable, X.Value : Sendable { get } -->
- ``AttributesSlice5``
