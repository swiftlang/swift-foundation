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

#if canImport(FoundationEssentials)
import FoundationEssentials
#endif

#if !FOUNDATION_FRAMEWORK

// stub
extension Date {

    @available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
    public struct ComponentsFormatStyle : Codable, Hashable, Sendable {
        public struct Field : Codable, Hashable, Sendable {
            enum Option : Int, Codable, Hashable, CaseIterable, Comparable {
                case year
                case month
                case week
                case day
                case hour
                case minute
                case second

                var component: Calendar.Component {
                    switch self {
                    case .year:
                        return .year
                    case .month:
                        return .month
                    case .week:
                        return .weekOfMonth
                    case .day:
                        return .day
                    case .hour:
                        return .hour
                    case .minute:
                        return .minute
                    case .second:
                        return .second
                    }
                }

                init?(component: Calendar.Component) {
                    switch component {
                    case .year:
                        self = .year
                    case .month:
                        self = .month
                    case .weekOfYear, .weekOfMonth:
                        self = .week
                    case .day:
                        self = .day
                    case .hour:
                        self = .hour
                    case .minute:
                        self = .minute
                    case .second:
                        self = .second
                    default:
                        return nil
                    }
                }

                static func <(lhs: Self, rhs: Self) -> Bool {
                    lhs.rawValue > rhs.rawValue
                }
            }

            var option: Option
            public static var year: Field { .init(option: .year) }
            public static var month: Field { .init(option: .month) }
            public static var week: Field { .init(option: .week) }
            public static var day: Field { .init(option: .day) }
            public static var hour: Field { .init(option: .hour) }
            public static var minute: Field { .init(option: .minute) }
            public static var second: Field { .init(option: .second) }
        }
    }
}
#endif // !FOUNDATION_FRAMEWORK
