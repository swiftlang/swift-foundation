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

import Testing
@testable import NewCodableMacros

// MARK: - splitIntoWords Tests

@Suite("splitIntoWords")
struct SplitIntoWordsTests {

    // MARK: - camelCase inputs

    @Test func camelCaseSimple() {
        #expect(splitIntoWords("myProperty") == ["my", "Property"])
    }

    @Test func camelCaseMultipleWords() {
        #expect(splitIntoWords("myLongPropertyName") == ["my", "Long", "Property", "Name"])
    }

    @Test func camelCaseSingleWord() {
        #expect(splitIntoWords("name") == ["name"])
    }

    // MARK: - PascalCase inputs

    @Test func pascalCaseSimple() {
        #expect(splitIntoWords("MyProperty") == ["My", "Property"])
    }

    @Test func pascalCaseMultipleWords() {
        #expect(splitIntoWords("MyLongPropertyName") == ["My", "Long", "Property", "Name"])
    }

    @Test func pascalCaseSingleWord() {
        #expect(splitIntoWords("Name") == ["Name"])
    }

    // MARK: - Acronyms

    @Test func acronymAtEnd() {
        #expect(splitIntoWords("parseJSON") == ["parse", "JSON"])
    }

    @Test func acronymAtStart() {
        #expect(splitIntoWords("HTTPResponse") == ["HTTP", "Response"])
    }

    @Test func acronymInMiddle() {
        #expect(splitIntoWords("parseHTTPResponse") == ["parse", "HTTP", "Response"])
    }

    @Test func multipleAcronyms() {
        #expect(splitIntoWords("convertXMLToJSON") == ["convert", "XML", "To", "JSON"])
    }

    @Test func acronymFollowedByAcronym() {
        #expect(splitIntoWords("XMLHTTP") == ["XMLHTTP"])
    }

    @Test func singleCharacterAtEnd() {
        #expect(splitIntoWords("singleCharacterAtEndX") == ["single", "Character", "At", "End", "X"])
    }

    @Test func twoCharacters() {
        #expect(splitIntoWords("aA") == ["a", "A"])
    }

    @Test func partialCaps() {
        #expect(splitIntoWords("partCAPS") == ["part", "CAPS"])
    }

    @Test func partialCapsSwitchBack() {
        #expect(splitIntoWords("partCAPSLowerAGAIN") == ["part", "CAPS", "Lower", "AGAIN"])
    }

    @Test func thisIsAnXMLProperty() {
        #expect(splitIntoWords("thisIsAnXMLProperty") == ["this", "Is", "An", "XML", "Property"])
    }

    // MARK: - snake_case inputs

    @Test func snakeCaseSimple() {
        #expect(splitIntoWords("my_property") == ["my", "property"])
    }

    @Test func snakeCaseMultipleWords() {
        #expect(splitIntoWords("my_long_property_name") == ["my", "long", "property", "name"])
    }

    @Test func screamingSnakeCase() {
        #expect(splitIntoWords("MY_LONG_PROPERTY") == ["MY", "LONG", "PROPERTY"])
    }

    // MARK: - Mixed inputs

    @Test func camelCaseWithUnderscores() {
        #expect(splitIntoWords("myProperty_name") == ["my", "Property", "name"])
    }

    // MARK: - Numerics

    @Test func numbersInMiddle() {
        #expect(splitIntoWords("property2Name") == ["property2", "Name"])
    }

    @Test func numbersAfterUnderscore() {
        #expect(splitIntoWords("property_2_name") == ["property", "2", "name"])
    }

    @Test func version4Thing() {
        #expect(splitIntoWords("version4Thing") == ["version4", "Thing"])
    }

    @Test func dataPoint22() {
        #expect(splitIntoWords("dataPoint22") == ["data", "Point22"])
    }

    @Test func dataPoint22Word() {
        #expect(splitIntoWords("dataPoint22Word") == ["data", "Point22", "Word"])
    }

    @Test func one2Three() {
        #expect(splitIntoWords("one2Three") == ["one2", "Three"])
    }

    // MARK: - Diacritics

    @Test func diacriticUppercaseTransition() {
        #expect(splitIntoWords("asdfĆqer") == ["asdf", "Ćqer"])
    }

    @Test func snakeCaseDiacritic() {
        #expect(splitIntoWords("snake_ćase") == ["snake", "ćase"])
    }

    @Test func snakeCaseCapitalizedDiacritic() {
        #expect(splitIntoWords("snake_Ćase") == ["snake", "Ćase"])
    }

    // MARK: - Edge cases

    @Test func emptyString() {
        #expect(splitIntoWords("") == [])
    }

    @Test func singleCharacterLowercase() {
        #expect(splitIntoWords("x") == ["x"])
    }

    @Test func singleCharacterUppercase() {
        #expect(splitIntoWords("X") == ["X"])
    }

    @Test func allUppercase() {
        #expect(splitIntoWords("URL") == ["URL"])
    }

    @Test func allLowercase() {
        #expect(splitIntoWords("lowercase") == ["lowercase"])
    }

    @Test func consecutiveUnderscores() {
        #expect(splitIntoWords("my__property") == ["my", "property"])
    }

    @Test func leadingUnderscore() {
        #expect(splitIntoWords("_myProperty") == ["my", "Property"])
    }

    @Test func trailingUnderscore() {
        #expect(splitIntoWords("myProperty_") == ["my", "Property"])
    }

    @Test func multipleLeadingUnderscores() {
        #expect(splitIntoWords("__myProperty") == ["my", "Property"])
    }

    @Test func onlyUnderscores() {
        #expect(splitIntoWords("___") == [])
    }
}

// MARK: - applyNamingConvention Tests

@Suite("applyNamingConvention")
struct ApplyNamingConventionTests {

    /// Each group represents the same conceptual words expressed in every valid Swift identifier format.
    /// This ensures a true cross-product: every concept × every input format × every output convention.
    ///
    /// Inputs are limited to formats that are valid Swift identifiers:
    /// camelCase, PascalCase, snake_case, and SCREAMING_SNAKE_CASE.
    struct ConceptGroup {
        let label: String
        let camelCase: String
        let pascalCase: String
        let snakeCase: String
        let screamingSnakeCase: String

        // Expected outputs for this concept under each target convention
        let toCamelCase: String
        let toPascalCase: String
        let toSnakeCase: String
        let toScreamingSnakeCase: String
        let toKebabCase: String
        let toScreamingKebabCase: String
        let toLowercase: String
        let toUppercase: String

        var allInputs: [(label: String, input: String)] {
            [
                ("\(label)/camelCase", camelCase),
                ("\(label)/PascalCase", pascalCase),
                ("\(label)/snake_case", snakeCase),
                ("\(label)/SCREAMING_SNAKE_CASE", screamingSnakeCase),
            ]
        }
    }

    static let concepts: [ConceptGroup] = [
        // Two simple words
        ConceptGroup(label: "twoWords",
            camelCase: "myProperty",
            pascalCase: "MyProperty",
            snakeCase: "my_property",
            screamingSnakeCase: "MY_PROPERTY",

            toCamelCase: "myProperty",
            toPascalCase: "MyProperty",
            toSnakeCase: "my_property",
            toScreamingSnakeCase: "MY_PROPERTY",
            toKebabCase: "my-property",
            toScreamingKebabCase: "MY-PROPERTY",
            toLowercase: "myproperty",
            toUppercase: "MYPROPERTY"
        ),
        // Four words
        ConceptGroup(label: "fourWords",
            camelCase: "myLongPropertyName",
            pascalCase: "MyLongPropertyName",
            snakeCase: "my_long_property_name",
            screamingSnakeCase: "MY_LONG_PROPERTY_NAME",

            toCamelCase: "myLongPropertyName",
            toPascalCase: "MyLongPropertyName",
            toSnakeCase: "my_long_property_name",
            toScreamingSnakeCase: "MY_LONG_PROPERTY_NAME",
            toKebabCase: "my-long-property-name",
            toScreamingKebabCase: "MY-LONG-PROPERTY-NAME",
            toLowercase: "mylongpropertyname",
            toUppercase: "MYLONGPROPERTYNAME"
        ),
        // Acronym in middle
        ConceptGroup(label: "acronymMiddle",
            camelCase: "parseHTTPResponse",
            pascalCase: "ParseHTTPResponse",
            snakeCase: "parse_http_response",
            screamingSnakeCase: "PARSE_HTTP_RESPONSE",

            toCamelCase: "parseHttpResponse",
            toPascalCase: "ParseHttpResponse",
            toSnakeCase: "parse_http_response",
            toScreamingSnakeCase: "PARSE_HTTP_RESPONSE",
            toKebabCase: "parse-http-response",
            toScreamingKebabCase: "PARSE-HTTP-RESPONSE",
            toLowercase: "parsehttpresponse",
            toUppercase: "PARSEHTTPRESPONSE"
        ),
        // Acronym at end
        ConceptGroup(label: "acronymEnd",
            camelCase: "imageURL",
            pascalCase: "ImageURL",
            snakeCase: "image_url",
            screamingSnakeCase: "IMAGE_URL",

            toCamelCase: "imageUrl",
            toPascalCase: "ImageUrl",
            toSnakeCase: "image_url",
            toScreamingSnakeCase: "IMAGE_URL",
            toKebabCase: "image-url",
            toScreamingKebabCase: "IMAGE-URL",
            toLowercase: "imageurl",
            toUppercase: "IMAGEURL"
        ),
        // Numeric in middle
        ConceptGroup(label: "numericMiddle",
            camelCase: "version4Thing",
            pascalCase: "Version4Thing",
            snakeCase: "version4_thing",
            screamingSnakeCase: "VERSION4_THING",

            toCamelCase: "version4Thing",
            toPascalCase: "Version4Thing",
            toSnakeCase: "version4_thing",
            toScreamingSnakeCase: "VERSION4_THING",
            toKebabCase: "version4-thing",
            toScreamingKebabCase: "VERSION4-THING",
            toLowercase: "version4thing",
            toUppercase: "VERSION4THING"
        ),
        // Numeric at end
        ConceptGroup(label: "numericEnd",
            camelCase: "dataPoint22",
            pascalCase: "DataPoint22",
            snakeCase: "data_point22",
            screamingSnakeCase: "DATA_POINT22",

            toCamelCase: "dataPoint22",
            toPascalCase: "DataPoint22",
            toSnakeCase: "data_point22",
            toScreamingSnakeCase: "DATA_POINT22",
            toKebabCase: "data-point22",
            toScreamingKebabCase: "DATA-POINT22",
            toLowercase: "datapoint22",
            toUppercase: "DATAPOINT22"
        ),
        // Acronym at start
        ConceptGroup(label: "acronymStart",
            camelCase: "httpResponse",
            pascalCase: "HTTPResponse",
            snakeCase: "http_response",
            screamingSnakeCase: "HTTP_RESPONSE",

            toCamelCase: "httpResponse",
            toPascalCase: "HttpResponse",
            toSnakeCase: "http_response",
            toScreamingSnakeCase: "HTTP_RESPONSE",
            toKebabCase: "http-response",
            toScreamingKebabCase: "HTTP-RESPONSE",
            toLowercase: "httpresponse",
            toUppercase: "HTTPRESPONSE"
        ),
        // Longer acronym in middle of longer phrase
        ConceptGroup(label: "xmlInPhrase",
            camelCase: "thisIsAnXMLProperty",
            pascalCase: "ThisIsAnXMLProperty",
            snakeCase: "this_is_an_xml_property",
            screamingSnakeCase: "THIS_IS_AN_XML_PROPERTY",

            toCamelCase: "thisIsAnXmlProperty",
            toPascalCase: "ThisIsAnXmlProperty",
            toSnakeCase: "this_is_an_xml_property",
            toScreamingSnakeCase: "THIS_IS_AN_XML_PROPERTY",
            toKebabCase: "this-is-an-xml-property",
            toScreamingKebabCase: "THIS-IS-AN-XML-PROPERTY",
            toLowercase: "thisisanxmlproperty",
            toUppercase: "THISISANXMLPROPERTY"
        ),
        // Single word
        ConceptGroup(label: "singleWord",
            camelCase: "single",
            pascalCase: "Single",
            snakeCase: "single",
            screamingSnakeCase: "SINGLE",

            toCamelCase: "single",
            toPascalCase: "Single",
            toSnakeCase: "single",
            toScreamingSnakeCase: "SINGLE",
            toKebabCase: "single",
            toScreamingKebabCase: "SINGLE",
            toLowercase: "single",
            toUppercase: "SINGLE"
        ),
        // Single word that's an all-caps acronym
        ConceptGroup(label: "singleWordAllCaps",
            camelCase: "url",
            pascalCase: "Url",
            snakeCase: "url",
            screamingSnakeCase: "URL",

            toCamelCase: "url",
            toPascalCase: "Url",
            toSnakeCase: "url",
            toScreamingSnakeCase: "URL",
            toKebabCase: "url",
            toScreamingKebabCase: "URL",
            toLowercase: "url",
            toUppercase: "URL"
        ),
        // Single character
        ConceptGroup(label: "singleChar",
            camelCase: "x",
            pascalCase: "X",
            snakeCase: "x",
            screamingSnakeCase: "X",

            toCamelCase: "x",
            toPascalCase: "X",
            toSnakeCase: "x",
            toScreamingSnakeCase: "X",
            toKebabCase: "x",
            toScreamingKebabCase: "X",
            toLowercase: "x",
            toUppercase: "X"
        ),
        // Diacritic word boundary
        ConceptGroup(label: "diacritic",
            camelCase: "asdfĆqer",
            pascalCase: "AsdfĆqer",
            snakeCase: "asdf_ćqer",
            screamingSnakeCase: "ASDF_ĆQER",

            toCamelCase: "asdfĆqer",
            toPascalCase: "AsdfĆqer",
            toSnakeCase: "asdf_ćqer",
            toScreamingSnakeCase: "ASDF_ĆQER",
            toKebabCase: "asdf-ćqer",
            toScreamingKebabCase: "ASDF-ĆQER",
            toLowercase: "asdfćqer",
            toUppercase: "ASDFĆQER"
        ),
        // Partial caps (word + all-caps tail)
        ConceptGroup(label: "partialCaps",
            camelCase: "partCAPS",
            pascalCase: "PartCAPS",
            snakeCase: "part_caps",
            screamingSnakeCase: "PART_CAPS",

            toCamelCase: "partCaps",
            toPascalCase: "PartCaps",
            toSnakeCase: "part_caps",
            toScreamingSnakeCase: "PART_CAPS",
            toKebabCase: "part-caps",
            toScreamingKebabCase: "PART-CAPS",
            toLowercase: "partcaps",
            toUppercase: "PARTCAPS"
        ),
        // Partial caps switching back
        ConceptGroup(label: "partialCapsSwitchBack",
            camelCase: "partCAPSLowerAGAIN",
            pascalCase: "PartCAPSLowerAGAIN",
            snakeCase: "part_caps_lower_again",
            screamingSnakeCase: "PART_CAPS_LOWER_AGAIN",

            toCamelCase: "partCapsLowerAgain",
            toPascalCase: "PartCapsLowerAgain",
            toSnakeCase: "part_caps_lower_again",
            toScreamingSnakeCase: "PART_CAPS_LOWER_AGAIN",
            toKebabCase: "part-caps-lower-again",
            toScreamingKebabCase: "PART-CAPS-LOWER-AGAIN",
            toLowercase: "partcapsloweragain",
            toUppercase: "PARTCAPSLOWERAGAIN"
        ),
    ]

    // Flatten all concept inputs for parameterized tests.
    // Each entry: (label, input, expected for that convention).
    static let allCamelCaseCases: [(label: String, input: String, expected: String)] = concepts.flatMap { concept in
        concept.allInputs.map { ($0.label, $0.input, concept.toCamelCase) }
    }

    static let allPascalCaseCases: [(label: String, input: String, expected: String)] = concepts.flatMap { concept in
        concept.allInputs.map { ($0.label, $0.input, concept.toPascalCase) }
    }

    static let allSnakeCaseCases: [(label: String, input: String, expected: String)] = concepts.flatMap { concept in
        concept.allInputs.map { ($0.label, $0.input, concept.toSnakeCase) }
    }

    static let allScreamingSnakeCaseCases: [(label: String, input: String, expected: String)] = concepts.flatMap { concept in
        concept.allInputs.map { ($0.label, $0.input, concept.toScreamingSnakeCase) }
    }

    static let allKebabCaseCases: [(label: String, input: String, expected: String)] = concepts.flatMap { concept in
        concept.allInputs.map { ($0.label, $0.input, concept.toKebabCase) }
    }

    static let allScreamingKebabCaseCases: [(label: String, input: String, expected: String)] = concepts.flatMap { concept in
        concept.allInputs.map { ($0.label, $0.input, concept.toScreamingKebabCase) }
    }

    static let allLowercaseCases: [(label: String, input: String, expected: String)] = concepts.flatMap { concept in
        concept.allInputs.map { ($0.label, $0.input, concept.toLowercase) }
    }

    static let allUppercaseCases: [(label: String, input: String, expected: String)] = concepts.flatMap { concept in
        concept.allInputs.map { ($0.label, $0.input, concept.toUppercase) }
    }

    // MARK: - Full matrix tests

    @Test(arguments: allCamelCaseCases)
    func camelCase(label: String, input: String, expected: String) {
        #expect(
            applyNamingConvention(input, convention: .camelCase) == expected,
            "\(label): \"\(input)\" → camelCase should be \"\(expected)\""
        )
    }

    @Test(arguments: allPascalCaseCases)
    func pascalCase(label: String, input: String, expected: String) {
        #expect(
            applyNamingConvention(input, convention: .PascalCase) == expected,
            "\(label): \"\(input)\" → PascalCase should be \"\(expected)\""
        )
    }

    @Test(arguments: allSnakeCaseCases)
    func snakeCase(label: String, input: String, expected: String) {
        #expect(
            applyNamingConvention(input, convention: .snake_case) == expected,
            "\(label): \"\(input)\" → snake_case should be \"\(expected)\""
        )
    }

    @Test(arguments: allScreamingSnakeCaseCases)
    func screamingSnakeCase(label: String, input: String, expected: String) {
        #expect(
            applyNamingConvention(input, convention: .SCREAMING_SNAKE_CASE) == expected,
            "\(label): \"\(input)\" → SCREAMING_SNAKE_CASE should be \"\(expected)\""
        )
    }

    @Test(arguments: allKebabCaseCases)
    func kebabCase(label: String, input: String, expected: String) {
        #expect(
            applyNamingConvention(input, convention: .kebab_case) == expected,
            "\(label): \"\(input)\" → kebab-case should be \"\(expected)\""
        )
    }

    @Test(arguments: allScreamingKebabCaseCases)
    func screamingKebabCase(label: String, input: String, expected: String) {
        #expect(
            applyNamingConvention(input, convention: .SCREAMING_KEBAB_CASE) == expected,
            "\(label): \"\(input)\" → SCREAMING-KEBAB-CASE should be \"\(expected)\""
        )
    }

    @Test(arguments: allLowercaseCases)
    func lowercase(label: String, input: String, expected: String) {
        #expect(
            applyNamingConvention(input, convention: .lowercase) == expected,
            "\(label): \"\(input)\" → lowercase should be \"\(expected)\""
        )
    }

    @Test(arguments: allUppercaseCases)
    func uppercase(label: String, input: String, expected: String) {
        #expect(
            applyNamingConvention(input, convention: .UPPERCASE) == expected,
            "\(label): \"\(input)\" → UPPERCASE should be \"\(expected)\""
        )
    }

    // MARK: - .default convention (pass-through)

    @Test(arguments: concepts.flatMap(\.allInputs))
    func defaultReturnsOriginal(label: String, input: String) {
        #expect(applyNamingConvention(input, convention: .default) == input)
    }

    // MARK: - Leading/trailing underscore preservation

    @Test func leadingUnderscoreSnakeCase() {
        #expect(applyNamingConvention("_myProperty", convention: .snake_case) == "_my_property")
    }

    @Test func trailingUnderscoreSnakeCase() {
        #expect(applyNamingConvention("myProperty_", convention: .snake_case) == "my_property_")
    }

    @Test func bothLeadingAndTrailingUnderscores() {
        #expect(applyNamingConvention("_myProperty_", convention: .snake_case) == "_my_property_")
    }

    @Test func multipleLeadingUnderscores() {
        #expect(applyNamingConvention("__myProperty", convention: .snake_case) == "__my_property")
    }

    @Test func multipleTrailingUnderscores() {
        #expect(applyNamingConvention("myProperty__", convention: .snake_case) == "my_property__")
    }

    @Test func multipleLeadingAndTrailingUnderscores() {
        #expect(applyNamingConvention("__myProperty__", convention: .snake_case) == "__my_property__")
    }

    @Test func leadingUnderscorePascalCase() {
        #expect(applyNamingConvention("_myProperty", convention: .PascalCase) == "_MyProperty")
    }

    @Test func leadingUnderscoreCamelCase() {
        #expect(applyNamingConvention("_MyProperty", convention: .camelCase) == "_myProperty")
    }

    @Test func leadingUnderscoreKebabCase() {
        #expect(applyNamingConvention("_myProperty", convention: .kebab_case) == "_my-property")
    }

    @Test func leadingUnderscoreUppercase() {
        #expect(applyNamingConvention("_myProperty", convention: .UPPERCASE) == "_MYPROPERTY")
    }

    @Test func leadingUnderscoreScreamingSnakeCase() {
        #expect(applyNamingConvention("_oneTwoThree", convention: .SCREAMING_SNAKE_CASE) == "_ONE_TWO_THREE")
    }

    @Test func allUnderscoresReturnsOriginal() {
        #expect(applyNamingConvention("___", convention: .snake_case) == "___")
    }

    @Test func singleUnderscoreReturnsOriginal() {
        #expect(applyNamingConvention("_", convention: .snake_case) == "_")
    }

    @Test func doubleUnderscoreReturnsOriginal() {
        #expect(applyNamingConvention("__", convention: .camelCase) == "__")
    }

    // MARK: - Edge cases

    @Test func emptyString() {
        #expect(applyNamingConvention("", convention: .snake_case) == "")
    }
}
