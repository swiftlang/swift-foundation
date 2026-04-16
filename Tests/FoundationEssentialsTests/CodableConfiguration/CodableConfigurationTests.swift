import Testing

#if canImport(FoundationEssentials)
@testable import FoundationEssentials
#else
@testable import Foundation
#endif

@Suite("CodableConfiguration")
struct CodableConfigurationTests {

    @Test
    func decodingIndirectly_succeedsForNull() async throws {
        let json = "{\"testObject\":null}"
        let jsonData = try #require(json.data(using: .utf8))

        let decoder = JSONDecoder()
        let sut = try decoder.decode(UsingCodableConfiguration.self, from: jsonData)
        #expect(sut.testObject == nil)
    }

    @Test
    func decodingIndirectly_succeedsForCorrectDate() async throws {
        let json = "{\"testObject\":\"Hello There\"}"
        let jsonData = try #require(json.data(using: .utf8))

        let decoder = JSONDecoder()
        let sut = try decoder.decode(UsingCodableConfiguration.self, from: jsonData)
        #expect(sut.testObject?.value == "Hello There")
    }

    @Test
    func decodingIndirectly_succeedsForMissingKey() async throws {
        let json = "{}"
        let jsonData = try #require(json.data(using: .utf8))

        let decoder = JSONDecoder()
        let sut = try decoder.decode(UsingCodableConfiguration.self, from: jsonData)
        #expect(sut.testObject == nil)
    }
}

private extension CodableConfigurationTests {
    struct NonCodableType {
        let value: String
    }

    /// Type that uses CodableConfiguration for decoding Optional NonCodableType
    struct UsingCodableConfiguration: Codable {
        @CodableConfiguration(wrappedValue: nil, from: CustomConfig.self)
        var testObject: NonCodableType?
    }

    /// Helper object allowing to decode Date using ISO8601 scheme
    struct CustomConfig: DecodingConfigurationProviding, EncodingConfigurationProviding, Sendable {
        static let encodingConfiguration = CustomConfig()
        static let decodingConfiguration = CustomConfig()

        func decode(from decoder: any Decoder) throws -> NonCodableType {
            let container = try decoder.singleValueContainer()
            let value = try container.decode(String.self)
            return NonCodableType(value: value)
        }

        func encode(object: NonCodableType, to encoder: Encoder) throws {
            var container = encoder.singleValueContainer()
            try container.encode(object.value)
        }
    }
}

extension CodableConfigurationTests.NonCodableType: CodableWithConfiguration {
    typealias CustomConfig = CodableConfigurationTests.CustomConfig

    public init(from decoder: any Decoder, configuration: CustomConfig) throws {
        self = try configuration.decode(from: decoder)
    }

    public func encode(to encoder: any Encoder, configuration: CustomConfig) throws {
        try configuration.encode(object: self, to: encoder)
    }
}
