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

#if FOUNDATION_FRAMEWORK

import Testing
import Foundation

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

struct PredicateCodableTests {
    
    struct Object : Equatable, PredicateCodableKeyPathProviding {
        var a: Int
        var b: String
        var c: Double
        var d: Int
        var e: Character
        var f: Bool
        var g: [Int]
        var h: Object2
        
        static var predicateCodableKeyPaths: [String : PartialKeyPath<PredicateCodableTests.Object> & Sendable] {
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
        
        static var predicateCodableKeyPaths: [String : PartialKeyPath<PredicateCodableTests.Object2> & Sendable] {
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
    
    @discardableResult
    private func _encodeDecode<
        EncodingConfigurationProvider: PredicateCodingConfigurationProviding,
        DecodingConfigurationProvider: PredicateCodingConfigurationProviding,
        T: CodableWithConfiguration
    >(
        _ value: T,
        encoding encodingConfig: EncodingConfigurationProvider.Type,
        decoding decodingConfig: DecodingConfigurationProvider.Type
    ) throws -> T where
        T.EncodingConfiguration == EncodingConfigurationProvider.EncodingConfiguration,
        T.DecodingConfiguration == DecodingConfigurationProvider.DecodingConfiguration
    {
        let encoder = JSONEncoder()
        let data = try encoder.encode(CodableConfiguration(wrappedValue: value, from: encodingConfig))
        let decoder = JSONDecoder()
        return try decoder.decode(CodableConfiguration<T, DecodingConfigurationProvider>.self, from: data).wrappedValue
    }
    
    @discardableResult
    private func _encodeDecode<
        ConfigurationProvider: PredicateCodingConfigurationProviding,
        T: CodableWithConfiguration
    >(
        _ value: T,
        for configuration: ConfigurationProvider.Type
    ) throws -> T where
        T.EncodingConfiguration == ConfigurationProvider.EncodingConfiguration,
        T.DecodingConfiguration == ConfigurationProvider.DecodingConfiguration
    {
        try _encodeDecode(value, encoding: configuration, decoding: configuration)
    }
    
    @discardableResult
    private func _encodeDecode<T: Codable>(_ value: T) throws -> T {
        let encoder = JSONEncoder()
        let data = try encoder.encode(value)
        let decoder = JSONDecoder()
        return try decoder.decode(T.self, from: data)
    }
    
    @Test func testBasicEncodeDecode() throws {
        let predicate = #Predicate<Object> {
            $0.a == 2
        }
        
        let decoded = try _encodeDecode(predicate, for: StandardConfig.self)
        var object = Object.example
        #expect(try predicate.evaluate(object) == decoded.evaluate(object))
        object.a = 2
        #expect(try predicate.evaluate(object) == decoded.evaluate(object))
        object.a = 3
        #expect(try predicate.evaluate(object) == decoded.evaluate(object))
        
        #expect(throws: (any Error).self) {
            try _encodeDecode(predicate, for: EmptyConfig.self)
        }
        #expect(throws: (any Error).self) {
            try _encodeDecode(predicate)
        }
    }
    
    @Test func testDisallowedKeyPath() throws {
        var predicate = #Predicate<Object> {
            $0.f
        }
        
        #expect(throws: (any Error).self) {
            try _encodeDecode(predicate)
        }
        #expect(throws: (any Error).self) {
            try _encodeDecode(predicate, for: StandardConfig.self)
        }
        
        predicate = #Predicate<Object> {
            $0.a == 1
        }
        #expect {
            try _encodeDecode(predicate, encoding: StandardConfig.self, decoding: MinimalConfig.self)
        } throws: {
            let decodingError = try #require($0 as? DecodingError)
            return decodingError.debugDescription == "A keypath for the 'Object.a' identifier is not in the provided allowlist"
        }
    }
    
    @Test func testKeyPathTypeMismatch() throws {
        let predicate = #Predicate<Object> {
            $0.a == 2
        }
        
        try _encodeDecode(predicate, for: StandardConfig.self)
        #expect {
            try _encodeDecode(predicate, encoding: StandardConfig.self, decoding: MismatchedKeyPathConfig.self)
        } throws: {
            let decodingError = try #require($0 as? DecodingError)
            return decodingError.debugDescription == "Key path '\\Object.b' (KeyPath<\(_typeName(Object.self)), Swift.String>) for identifier 'Object.a' did not match the expression's requirement for KeyPath<\(_typeName(Object.self)), Swift.Int>"
        }
    }
    
    @Test func testDisallowedType() throws {
        let uuid = UUID()
        let predicate = #Predicate<Object> { obj in
            uuid == uuid
        }
        
        #expect(throws: (any Error).self) {
            try _encodeDecode(predicate)
        }
        #expect(throws: (any Error).self) {
            try _encodeDecode(predicate, for: StandardConfig.self)
        }
        #expect {
            try _encodeDecode(predicate, encoding: UUIDConfig.self, decoding: MinimalConfig.self)
        } throws: {
            String(describing: $0) == "The 'Foundation.UUID' identifier is not in the provided allowlist (required by /PredicateExpressions.Equal/PredicateExpressions.Value)"
        }
        
        let decoded = try _encodeDecode(predicate, for: UUIDConfig.self)
        #expect(try decoded.evaluate(.example) == predicate.evaluate(.example))
    }
    
    @Test func testProvidedProperties() throws {
        var predicate = #Predicate<Object> {
            $0.a == 2
        }
        
        #expect(throws: (any Error).self) {
            try _encodeDecode(predicate, for: ProvidedKeyPathConfig.self)
        }
        #expect(throws: (any Error).self) {
            try _encodeDecode(predicate, for: RecursiveProvidedKeyPathConfig.self)
        }
        
        predicate = #Predicate<Object> {
            $0.f == false
        }
        
        var decoded = try _encodeDecode(predicate, for: ProvidedKeyPathConfig.self)
        #expect(try decoded.evaluate(.example) == predicate.evaluate(.example))
        decoded = try _encodeDecode(predicate, for: RecursiveProvidedKeyPathConfig.self)
        #expect(try decoded.evaluate(.example) == predicate.evaluate(.example))
        
        predicate = #Predicate<Object> {
            $0.h.a == 1
        }
        
        #expect(throws: (any Error).self) {
            try _encodeDecode(predicate, for: ProvidedKeyPathConfig.self)
        }
        decoded = try _encodeDecode(predicate, for: RecursiveProvidedKeyPathConfig.self)
        #expect(try decoded.evaluate(.example) == predicate.evaluate(.example))
    }
    
    @Test func testDefaultAllowlist() throws {
        var predicate = #Predicate<String> {
            $0.isEmpty
        }
        var decoded = try _encodeDecode(predicate)
        #expect(try decoded.evaluate("Hello world") == predicate.evaluate("Hello world"))
        
        predicate = #Predicate<String> {
            $0.count > 2
        }
        decoded = try _encodeDecode(predicate)
        #expect(try decoded.evaluate("Hello world") == predicate.evaluate("Hello world"))
        
        predicate = #Predicate<String> {
            $0.contains(/[a-z]/)
        }
        decoded = try _encodeDecode(predicate)
        #expect(try decoded.evaluate("Hello world") == predicate.evaluate("Hello world"))
        
        let predicate2 = #Predicate<Object> {
            $0 == $0
        }
        let decoded2 = try _encodeDecode(predicate2)
        #expect(try decoded2.evaluate(.example) == predicate2.evaluate(.example))
        
        
        var predicate3 = #Predicate<Array<String>> {
            $0.isEmpty
        }
        var decoded3 = try _encodeDecode(predicate3)
        #expect(try decoded3.evaluate(["A", "B", "C"]) == predicate3.evaluate(["A", "B", "C"]))
        
        predicate3 = #Predicate<Array<String>> {
            $0.count == 2
        }
        decoded3 = try _encodeDecode(predicate3)
        #expect(try decoded3.evaluate(["A", "B", "C"]) == predicate3.evaluate(["A", "B", "C"]))
        
        var predicate4 = #Predicate<Dictionary<String, Int>> {
            $0.isEmpty
        }
        var decoded4 = try _encodeDecode(predicate4)
        #expect(try decoded4.evaluate(["A": 1, "B": 2, "C": 3]) == predicate4.evaluate(["A": 1, "B": 2, "C": 3]))
        
        predicate4 = #Predicate<Dictionary<String, Int>> {
            $0.count == 2
        }
        decoded4 = try _encodeDecode(predicate4)
        #expect(try decoded4.evaluate(["A": 1, "B": 2, "C": 3]) == predicate4.evaluate(["A": 1, "B": 2, "C": 3]))
        
        let predicate5 = #Predicate<Int> {
            (0 ..< 4).contains($0)
        }
        let decoded5 = try _encodeDecode(predicate5)
        #expect(try decoded5.evaluate(2) == predicate5.evaluate(2))
    }
    
    @Test func testMalformedData() {
        func _malformedDecode<T: PredicateCodingConfigurationProviding>(_ json: String, config: T.Type = StandardConfig.self, reason: String, sourceLocation: SourceLocation = #_sourceLocation) {
            let data = Data(json.utf8)
            let decoder = JSONDecoder()
            #expect(sourceLocation: sourceLocation) {
                try decoder.decode(CodableConfiguration<Predicate<Object>, T>.self, from: data)
            } throws: {
                String(describing: $0).contains(reason)
            }
        }
        
        // expression is not a PredicateExpression
        _malformedDecode(
            """
            [
                {
                  "variable" : [{
                    "key" : 0
                  }],
                  "expression" : 0,
                  "structure" : "Swift.Int"
                }
            ]
            """,
            reason: "This type of this expression is unsupported"
        )
        
        // conjunction is missing generic arguments
        _malformedDecode(
            """
            [
              {
                "variable" : [{
                  "key" : 0
                }],
                "expression" : 0,
                "structure" : "PredicateExpressions.Conjunction"
              }
            ]
            """,
            reason: "Reconstruction of 'Conjunction' with the arguments [] failed"
        )
        
        // conjunction's generic arguments don't match constraint requirements
        _malformedDecode(
            """
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
            """,
            reason: "Reconstruction of 'Conjunction' with the arguments [Swift.Int, Swift.Int] failed"
        )
        
        // expression is not a StandardPredicateExpression
        _malformedDecode(
            """
            [
              {
                "variable" : [{
                  "key" : 0
                }],
                "expression" : 0,
                "structure" : "PredicateExpressions.TestNonStandardExpression"
              }
            ]
            """,
            config: TestExpressionConfig.self,
            reason: "This expression is unsupported by this predicate"
        )
    }
    
    @Test func testBasicVariadic() throws {
        let predicate = #Predicate<Object, Object> {
            $0.a == 2 && $1.a == 3
        }
        
        let decoded = try _encodeDecode(predicate, for: StandardConfig.self)
        var object = Object.example
        let object2 = Object.example
        #expect(try predicate.evaluate(object, object2) == decoded.evaluate(object, object2))
        object.a = 2
        #expect(try predicate.evaluate(object, object2) == decoded.evaluate(object, object2))
        object.a = 3
        #expect(try predicate.evaluate(object, object2) == decoded.evaluate(object, object2))
        
        #expect(throws: (any Error).self) {
            try _encodeDecode(predicate, for: EmptyConfig.self)
        }
        #expect(throws: (any Error).self) {
            try _encodeDecode(predicate)
        }
    }
    
    @Test func testCapturedVariadicTypes() throws {
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
        

        struct CustomConfig : PredicateCodingConfigurationProviding {
            static let config = {
                var configuration = PredicateCodableConfiguration.standardConfiguration
                configuration.allowPartialType(A< >.self, identifier: "PredicateCodableTests.A")
                return configuration
            }()
        }
        
        let decoded = try _encodeDecode(predicate, for: CustomConfig.self)
        #expect(try decoded.evaluate(2) == predicate.evaluate(2))
    }
    
    @Test func testNestedPredicates() throws {
        let predicateA = #Predicate<Object> {
            $0.a == 3
        }
        
        let predicateB = #Predicate<Object> {
            predicateA.evaluate($0) && $0.a > 2
        }
        
        let decoded = try _encodeDecode(predicateB, for: StandardConfig.self)
        
        let objects = [
            Object(a: 3, b: "abc", c: 0.0, d: 0, e: "c", f: true, g: [1, 3], h: Object2(a: 1, b: "Foo")),
            Object(a: 2, b: "abc", c: 0.0, d: 0, e: "c", f: true, g: [1, 3], h: Object2(a: 1, b: "Foo")),
            Object(a: 3, b: "abc", c: 0.0, d: 0, e: "c", f: true, g: [1, 3], h: Object2(a: 1, b: "Foo")),
            Object(a: 2, b: "abc", c: 0.0, d: 0, e: "c", f: true, g: [1, 3], h: Object2(a: 1, b: "Foo")),
            Object(a: 4, b: "abc", c: 0.0, d: 0, e: "c", f: true, g: [1, 3], h: Object2(a: 1, b: "Foo"))
        ]
        
        for object in objects {
            #expect(try decoded.evaluate(object) == predicateB.evaluate(object), "Evaluation failed to produce equal results for \(object)")
        }
    }
    
    @Test func testNestedPredicateRestrictedConfiguration() throws {
        struct RestrictedBox<each T> : Codable {
            let predicate: Predicate<repeat each T>
            
            func encode(to encoder: any Encoder) throws {
                var container = encoder.unkeyedContainer()
                // Restricted empty configuration
                try container.encode(predicate, configuration: PredicateCodableConfiguration())
            }
            
            init(_ predicate: Predicate<repeat each T>) {
                self.predicate = predicate
            }
            
            init(from decoder: any Decoder) throws {
                var container = try decoder.unkeyedContainer()
                self.predicate = try container.decode(Predicate<repeat each T>.self, configuration: PredicateCodableConfiguration())
            }
        }
        
        let predicateA = #Predicate<Object> {
            $0.a == 3
        }
        let box = RestrictedBox(predicateA)
        
        let predicateB = #Predicate<Object> {
            box.predicate.evaluate($0) && $0.a > 2
        }
        
        struct CustomConfig : PredicateCodingConfigurationProviding {
            static let config = {
                var configuration = PredicateCodableConfiguration.standardConfiguration
                configuration.allowKeyPathsForPropertiesProvided(by: PredicateCodableTests.Object.self)
                configuration.allowKeyPath(\RestrictedBox<Object>.predicate, identifier: "RestrictedBox.Predicate")
                return configuration
            }()
        }
        
        // Throws an error because the sub-predicate's configuration won't contain anything in the allowlist
        #expect(throws: (any Error).self) {
            try _encodeDecode(predicateB, for: CustomConfig.self)
        }
    }
    
    @Test func testExpression() throws {
        let expression = #Expression<Object, Int> {
            $0.a
        }
        let decoded = try _encodeDecode(expression, for: StandardConfig.self)
        var object = Object.example
        #expect(try expression.evaluate(object) == decoded.evaluate(object))
        object.a = 2
        #expect(try expression.evaluate(object) == decoded.evaluate(object))
        object.a = 3
        #expect(try expression.evaluate(object) == decoded.evaluate(object))
        
        #expect(throws: (any Error).self) {
            try _encodeDecode(expression, for: EmptyConfig.self)
        }
        #expect(throws: (any Error).self) {
            try _encodeDecode(expression)
        }
    }
}

#endif // FOUNDATION_FRAMEWORK
