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

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public struct ListFormatStyle<Style: FormatStyle, Base: Sequence>: FormatStyle where Base.Element == Style.FormatInput, Style.FormatOutput == String {
    private(set) var memberStyle: Style
    public var width: Width
    public var listType: ListType
    public var locale: Locale

    public init(memberStyle: Style) {
        self.memberStyle = memberStyle
        self.width = .standard
        self.listType = .and
        self.locale = .autoupdatingCurrent
    }

    public func format(_ value: Base) -> String {
        let formatter = ICUListFormatter.formatterCreateIfNeeded(format: self)
        return formatter.format(strings: value.map(memberStyle.format(_:)))
    }

    public enum Width: Int, Codable, Sendable {
        case standard
        case short
        case narrow
    }

    public enum ListType: Int, Codable, Sendable {
        case and
        case or
    }

    public func locale(_ locale: Locale) -> Self {
        var new = self
        new.locale = locale
        return new
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
extension ListFormatStyle : Sendable where Style : Sendable {}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public struct StringStyle: FormatStyle, Sendable {
    public func format(_ value: String) -> String { value }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension Sequence {
    func formatted<S: FormatStyle>(_ style: S) -> S.FormatOutput where S.FormatInput == Self {
        return style.format(self)
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension Swift.Sequence where Element == String {
    func formatted() -> String {
        return self.formatted(ListFormatStyle(memberStyle: StringStyle()))
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle {
    static func list<MemberStyle, Base>(memberStyle: MemberStyle, type: Self.ListType, width: Self.Width = .standard) -> Self where Self == ListFormatStyle<MemberStyle, Base> {
        var style = ListFormatStyle<MemberStyle, Base>(memberStyle: memberStyle)
        style.width = width
        style.listType = type
        return style
    }
}

@available(macOS 12.0, iOS 15.0, tvOS 15.0, watchOS 8.0, *)
public extension FormatStyle {
    static func list<Base>(type: Self.ListType, width: Self.Width = .standard) -> Self where Self == ListFormatStyle<StringStyle, Base> {
        var style = ListFormatStyle<StringStyle, Base>(memberStyle: StringStyle())
        style.width = width
        style.listType = type
        return style
    }
}
