//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2022-2023 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

#if canImport(TestSupport)
import TestSupport
#endif

#if FOUNDATION_FRAMEWORK

fileprivate protocol PredicateCodingConfigurationProviding : EncodingConfigurationProviding, DecodingConfigurationProviding where EncodingConfiguration == PredicateCodableConfiguration, DecodingConfiguration == PredicateCodableConfiguration {
    static var config: PredicateCodableConfiguration { get }
}

extension PredicateCodingConfigurationProviding {
    static var encodingConfiguration: PredicateCodableConfiguration {
        Self.config
    }
    
    static var decodingConfiguration: PredicateCodableConfiguration {
        Self.config
    }
}

extension DecodingError {
    fileprivate var debugDescription: String? {
        switch self {
        case .typeMismatch(_, let context):
            return context.debugDescription
        case .valueNotFound(_, let context):
            return context.debugDescription
        case .keyNotFound(_, let context):
            return context.debugDescription
        case .dataCorrupted(let context):
            return context.debugDescription
        default:
            return nil
        }
    }
}

extension PredicateExpressions {
    fileprivate struct TestNonStandardExpression : PredicateExpression, Decodable {
        typealias Output = Bool
        
        func evaluate(_ bindings: PredicateBindings) throws -> Bool {
            true
        }
    }
}

@available(macOS 9999, iOS 9999, tvOS 9999, watchOS 9999, *)
final class PredicateCodableTests: XCTestCase {
    
    struct Object : Equatable, PredicateCodableKeyPathProviding {
        var a: Int
        var b: String
        var c: Double
        var d: Int
        var e: Character
        var f: Bool
        var g: [Int]
        var h: Object2
        
        static var predicateCodableKeyPaths: [String : PartialKeyPath<PredicateCodableTests.Object>] {
            [
                "Object.f" : \.f,
                "Object.g" : \.g,
                "Object.h" : \.h
            ]
        }
        
        static let example = Object(a: 1, b: "Hello", c: 2.3, d: 4, e: "J", f: true, g: [9, 1, 4], h: Object2(a: 1, b: "Foo"))
    }
    
    struct Object2 : Equatable, PredicateCodableKeyPathProviding {
        var a: Int
        var b: String
        
        static var predicateCodableKeyPaths: [String : PartialKeyPath<PredicateCodableTests.Object2>] {
            ["Object2.a" : \.a]
        }
    }
    
    struct MinimalConfig : PredicateCodingConfigurationProviding {
        static let config = PredicateCodableConfiguration.standardConfiguration
    }
    
    struct StandardConfig : PredicateCodingConfigurationProviding {
        static let config = {
            var config = PredicateCodableConfiguration.standardConfiguration
            config.allowType(Object.self, identifier: "Foundation.PredicateCodableTests.Object")
            config.allowKeyPath(\Object.a, identifier: "Object.a")
            config.allowKeyPath(\Object.b, identifier: "Object.b")
            config.allowKeyPath(\Object.c, identifier: "Object.c")
            return config
        }()
    }
    
    struct ProvidedKeyPathConfig : PredicateCodingConfigurationProviding {
        static let config = {
            var config = PredicateCodableConfiguration.standardConfiguration
            config.allowType(Object.self, identifier: "Foundation.PredicateCodableTests.Object")
            config.allowKeyPathsForPropertiesProvided(by: Object.self)
            return config
        }()
    }
    
    struct RecursiveProvidedKeyPathConfig : PredicateCodingConfigurationProviding {
        static let config = {
            var config = PredicateCodableConfiguration.standardConfiguration
            config.allowType(Object.self, identifier: "Foundation.PredicateCodableTests.Object")
            config.allowKeyPathsForPropertiesProvided(by: Object.self, recursive: true)
            return config
        }()
    }
    
    struct EmptyConfig : PredicateCodingConfigurationProviding {
        static let config = PredicateCodableConfiguration()
    }
    
    struct UUIDConfig : PredicateCodingConfigurationProviding {
        static let config = {
            var config = PredicateCodableConfiguration.standardConfiguration
            config.allowType(UUID.self, identifier: "Foundation.UUID")
            return config
        }()
    }
    
    struct MismatchedKeyPathConfig : PredicateCodingConfigurationProviding {
        static let config = {
            var config = PredicateCodableConfiguration.standardConfiguration
            // Intentionally provide a keypath that doesn't match the signature of the identifier/
            config.allowKeyPath(\Object.b, identifier: "Object.a")
            return config
        }()
    }
    
    struct TestExpressionConfig : PredicateCodingConfigurationProviding {
        static let config = {
            var config = PredicateCodableConfiguration.standardConfiguration
            config.allowPartialType(PredicateExpressions.TestNonStandardExpression.self, identifier: "PredicateExpressions.TestNonStandardExpression")
            return config
        }()
    }
    
    private struct Wrapper<ConfigurationProvider : PredicateCodingConfigurationProviding, each Input> : Codable {
        let predicate: Predicate<repeat each Input>
        
        init(_ predicate: Predicate<repeat each Input>, configuration: ConfigurationProvider.Type) {
            self.predicate = predicate
        }
        
        init(from decoder: Decoder) throws {
            var container = try decoder.unkeyedContainer()
            predicate = try container.decode(Predicate<repeat each Input>.self, configuration: ConfigurationProvider.self)
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.unkeyedContainer()
            try container.encode(predicate, configuration: ConfigurationProvider.self)
        }
    }
    
    @discardableResult
    private func _encodeDecode<EncodingConfigurationProvider: PredicateCodingConfigurationProviding, DecodingConfigurationProvider: PredicateCodingConfigurationProviding, each Input>(_ predicate: Predicate<repeat each Input>, encoding encodingConfig: EncodingConfigurationProvider.Type, decoding decodingConfig: DecodingConfigurationProvider.Type) throws -> Predicate<repeat each Input> {
        let encoder = JSONEncoder()
        let data = try encoder.encode(Wrapper(predicate, configuration: encodingConfig))
        let decoder = JSONDecoder()
        return try decoder.decode(Wrapper<DecodingConfigurationProvider, repeat each Input>.self, from: data).predicate
    }
    
    @discardableResult
    private func _encodeDecode<ConfigurationProvider: PredicateCodingConfigurationProviding, each Input>(_ predicate: Predicate<repeat each Input>, for configuration: ConfigurationProvider.Type) throws -> Predicate<repeat each Input> {
        let encoder = JSONEncoder()
        let data = try encoder.encode(Wrapper(predicate, configuration: configuration))
        let decoder = JSONDecoder()
        return try decoder.decode(Wrapper<ConfigurationProvider, repeat each Input>.self, from: data).predicate
    }
    
    @discardableResult
    private func _encodeDecode<each Input>(_ predicate: Predicate<repeat each Input>) throws -> Predicate<repeat each Input> {
        let encoder = JSONEncoder()
        let data = try encoder.encode(predicate)
        let decoder = JSONDecoder()
        return try decoder.decode(Predicate<repeat each Input>.self, from: data)
    }
    
    func testBasicEncodeDecode() throws {
        let predicate = #Predicate<Object> {
            $0.a == 2
        }
        
        let decoded = try _encodeDecode(predicate, for: StandardConfig.self)
        var object = Object.example
        XCTAssertEqual(try predicate.evaluate(object), try decoded.evaluate(object))
        object.a = 2
        XCTAssertEqual(try predicate.evaluate(object), try decoded.evaluate(object))
        object.a = 3
        XCTAssertEqual(try predicate.evaluate(object), try decoded.evaluate(object))
        
        XCTAssertThrowsError(try _encodeDecode(predicate, for: EmptyConfig.self))
        XCTAssertThrowsError(try _encodeDecode(predicate))
    }
    
    func testDisallowedKeyPath() throws {
        var predicate = #Predicate<Object> {
            $0.f
        }
        
        XCTAssertThrowsError(try _encodeDecode(predicate))
        XCTAssertThrowsError(try _encodeDecode(predicate, for: StandardConfig.self))
        
        predicate = #Predicate<Object> {
            $0.a == 1
        }
        XCTAssertThrowsError(try _encodeDecode(predicate, encoding: StandardConfig.self, decoding: MinimalConfig.self)) {
            guard let decodingError = $0 as? DecodingError else {
                XCTFail("Incorrect error thrown: \($0)")
                return
            }
            XCTAssertEqual(decodingError.debugDescription, "A keypath for the 'Object.a' identifier is not in the provided allowlist")
        }
    }
    
    func testKeyPathTypeMismatch() throws {
        let predicate = #Predicate<Object> {
            $0.a == 2
        }
        
        try _encodeDecode(predicate, for: StandardConfig.self)
        XCTAssertThrowsError(try _encodeDecode(predicate, encoding: StandardConfig.self, decoding: MismatchedKeyPathConfig.self)) {
            guard let decodingError = $0 as? DecodingError else {
                XCTFail("Incorrect error thrown: \($0)")
                return
            }
            XCTAssertEqual(decodingError.debugDescription, "Key path '\\Object.b' (KeyPath<\(_typeName(Object.self)), Swift.String>) for identifier 'Object.a' did not match the expression's requirement for KeyPath<\(_typeName(Object.self)), Swift.Int>")
        }
    }
    
    func testDisallowedType() throws {
        let uuid = UUID()
        let predicate = #Predicate<Object> { obj in
            uuid == uuid
        }
        
        XCTAssertThrowsError(try _encodeDecode(predicate))
        XCTAssertThrowsError(try _encodeDecode(predicate, for: StandardConfig.self))
        XCTAssertThrowsError(try _encodeDecode(predicate, encoding: UUIDConfig.self, decoding: MinimalConfig.self)) {
            XCTAssertEqual(String(describing: $0), "The 'Foundation.UUID' identifier is not in the provided allowlist (required by /PredicateExpressions.TypeCheck)")
        }
        
        let decoded = try _encodeDecode(predicate, for: UUIDConfig.self)
        XCTAssertEqual(try decoded.evaluate(.example), try predicate.evaluate(.example))
    }
    
    func testProvidedProperties() throws {
        var predicate = #Predicate<Object> {
            $0.a == 2
        }
        
        XCTAssertThrowsError(try _encodeDecode(predicate, for: ProvidedKeyPathConfig.self))
        XCTAssertThrowsError(try _encodeDecode(predicate, for: RecursiveProvidedKeyPathConfig.self))
        
        predicate = #Predicate<Object> {
            $0.f == false
        }
        
        var decoded = try _encodeDecode(predicate, for: ProvidedKeyPathConfig.self)
        XCTAssertEqual(try decoded.evaluate(.example), try predicate.evaluate(.example))
        decoded = try _encodeDecode(predicate, for: RecursiveProvidedKeyPathConfig.self)
        XCTAssertEqual(try decoded.evaluate(.example), try predicate.evaluate(.example))
        
        predicate = #Predicate<Object> {
            $0.h.a == 1
        }
        
        XCTAssertThrowsError(try _encodeDecode(predicate, for: ProvidedKeyPathConfig.self))
        decoded = try _encodeDecode(predicate, for: RecursiveProvidedKeyPathConfig.self)
        XCTAssertEqual(try decoded.evaluate(.example), try predicate.evaluate(.example))
    }
    
    func testDefaultAllowlist() throws {
        var predicate = #Predicate<String> {
            $0.isEmpty
        }
        var decoded = try _encodeDecode(predicate)
        XCTAssertEqual(try decoded.evaluate("Hello world"), try predicate.evaluate("Hello world"))
        
        predicate = #Predicate<String> {
            $0.count > 2
        }
        decoded = try _encodeDecode(predicate)
        XCTAssertEqual(try decoded.evaluate("Hello world"), try predicate.evaluate("Hello world"))
        
        let predicate2 = #Predicate<Object> {
            $0 == $0
        }
        let decoded2 = try _encodeDecode(predicate2)
        XCTAssertEqual(try decoded2.evaluate(.example), try predicate2.evaluate(.example))
        
        
        var predicate3 = #Predicate<Array<String>> {
            $0.isEmpty
        }
        var decoded3 = try _encodeDecode(predicate3)
        XCTAssertEqual(try decoded3.evaluate(["A", "B", "C"]), try predicate3.evaluate(["A", "B", "C"]))
        
        predicate3 = #Predicate<Array<String>> {
            $0.count == 2
        }
        decoded3 = try _encodeDecode(predicate3)
        XCTAssertEqual(try decoded3.evaluate(["A", "B", "C"]), try predicate3.evaluate(["A", "B", "C"]))
        
        var predicate4 = #Predicate<Dictionary<String, Int>> {
            $0.isEmpty
        }
        var decoded4 = try _encodeDecode(predicate4)
        XCTAssertEqual(try decoded4.evaluate(["A": 1, "B": 2, "C": 3]), try predicate4.evaluate(["A": 1, "B": 2, "C": 3]))
        
        predicate4 = #Predicate<Dictionary<String, Int>> {
            $0.count == 2
        }
        decoded4 = try _encodeDecode(predicate4)
        XCTAssertEqual(try decoded4.evaluate(["A": 1, "B": 2, "C": 3]), try predicate4.evaluate(["A": 1, "B": 2, "C": 3]))
    }
    
    func testMalformedData() {
        func _malformedDecode<T: PredicateCodingConfigurationProviding>(_ json: String, config: T.Type = StandardConfig.self, reason: String, file: StaticString = #file, line: UInt = #line) {
            let data = Data(json.utf8)
            let decoder = JSONDecoder()
            XCTAssertThrowsError(try decoder.decode(Wrapper<T, Object>.self, from: data), file: file, line: line) {
                XCTAssertTrue(String(describing: $0).contains(reason), "Error '\($0)' did not contain reason '\(reason)'", file: file, line: line)
            }
        }
        
        // expression is not a PredicateExpression
        _malformedDecode(
            """
            [
              [
                {
                  "variable" : [{
                    "key" : 0
                  }],
                  "expression" : 0,
                  "structure" : "Swift.Int"
                }
              ]
            ]
            """,
            reason: "This expression is unsupported by this predicate"
        )
        
        // conjunction is missing generic arguments
        _malformedDecode(
            """
            [
              [
                {
                  "variable" : [{
                    "key" : 0
                  }],
                  "expression" : 0,
                  "structure" : "PredicateExpressions.Conjunction"
                }
              ]
            ]
            """,
            reason: "Reconstruction of 'Conjunction' with the arguments [] failed"
        )
        
        // conjunction's generic arguments don't match constraint requirements
        _malformedDecode(
            """
            [
              [
                {
                  "variable" : [{
                    "key" : 0
                  }],
                  "expression" : 0,
                  "structure" : {
                    "identifier": "PredicateExpressions.Conjunction",
                    "args": [
                      "Swift.Int",
                      "Swift.Int"
                    ]
                  }
                }
              ]
            ]
            """,
            reason: "Reconstruction of 'Conjunction' with the arguments [Swift.Int, Swift.Int] failed"
        )
        
        // expression is not a StandardPredicateExpression
        _malformedDecode(
            """
            [
              [
                {
                  "variable" : [{
                    "key" : 0
                  }],
                  "expression" : 0,
                  "structure" : "PredicateExpressions.TestNonStandardExpression"
                }
              ]
            ]
            """,
            config: TestExpressionConfig.self,
            reason: "This expression is unsupported by this predicate"
        )
    }
    
    func testBasicVariadic() throws {
        let predicate = #Predicate<Object, Object> {
            $0.a == 2 && $1.a == 3
        }
        
        let decoded = try _encodeDecode(predicate, for: StandardConfig.self)
        var object = Object.example
        let object2 = Object.example
        XCTAssertEqual(try predicate.evaluate(object, object2), try decoded.evaluate(object, object2))
        object.a = 2
        XCTAssertEqual(try predicate.evaluate(object, object2), try decoded.evaluate(object, object2))
        object.a = 3
        XCTAssertEqual(try predicate.evaluate(object, object2), try decoded.evaluate(object, object2))
        
        XCTAssertThrowsError(try _encodeDecode(predicate, for: EmptyConfig.self))
        XCTAssertThrowsError(try _encodeDecode(predicate))
    }
    
    func testCapturedVariadicTypes() throws {
        struct A<each T> : Equatable, Codable {
            init(_: repeat (each T).Type) {}
            
            func encode(to encoder: Encoder) throws {
                var container = encoder.singleValueContainer()
                try container.encodeNil()
            }
            
            init(from decoder: Decoder) throws {
                let container = try decoder.singleValueContainer()
                guard container.decodeNil() else {
                    throw DecodingError.dataCorrupted(.init(codingPath: container.codingPath, debugDescription: "Did not find encoded nil"))
                }
            }
        }

        let a = A(String.self, Int.self)

        let predicate = #Predicate<Int> { _ in
            a == a
        }

        let encoder = JSONEncoder()
        var config = PredicateCodableConfiguration.standardConfiguration
        config.allowPartialType(A< >.self, identifier: "PredicateCodableTests.A")
        XCTAssertThrowsError(try encoder.encode(predicate, configuration: config)) {
            XCTAssertTrue(String(describing: $0).contains("type is not allowed because it contains type pack parameters"))
        }
        
        let json = """
        [
          {
            "expression" : [
              null,
              null
            ],
            "structure" : {
              "identifier" : "PredicateExpressions.Equal",
              "args" : [
                {
                  "identifier" : "PredicateExpressions.Value",
                  "args" : [
                    {
                      "identifier": "PredicateCodableTests.A",
                      "args": [
                        "Swift.String",
                        "Swift.Int"
                      ]
                    }
                  ]
                },
                {
                  "args" : [
                    {
                      "identifier": "PredicateCodableTests.A",
                      "args": [
                        "Swift.String",
                        "Swift.Int"
                      ]
                    }
                  ],
                  "identifier" : "PredicateExpressions.Value"
                }
              ]
            },
            "variable" : [
              {
                "key" : 0
              }
            ]
          }
        ]
        """
        
        let decoder = JSONDecoder()
        XCTAssertThrowsError(try decoder.decode(Predicate<Int>.self, from: json.data(using: .utf8)!, configuration: config)) {
            XCTAssertTrue(String(describing: $0).contains("type is not allowed because it contains type pack parameters"))
        }
    }
}

#endif // FOUNDATION_FRAMEWORK
