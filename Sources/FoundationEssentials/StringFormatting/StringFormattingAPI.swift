//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2026 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

extension String {
    var stringsDictConfiguration: StringsDictConfig? {
        #if FOUNDATION_FRAMEWORK
        (self as NSString).stringsDictConfiguration
        #else
        nil
        #endif
    }
}

extension Optional<String> {
    fileprivate func withContents<T: ~Copyable, E>(_ body: (StringContents?) throws(E) -> T) throws(E) -> T {
        if let value = self {
            return try value.withContents(body)
        } else {
            return try body(nil)
        }
    }
}

#if NO_LOCALIZATION || !FOUNDATION_FRAMEWORK
// Stub String.LocalizationOptions._PluralizationNumber when building (the value will never be used)
extension String {
    enum LocalizationOptions {
        typealias _PluralizationNumber = Void
    }
}
#endif

extension String {
    init(_format format: String, pluralizationNumber: String.LocalizationOptions._PluralizationNumber?, locale: Locale?, args: CVaListPointer) {
        self.init()
        try! self.__append(format: format, validFormatSpecifiers: nil, pluralizationNumber: pluralizationNumber, locale: locale, args: args)
    }

    init(_format format: String, validFormatSpecifiers: String, pluralizationNumber: String.LocalizationOptions._PluralizationNumber?, locale: Locale?, args: CVaListPointer) throws {
        self.init()
        try self.__append(format: format, validFormatSpecifiers: validFormatSpecifiers, pluralizationNumber: pluralizationNumber, locale: locale, args: args)
    }

    #if !FOUNDATION_FRAMEWORK
    @_spi(SwiftCorelibsFoundation)
    public init(_format format: String, locale: Locale?, args: CVaListPointer, descriptionFunc: StringFormattingDescriptionFunction?) {
        self.init()
        try! self.__append(format: format, validFormatSpecifiers: nil, pluralizationNumber: nil, locale: locale, args: args, descriptionFunc: descriptionFunc)
    }
    #endif

    private static var defaultDescriptionFunc: StringFormattingDescriptionFunction? {
        #if FOUNDATION_FRAMEWORK
        __NSSwiftDescriptionWithLocale
        #else
        nil
        #endif
    }

    private mutating func __append(format: String, validFormatSpecifiers: String?, pluralizationNumber: String.LocalizationOptions._PluralizationNumber?, locale: Locale?, args: CVaListPointer, descriptionFunc: StringFormattingDescriptionFunction? = defaultDescriptionFunc) throws {
        var builder = SwiftStringBuilder(self)

        #if FOUNDATION_FRAMEWORK
        let contextDescriptionFunc: StringFormattingContextDescriptionFunction? = { object, formatString, run, found in
            formatString.withNSStringBorrow { nsFormatString in
                __NSSwiftDescriptionWithStringProxy(object, nsFormatString, STRING_FORMATTING_CONTEXT_REPLACEMENT as NSString, run, &found)
            }
        }
        #else
        let contextDescriptionFunc: StringFormattingContextDescriptionFunction? = nil
        #endif

        try format.withContents { formatString in
            try validFormatSpecifiers.withContents { validFormatSpecifiers in
                try _AppendFormatCore(
                    into: &builder,
                    descriptionFunc: descriptionFunc,
                    contextDescriptionFunc: contextDescriptionFunc,
                    locale: locale,
                    unlocalizedDecimalSeparator: nil,
                    stringsDictConfig: format.stringsDictConfiguration,
                    pluralizationNumber: pluralizationNumber,
                    validFormatSpecifiers: validFormatSpecifiers,
                    formatString: formatString,
                    arguments: _VarArgs(copying: args)
                )
            }
        }

        self = builder.finalize()
    }
}

#if FOUNDATION_FRAMEWORK && !targetEnvironment(exclaveKit)
extension AttributedString {
    init<S: AttributeScope>(_format format: String, arguments: [String.LocalizationValue.FormatArgument], options: AttributedString.LocalizationOptions, formatConfiguration: NSDictionary?, locale: Locale, scope: S.Type) {
        var varArgs: [any CVarArg] = []
        varArgs.reserveCapacity(arguments.count)
        var fixups: [String.LocalizationValue.FormatArgument._AttributeFixup?] = []
        fixups.reserveCapacity(arguments.count)

        for argument in arguments {
            switch argument.storage {
            case let .value(value):
                varArgs.append(value as! CVarArg)
                fixups.append(.attributeContainer(argument.buildAttributeContainerForArgument()))
            case let .attrStr(str, opts):
                varArgs.append(String(str._guts.string))
                fixups.append(.attributedString(str, options: opts))
            case let .stringFormat(wrapper):
                varArgs.append(wrapper.format(with: locale))
                fixups.append(.attributeContainer(argument.buildAttributeContainerForArgument()))
            case let .attributedStringFormat(wrapper):
                let str = wrapper.format(with: locale)
                varArgs.append(String(str._guts.string))
                let container = argument.buildAttributeContainerForArgument()
                fixups.append(.attributedString(str.mergingAttributes(container, mergePolicy: .keepCurrent), options: .init()))
            case var .localizedStringResource(resource):
                resource.locale = locale
                let attributedResolved = AttributedString(localized: resource, including: scope)
                varArgs.append(String(attributedResolved._guts.string))
                fixups.append(.attributedString(attributedResolved, options: .init()))
            case .localizedStringResourceList(let resources, var format):
                format = format.locale(locale)
                let items = resources.map {
                    var new = $0
                    new.locale = locale
                    return String(localized: new)
                }
                varArgs.append(items.formatted(format))
                fixups.append(nil)
            case .placeholder:
                fatalError("Attempted to resolve FormatArgument.placeholder")
            }
        }

        var builder = AttributedStringBuilder(applyReplacementIndex: options.applyReplacementIndexAttribute, fixups: fixups)
        let contextCallback: StringFormattingContextDescriptionFunction = { object, formatString, run, found in
            formatString.withNSStringBorrow { nsFormatString in
                __NSSwiftDescriptionWithStringProxy(object, nsFormatString, STRING_FORMATTING_CONTEXT_REPLACEMENT as NSString, run, &found)
            }
        }
        var success = false
        format.withContents { formatContents in
            withVaList(varArgs) { varArgsPointer in
                do {
                    try _AppendFormatCore(
                        into: &builder,
                        descriptionFunc: __NSSwiftDescriptionWithLocale,
                        contextDescriptionFunc: contextCallback,
                        locale: locale,
                        unlocalizedDecimalSeparator: nil,
                        stringsDictConfig: formatConfiguration.map { StringsDictConfig($0) },
                        pluralizationNumber: options._pluralizationNumber.map { String.LocalizationOptions._PluralizationNumber($0) },
                        validFormatSpecifiers: nil,
                        formatString: formatContents,
                        arguments: _VarArgs(copying: varArgsPointer)
                    )
                    success = true
                } catch {
                    success = false
                }
            }
        }
        guard success else {
            self.init()
            return
        }

        self = builder.content
    }
}
#endif
