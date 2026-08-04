//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2020 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if !FOUNDATION_FRAMEWORK

// stub
public struct Measurement<UnitType> {}
public class Dimension {}
public class UnitDuration: Dimension {}

extension Measurement where UnitType: Dimension {
    public struct FormatStyle : Sendable {
        public struct UnitWidth : Codable, Hashable, Sendable {
            /// A unit width that shows the full unit name.
            ///
            /// For example, `37.20 Calories` or `37,20 litres`.
            public static var wide: Self { .init(option: .wide) }

            /// An abbreviated unit width.
            ///
            /// For example, `37.20 Cal` or `37,2 L`.
            public static var abbreviated: Self { .init(option: .abbreviated) }

            /// The shortest unit width.
            ///
            /// This width may condense the spacing between the value and the unit; for example, `37.20Cal` or `37,2L`.
            public static var narrow: Self { .init(option: .narrow) }

            enum Option: Int, Codable, Hashable {
                case wide
                case abbreviated
                case narrow
            }
            var option: Option

            var skeleton: String {
                switch option {
                case .wide:
                    return "unit-width-full-name"
                case .abbreviated:
                    return "unit-width-short"
                case .narrow:
                    return "unit-width-narrow"
                }
            }
        }
    }
}
#endif // !FOUNDATION_FRAMEWORK
