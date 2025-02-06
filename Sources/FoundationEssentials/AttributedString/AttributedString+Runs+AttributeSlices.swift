//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2020-2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.Runs {
    @preconcurrency
    public struct AttributesSlice1<T : AttributedStringKey> : BidirectionalCollection, Sendable
    where T.Value : Sendable {
        public typealias Index = AttributedString.Index

        // FIXME: Why no labels?
        public typealias Element = (T.Value?, Range<AttributedString.Index>)

        internal typealias Runs = AttributedString.Runs

        let runs: Runs
        let _names: [String]
        let _constraints: [AttributeRunBoundaries]

        init(runs: Runs) {
            self.runs = runs
            // FIXME: ☠️ Get these from a proper cache in runs._guts.
            _names = [T.name]
            _constraints = T._constraintsInvolved
        }

        public struct Iterator: IteratorProtocol, Sendable {
            // Note: This is basically equivalent to `IndexingIterator`.

            public typealias Element = AttributesSlice1.Element

            let _slice: AttributesSlice1
            var _index: AttributesSlice1.Index

            internal init(_ slice: AttributesSlice1) {
                self._slice = slice
                self._index = slice.startIndex
            }

            public mutating func next() -> Element? {
                if _index == _slice.endIndex {
                    return nil
                }
                
                let run: AttributedString.Runs.Run
                let range: Range<AttributedString.Index>
                if _slice.runs._isDiscontiguous {
                    // Need to find the end of the current run (which may not be the same as the start of the next since it's discontiguous)
                    run = _slice.runs[_index]
                    let end = _slice.runs._slicedRunBoundary(
                        after: _index,
                        attributeNames: _slice._names,
                        constraints: _slice._constraints,
                        endOfCurrent: true)
                    let next = _slice.runs._slicedRunBoundary(
                        after: end,
                        attributeNames: _slice._names,
                        constraints: _slice._constraints,
                        endOfCurrent: false)
                    range = _index ..< end
                    _index = next
                } else {
                    // Contiguous runs ensures that the next index is the end of our run, which we can cache as the start of the next
                    run = _slice.runs[_index]
                    let next = _slice.index(after: _index)
                    range = _index ..< next
                    _index = next
                }
                
                return (run._attributes[T.self], range)
            }
        }

        public func makeIterator() -> Iterator {
            Iterator(self)
        }

        public var startIndex: Index {
            Index(runs.startIndex._stringIndex!)
        }

        public var endIndex: Index {
            Index(runs.endIndex._stringIndex!)
        }

        public func index(before i: Index) -> Index {
            runs._slicedRunBoundary(
                before: i,
                attributeNames: _names,
                constraints: _constraints,
                endOfPrevious: false
            )
        }

        public func index(after i: Index) -> Index {
            runs._slicedRunBoundary(
                after: i,
                attributeNames: _names,
                constraints: _constraints,
                endOfCurrent: false
            )
        }

        public subscript(position: AttributedString.Index) -> Element {
            let (start, runIndex) = runs._slicedRunBoundary(
                roundingDown: position,
                attributeNames: _names,
                constraints: _constraints)
            let end = runs._slicedRunBoundary(
                after: position,
                attributeNames: _names,
                constraints: _constraints,
                endOfCurrent: true
            )
            let attributes = runs._guts.runs[runIndex].attributes
            return (attributes[T.self], start ..< end)
        }

        // FIXME: This is a collection with potentially unaligned indices that uses Slice as its
        // SubSequence. Slicing the collection on such an index will produce spurious crashes.
        // Add a custom implementation for the range subscript that forcibly rounds the given bounds
        // down to the nearest valid indices.
    }

    @preconcurrency
    public subscript<T : AttributedStringKey>(_ keyPath: KeyPath<AttributeDynamicLookup, T>) -> AttributesSlice1<T> where T.Value : Sendable {
        return AttributesSlice1<T>(runs: self)
    }

    @preconcurrency
    public subscript<T : AttributedStringKey>(_ t: T.Type) -> AttributesSlice1<T> where T.Value : Sendable {
        return AttributesSlice1<T>(runs: self)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.Runs {
    @preconcurrency
    public struct AttributesSlice2<
        T : AttributedStringKey,
        U : AttributedStringKey
    > : BidirectionalCollection, Sendable
    where
        T.Value : Sendable,
        U.Value : Sendable
    {
        public typealias Index = AttributedString.Index

        // FIXME: Why no labels?
        public typealias Element = (T.Value?, U.Value?, Range<AttributedString.Index>)

        internal typealias Runs = AttributedString.Runs

        let runs : Runs
        let _names: [String]
        let _constraints: [AttributeRunBoundaries]

        init(runs: Runs) {
            self.runs = runs
            // FIXME: ☠️ Get these from a proper cache in runs._guts.
            _names = [T.name, U.name]
            _constraints = Array(_contents: T.runBoundaries, U.runBoundaries)
        }

        public struct Iterator: IteratorProtocol, Sendable {
            // Note: This is basically equivalent to `IndexingIterator`.

            public typealias Element = AttributesSlice2.Element

            let _slice: AttributesSlice2
            var _index: AttributedString.Index

            internal init(_ slice: AttributesSlice2) {
                self._slice = slice
                self._index = slice.startIndex
            }

            public mutating func next() -> Element? {
                if _index == _slice.endIndex {
                    return nil
                }
                
                let run: AttributedString.Runs.Run
                let range: Range<AttributedString.Index>
                if _slice.runs._isDiscontiguous {
                    // Need to find the end of the current run (which may not be the same as the start of the next since it's discontiguous)
                    run = _slice.runs[_index]
                    let end = _slice.runs._slicedRunBoundary(
                        after: _index,
                        attributeNames: _slice._names,
                        constraints: _slice._constraints,
                        endOfCurrent: true)
                    let next = _slice.runs._slicedRunBoundary(
                        after: end,
                        attributeNames: _slice._names,
                        constraints: _slice._constraints,
                        endOfCurrent: false)
                    range = _index ..< end
                    _index = next
                } else {
                    // Contiguous runs ensures that the next index is the end of our run, which we can cache as the start of the next
                    run = _slice.runs[_index]
                    let next = _slice.index(after: _index)
                    range = _index ..< next
                    _index = next
                }
                
                return (run._attributes[T.self], run._attributes[U.self], range)
            }
        }

        public func makeIterator() -> Iterator {
            Iterator(self)
        }
        
        public var startIndex: Index {
            Index(runs.startIndex._stringIndex!)
        }
        
        public var endIndex: Index {
            Index(runs.endIndex._stringIndex!)
        }

        public func index(before i: Index) -> Index {
            runs._slicedRunBoundary(
                before: i,
                attributeNames: _names,
                constraints: _constraints,
                endOfPrevious: false
            )
        }

        public func index(after i: Index) -> Index {
            runs._slicedRunBoundary(
                after: i,
                attributeNames: _names,
                constraints: _constraints,
                endOfCurrent: false
            )
        }

        public subscript(position: AttributedString.Index) -> Element {
            let (start, runIndex) = runs._slicedRunBoundary(
                roundingDown: position,
                attributeNames: _names,
                constraints: _constraints)
            let end = runs._slicedRunBoundary(
                after: position,
                attributeNames: _names,
                constraints: _constraints,
                endOfCurrent: true
            )
            let attributes = runs._guts.runs[runIndex].attributes
            return (attributes[T.self], attributes[U.self], start ..< end)
        }

        // FIXME: This is a collection with potentially unaligned indices that uses Slice as its
        // SubSequence. Slicing the collection on such an index will produce spurious crashes.
        // Add a custom implementation for the range subscript that forcibly rounds the given bounds
        // down to the nearest valid indices.
    }

    @preconcurrency
    public subscript <
        T : AttributedStringKey,
        U : AttributedStringKey
    > (
        _ t: KeyPath<AttributeDynamicLookup, T>,
        _ u: KeyPath<AttributeDynamicLookup, U>
    ) -> AttributesSlice2<T, U>
    where
        T.Value : Sendable,
        U.Value : Sendable {
        return AttributesSlice2<T, U>(runs: self)
    }

    @preconcurrency
    public subscript <
        T : AttributedStringKey,
        U : AttributedStringKey
    > (
        _ t: T.Type,
        _ u: U.Type
    ) -> AttributesSlice2<T, U>
    where 
        T.Value : Sendable,
        U.Value : Sendable {
        return AttributesSlice2<T, U>(runs: self)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.Runs {
    @preconcurrency
    public struct AttributesSlice3<
        T : AttributedStringKey,
        U : AttributedStringKey,
        V : AttributedStringKey
    > : BidirectionalCollection, Sendable
    where
        T.Value : Sendable,
        U.Value : Sendable,
        V.Value : Sendable
    {
        public typealias Index = AttributedString.Index

        // FIXME: Why no labels?
        public typealias Element = (T.Value?, U.Value?, V.Value?, Range<AttributedString.Index>)

        internal typealias Runs = AttributedString.Runs

        let runs : Runs
        let _names: [String]
        let _constraints: [AttributeRunBoundaries]

        init(runs: Runs) {
            self.runs = runs
            // FIXME: ☠️ Get these from a proper cache in runs._guts.
            _names = [T.name, U.name, V.name]
            _constraints = Array(_contents: T.runBoundaries, U.runBoundaries, V.runBoundaries)
        }

        public struct Iterator: IteratorProtocol, Sendable {
            // Note: This is basically equivalent to `IndexingIterator`.

            public typealias Element = AttributesSlice3.Element

            let _slice: AttributesSlice3
            var _index: AttributedString.Index

            internal init(_ slice: AttributesSlice3) {
                self._slice = slice
                self._index = slice.startIndex
            }

            public mutating func next() -> Element? {
                if _index == _slice.endIndex {
                    return nil
                }
                
                let run: AttributedString.Runs.Run
                let range: Range<AttributedString.Index>
                if _slice.runs._isDiscontiguous {
                    // Need to find the end of the current run (which may not be the same as the start of the next since it's discontiguous)
                    run = _slice.runs[_index]
                    let end = _slice.runs._slicedRunBoundary(
                        after: _index,
                        attributeNames: _slice._names,
                        constraints: _slice._constraints,
                        endOfCurrent: true)
                    let next = _slice.runs._slicedRunBoundary(
                        after: end,
                        attributeNames: _slice._names,
                        constraints: _slice._constraints,
                        endOfCurrent: false)
                    range = _index ..< end
                    _index = next
                } else {
                    // Contiguous runs ensures that the next index is the end of our run, which we can cache as the start of the next
                    run = _slice.runs[_index]
                    let next = _slice.index(after: _index)
                    range = _index ..< next
                    _index = next
                }
                
                return (
                    run._attributes[T.self],
                    run._attributes[U.self],
                    run._attributes[V.self],
                    range)
            }
        }

        public func makeIterator() -> Iterator {
            Iterator(self)
        }
        
        public var startIndex: Index {
            Index(runs.startIndex._stringIndex!)
        }
        
        public var endIndex: Index {
            Index(runs.endIndex._stringIndex!)
        }

        public func index(before i: Index) -> Index {
            runs._slicedRunBoundary(
                before: i,
                attributeNames: _names,
                constraints: _constraints,
                endOfPrevious: false
            )
        }

        public func index(after i: Index) -> Index {
            runs._slicedRunBoundary(
                after: i,
                attributeNames: _names,
                constraints: _constraints,
                endOfCurrent: false
            )
        }

        public subscript(position: AttributedString.Index) -> Element {
            let (start, runIndex) = runs._slicedRunBoundary(
                roundingDown: position,
                attributeNames: _names,
                constraints: _constraints)
            let end = runs._slicedRunBoundary(
                after: position,
                attributeNames: _names,
                constraints: _constraints,
                endOfCurrent: true
            )
            let attributes = runs._guts.runs[runIndex].attributes
            return (attributes[T.self], attributes[U.self], attributes[V.self], start ..< end)
        }

        // FIXME: This is a collection with potentially unaligned indices that uses Slice as its
        // SubSequence. Slicing the collection on such an index will produce spurious crashes.
        // Add a custom implementation for the range subscript that forcibly rounds the given bounds
        // down to the nearest valid indices.
    }

    @preconcurrency
    public subscript <
        T : AttributedStringKey,
        U : AttributedStringKey,
        V : AttributedStringKey
    > (
        _ t: KeyPath<AttributeDynamicLookup, T>,
        _ u: KeyPath<AttributeDynamicLookup, U>,
        _ v: KeyPath<AttributeDynamicLookup, V>
    ) -> AttributesSlice3<T, U, V>
    where
        T.Value : Sendable,
        U.Value : Sendable,
        V.Value : Sendable {
        return AttributesSlice3<T, U, V>(runs: self)
    }

    @preconcurrency
    public subscript <
        T : AttributedStringKey,
        U : AttributedStringKey,
        V : AttributedStringKey
    > (
        _ t: T.Type,
        _ u: U.Type,
        _ v: V.Type
    ) -> AttributesSlice3<T, U, V>
    where
        T.Value : Sendable,
        U.Value : Sendable,
        V.Value : Sendable {
        return AttributesSlice3<T, U, V>(runs: self)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.Runs {
    @preconcurrency
    public struct AttributesSlice4<
        T : AttributedStringKey,
        U : AttributedStringKey,
        V : AttributedStringKey,
        W : AttributedStringKey
    > : BidirectionalCollection, Sendable
    where
        T.Value : Sendable,
        U.Value : Sendable,
        V.Value : Sendable,
        W.Value : Sendable
    {
        public typealias Index = AttributedString.Index

        // FIXME: Why no labels?
        public typealias Element = (T.Value?, U.Value?, V.Value?, W.Value?, Range<AttributedString.Index>)

        internal typealias Runs = AttributedString.Runs

        let runs : Runs
        let _names: [String]
        let _constraints: [AttributeRunBoundaries]

        init(runs: Runs) {
            self.runs = runs
            // FIXME: ☠️ Get these from a proper cache in runs._guts.
            _names = [T.name, U.name, V.name, W.name]
            _constraints = Array(
                _contents: T.runBoundaries, U.runBoundaries, V.runBoundaries, W.runBoundaries)
        }

        public struct Iterator: IteratorProtocol, Sendable {
            // Note: This is basically equivalent to `IndexingIterator`.

            public typealias Element = AttributesSlice4.Element

            let _slice: AttributesSlice4
            var _index: AttributedString.Index

            internal init(_ slice: AttributesSlice4) {
                self._slice = slice
                self._index = slice.startIndex
            }

            public mutating func next() -> Element? {
                if _index == _slice.endIndex {
                    return nil
                }
                
                let run: AttributedString.Runs.Run
                let range: Range<AttributedString.Index>
                if _slice.runs._isDiscontiguous {
                    // Need to find the end of the current run (which may not be the same as the start of the next since it's discontiguous)
                    run = _slice.runs[_index]
                    let end = _slice.runs._slicedRunBoundary(
                        after: _index,
                        attributeNames: _slice._names,
                        constraints: _slice._constraints,
                        endOfCurrent: true)
                    let next = _slice.runs._slicedRunBoundary(
                        after: end,
                        attributeNames: _slice._names,
                        constraints: _slice._constraints,
                        endOfCurrent: false)
                    range = _index ..< end
                    _index = next
                } else {
                    // Contiguous runs ensures that the next index is the end of our run, which we can cache as the start of the next
                    run = _slice.runs[_index]
                    let next = _slice.index(after: _index)
                    range = _index ..< next
                    _index = next
                }
                
                return (
                    run._attributes[T.self],
                    run._attributes[U.self],
                    run._attributes[V.self],
                    run._attributes[W.self],
                    range)
            }
        }

        public func makeIterator() -> Iterator {
            Iterator(self)
        }
        
        public var startIndex: Index {
            Index(runs.startIndex._stringIndex!)
        }
        
        public var endIndex: Index {
            Index(runs.endIndex._stringIndex!)
        }

        public func index(before i: Index) -> Index {
            runs._slicedRunBoundary(
                before: i,
                attributeNames: _names,
                constraints: _constraints,
                endOfPrevious: false
            )
        }

        public func index(after i: Index) -> Index {
            runs._slicedRunBoundary(
                after: i,
                attributeNames: _names,
                constraints: _constraints,
                endOfCurrent: false
            )
        }

        public subscript(position: AttributedString.Index) -> Element {
            let (start, runIndex) = runs._slicedRunBoundary(
                roundingDown: position,
                attributeNames: _names,
                constraints: _constraints)
            let end = runs._slicedRunBoundary(
                after: position,
                attributeNames: _names,
                constraints: _constraints,
                endOfCurrent: true
            )
            let attributes = runs._guts.runs[runIndex].attributes
            return (
                attributes[T.self],
                attributes[U.self],
                attributes[V.self],
                attributes[W.self],
                start ..< end)
        }

        // FIXME: This is a collection with potentially unaligned indices that uses Slice as its
        // SubSequence. Slicing the collection on such an index will produce spurious crashes.
        // Add a custom implementation for the range subscript that forcibly rounds the given bounds
        // down to the nearest valid indices.
    }

    @preconcurrency
    public subscript <
        T : AttributedStringKey,
        U : AttributedStringKey,
        V : AttributedStringKey,
        W : AttributedStringKey
    > (
        _ t: KeyPath<AttributeDynamicLookup, T>,
        _ u: KeyPath<AttributeDynamicLookup, U>,
        _ v: KeyPath<AttributeDynamicLookup, V>,
        _ w: KeyPath<AttributeDynamicLookup, W>
    ) -> AttributesSlice4<T, U, V, W>
    where
        T.Value : Sendable,
        U.Value : Sendable,
        V.Value : Sendable,
        W.Value : Sendable {
        return AttributesSlice4<T, U, V, W>(runs: self)
    }

    @preconcurrency
    public subscript <
        T : AttributedStringKey,
        U : AttributedStringKey,
        V : AttributedStringKey,
        W : AttributedStringKey
    > (
        _ t: T.Type,
        _ u: U.Type,
        _ v: V.Type,
        _ w: W.Type
    ) -> AttributesSlice4<T, U, V, W>
    where
        T.Value : Sendable,
        U.Value : Sendable,
        V.Value : Sendable,
        W.Value : Sendable {
        return AttributesSlice4<T, U, V, W>(runs: self)
    }
}

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.Runs {
    @preconcurrency
    public struct AttributesSlice5<
        T : AttributedStringKey,
        U : AttributedStringKey,
        V : AttributedStringKey,
        W : AttributedStringKey,
        X : AttributedStringKey
    > : BidirectionalCollection, Sendable
    where
        T.Value : Sendable,
        U.Value : Sendable,
        V.Value : Sendable,
        W.Value : Sendable,
        X.Value : Sendable
    {
        public typealias Index = AttributedString.Index

        // FIXME: Why no labels?
        public typealias Element = (T.Value?, U.Value?, V.Value?, W.Value?, X.Value?, Range<AttributedString.Index>)

        internal typealias Runs = AttributedString.Runs

        let runs : Runs
        let _names: [String]
        let _constraints: [AttributeRunBoundaries]

        init(runs: Runs) {
            self.runs = runs
            // FIXME: ☠️ Get these from a proper cache in runs._guts.
            _names = [T.name, U.name, V.name, W.name]
            _constraints = Array(
                _contents: T.runBoundaries,
                U.runBoundaries,
                V.runBoundaries,
                W.runBoundaries,
                X.runBoundaries)
        }

        public struct Iterator: IteratorProtocol, Sendable {
            public typealias Element = AttributesSlice5.Element

            let _slice: AttributesSlice5
            var _index: AttributedString.Index

            internal init(_ slice: AttributesSlice5) {
                self._slice = slice
                self._index = slice.startIndex
            }

            public mutating func next() -> Element? {
                if _index == _slice.endIndex {
                    return nil
                }
                
                let run: AttributedString.Runs.Run
                let range: Range<AttributedString.Index>
                if _slice.runs._isDiscontiguous {
                    // Need to find the end of the current run (which may not be the same as the start of the next since it's discontiguous)
                    run = _slice.runs[_index]
                    let end = _slice.runs._slicedRunBoundary(
                        after: _index,
                        attributeNames: _slice._names,
                        constraints: _slice._constraints,
                        endOfCurrent: true)
                    let next = _slice.runs._slicedRunBoundary(
                        after: end,
                        attributeNames: _slice._names,
                        constraints: _slice._constraints,
                        endOfCurrent: false)
                    range = _index ..< end
                    _index = next
                } else {
                    // Contiguous runs ensures that the next index is the end of our run, which we can cache as the start of the next
                    run = _slice.runs[_index]
                    let next = _slice.index(after: _index)
                    range = _index ..< next
                    _index = next
                }
                
                return (
                    run._attributes[T.self],
                    run._attributes[U.self],
                    run._attributes[V.self],
                    run._attributes[W.self],
                    run._attributes[X.self],
                    range)
            }
        }

        public func makeIterator() -> Iterator {
            Iterator(self)
        }
        
        public var startIndex: Index {
            Index(runs.startIndex._stringIndex!)
        }
        
        public var endIndex: Index {
            Index(runs.endIndex._stringIndex!)
        }

        public func index(before i: Index) -> Index {
            runs._slicedRunBoundary(
                before: i,
                attributeNames: _names,
                constraints: _constraints,
                endOfPrevious: false
            )
        }

        public func index(after i: Index) -> Index {
            runs._slicedRunBoundary(
                after: i,
                attributeNames: _names,
                constraints: _constraints,
                endOfCurrent: false
            )
        }

        public subscript(position: AttributedString.Index) -> Element {
            let (start, runIndex) = runs._slicedRunBoundary(
                roundingDown: position,
                attributeNames: _names,
                constraints: _constraints)
            let end = runs._slicedRunBoundary(
                after: position,
                attributeNames: _names,
                constraints: _constraints,
                endOfCurrent: true
            )
            let attributes = runs._guts.runs[runIndex].attributes
            return (
                attributes[T.self],
                attributes[U.self],
                attributes[V.self],
                attributes[W.self],
                attributes[X.self],
                start ..< end)
        }

        // FIXME: This is a collection with potentially unaligned indices that uses Slice as its
        // SubSequence. Slicing the collection on such an index will produce spurious crashes.
        // Add a custom implementation for the range subscript that forcibly rounds the given bounds
        // down to the nearest valid indices.
    }

    @preconcurrency
    public subscript <
        T : AttributedStringKey,
        U : AttributedStringKey,
        V : AttributedStringKey,
        W : AttributedStringKey,
        X : AttributedStringKey
    > (
        _ t: KeyPath<AttributeDynamicLookup, T>,
        _ u: KeyPath<AttributeDynamicLookup, U>,
        _ v: KeyPath<AttributeDynamicLookup, V>,
        _ w: KeyPath<AttributeDynamicLookup, W>,
        _ x: KeyPath<AttributeDynamicLookup, X>
    ) -> AttributesSlice5<T, U, V, W, X> 
    where
        T.Value : Sendable,
        U.Value : Sendable,
        V.Value : Sendable,
        W.Value : Sendable,
        X.Value : Sendable {
        return AttributesSlice5<T, U, V, W, X>(runs: self)
    }

    @preconcurrency
    public subscript <
        T : AttributedStringKey,
        U : AttributedStringKey,
        V : AttributedStringKey,
        W : AttributedStringKey,
        X : AttributedStringKey
    > (
        _ t: T.Type,
        _ u: U.Type,
        _ v: V.Type,
        _ w: W.Type,
        _ x: X.Type
    ) -> AttributesSlice5<T, U, V, W, X> 
    where
        T.Value : Sendable,
        U.Value : Sendable,
        V.Value : Sendable,
        W.Value : Sendable,
        X.Value : Sendable {
        return AttributesSlice5<T, U, V, W, X>(runs: self)
    }
}

#if FOUNDATION_FRAMEWORK

@available(macOS 12, iOS 15, tvOS 15, watchOS 8, *)
extension AttributedString.Runs {
    @_spi(AttributedString)
    public struct NSAttributesSlice : BidirectionalCollection, Sendable {
        public typealias Index = AttributedString.Index

        // FIXME: Why no labels?
        public typealias Element = (AttributeContainer, Range<AttributedString.Index>)

        internal typealias Runs = AttributedString.Runs

        internal let _runs: Runs
        private let _names: [String]

        internal init(runs: Runs, names: [String]) {
            self._runs = runs
            self._names = names
        }

        public struct Iterator: IteratorProtocol, Sendable {
            // Note: This is basically equivalent to `IndexingIterator`.

            public typealias Element = NSAttributesSlice.Element

            let _slice: NSAttributesSlice
            var _index: AttributedString.Index

            internal init(_ slice: NSAttributesSlice) {
                self._slice = slice
                self._index = slice.startIndex
            }

            public mutating func next() -> Element? {
                if _index == _slice.endIndex {
                    return nil
                }
                let run = _slice._runs[_index]
                let next = _slice.index(after: _index)
                let range = _index ..< next
                _index = next
                return (_slice.buildContainer(from: run._attributes), range)
            }
        }

        public func makeIterator() -> Iterator {
            Iterator(self)
        }

        public var startIndex: Index {
            Index(_runs._strBounds.lowerBound)
        }

        public var endIndex: Index {
            Index(_runs._strBounds.upperBound)
        }

        public func index(before i: Index) -> Index {
            _runs._slicedRunBoundary(
                before: i,
                attributeNames: _names,
                constraints: [])
        }

        public func index(after i: Index) -> Index {
            _runs._slicedRunBoundary(
                after: i,
                attributeNames: _names,
                constraints: [])
        }

        public subscript(position: AttributedString.Index) -> Element {
            let (start, runIndex) = _runs._slicedRunBoundary(
                roundingDown: position,
                attributeNames: _names,
                constraints: [])
            let end = self.index(after: position)
            let attributes = _runs._guts.runs[runIndex].attributes
            return (buildContainer(from: attributes), start ..< end)
        }

        // FIXME: This is a collection with potentially unaligned indices that uses Slice as its
        // SubSequence. Slicing the collection on such an index will produce spurious crashes.
        // Add a custom implementation for the range subscript that forcibly rounds the given bounds
        // down to the nearest valid indices.

        private func buildContainer(from storage: AttributedString._AttributeStorage) -> AttributeContainer {
            AttributeContainer(storage.filterWithoutInvalidatingDependents { _names.contains($0.key) })
        }
    }

    @_spi(AttributedString)
    public subscript(nsAttributedStringKeys keys: NSAttributedString.Key...) -> NSAttributesSlice {
        return NSAttributesSlice(runs: self, names: keys.map { $0.rawValue })
    }
}

#endif // FOUNDATION_FRAMEWORK

extension RangeReplaceableCollection {
    internal init(_contents item1: Element?) {
        self.init()
        if let item1 { self.append(item1) }
    }

    internal init(_contents item1: Element?, _ item2: Element?) {
        self.init()
        var c = 0
        if item1 != nil { c &+= 1 }
        if item2 != nil { c &+= 1 }
        guard c > 0 else { return }
        self.reserveCapacity(c)
        if let item1 { self.append(item1) }
        if let item2 { self.append(item2) }
    }

    internal init(_contents item1: Element?, _ item2: Element?, _ item3: Element?) {
        self.init()
        var c = 0
        if item1 != nil { c &+= 1 }
        if item2 != nil { c &+= 1 }
        if item3 != nil { c &+= 1 }
        guard c > 0 else { return }
        self.reserveCapacity(c)
        if let item1 { self.append(item1) }
        if let item2 { self.append(item2) }
        if let item3 { self.append(item3) }
    }

    internal init(
        _contents item1: Element?, _ item2: Element?, _ item3: Element?, _ item4: Element?
    ) {
        self.init()
        var c = 0
        if item1 != nil { c &+= 1 }
        if item2 != nil { c &+= 1 }
        if item3 != nil { c &+= 1 }
        if item4 != nil { c &+= 1 }
        guard c > 0 else { return }
        self.reserveCapacity(c)
        if let item1 { self.append(item1) }
        if let item2 { self.append(item2) }
        if let item3 { self.append(item3) }
        if let item4 { self.append(item4) }
    }

    internal init(
        _contents item1: Element?,
        _ item2: Element?,
        _ item3: Element?,
        _ item4: Element?,
        _ item5: Element?
    ) {
        self.init()
        var c = 0
        if item1 != nil { c &+= 1 }
        if item2 != nil { c &+= 1 }
        if item3 != nil { c &+= 1 }
        if item4 != nil { c &+= 1 }
        if item5 != nil { c &+= 1 }
        guard c > 0 else { return }
        self.reserveCapacity(c)
        if let item1 { self.append(item1) }
        if let item2 { self.append(item2) }
        if let item3 { self.append(item3) }
        if let item4 { self.append(item4) }
        if let item5 { self.append(item5) }
    }
}

