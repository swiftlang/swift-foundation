//
//  MeasurementTests.swift
//  swift-foundation
//
//  Created by Alejandro Beltrán on 4/13/25.
//

import XCTest
@testable import FoundationEssentials

/// Test suite for verifying the `Hashable` conformance of the `Measurement` type
/// These tests ensure that `Measurement` properly implements equality and hashing functions
/// to allow usage in collections like Sets and Dictionaries.
final class MeasurementTests: XCTestCase {
    
    /// A mock implementation of the `Unit` class for testing purposes
    /// This allows us to test `Measurement<Unit>` without relying on specific unit implementations
    class UnitMock: Unit, @unchecked Sendable {
        /// Initializes a new mock unit with the specified symbol
        /// - Parameter symbol: The string symbol representing this unit (e.g., "m", "kg")
        override init(symbol: String) {
            super.init(symbol: symbol)
        }
        
        /// Required initializer for NSCoder compatibility
        required init?(coder: NSCoder) {
            super.init(coder: coder)
        }
    }
    
    // MARK: - Basic Hashable behavior
    
    /// Tests that `Measurement` objects can be used correctly in a `Set`
    /// This verifies that equal measurements are treated as duplicates in a Set
    func testMeasurementHashableInSet() {
        let m1 = Measurement(value: 5.0, unit: UnitMock(symbol: "m"))
        let m2 = Measurement(value: 5.0, unit: UnitMock(symbol: "m"))  // Same as m1
        let m3 = Measurement(value: 1.0, unit: UnitMock(symbol: "km")) // Different unit
        
        let set: Set = [m1, m2, m3]
        
        // Set should contain only 2 elements since m1 and m2 are equal
        XCTAssertEqual(set.count, 2)
        XCTAssertTrue(set.contains(m2))
    }
    
    // MARK: - Explicit equality tests
    
    /// Verifies that `Measurement` equality works correctly
    /// Two measurements are equal if they have the same value and unit type
    func testMeasurementEquality() {
        let m1 = Measurement(value: 100.0, unit: UnitMock(symbol: "m"))
        let m2 = Measurement(value: 100.0, unit: UnitMock(symbol: "m"))  // Same as m1
        let m3 = Measurement(value: 100.0, unit: UnitMock(symbol: "km")) // Different unit
        
        XCTAssertEqual(m1, m2)
        XCTAssertNotEqual(m1, m3)
    }
    
    // MARK: - Hash value matching
    
    /// Confirms that two equal `Measurement` objects produce the same hash value
    /// This is a requirement for proper `Hashable` conformance
    func testMeasurementHashValue() {
        let m1 = Measurement(value: 42.0, unit: UnitMock(symbol: "m"))
        let m2 = Measurement(value: 42.0, unit: UnitMock(symbol: "m"))  // Same as m1
        let m3 = Measurement(value: 42.0, unit: UnitMock(symbol: "km")) // Different unit
        
        XCTAssertEqual(m1.hashValue, m2.hashValue)
        XCTAssertNotEqual(m1.hashValue, m3.hashValue) // Fixed duplicate assertion
    }
    
    // MARK: - Edge cases
    
    /// Tests edge cases for `Measurement` equality and hashing
    /// Including zero, negative values, and special floating-point values like NaN
    func testEdgeCases() {
        let unit = UnitMock(symbol: "°C")
        
        let zero = Measurement(value: 0.0, unit: unit)
        let negative = Measurement(value: -42.0, unit: unit)
        let nan = Measurement(value: .nan, unit: unit)
        
        XCTAssertNotEqual(zero, negative)
        // NaN != NaN (following IEEE 754 floating-point standard)
        XCTAssertFalse(nan == nan)
        
        // Additional test for infinity
        let infinity = Measurement(value: .infinity, unit: unit)
        XCTAssertNotEqual(infinity, zero)
    }
    
    // MARK: - Dictionary usage
    
    /// Validates that `Measurement` can be used as a dictionary key
    /// This tests the full `Hashable` conformance in a practical use case
    func testUsageDictionaryKey() {
        let distance = UnitMock(symbol: "m")
        let time = UnitMock(symbol: "sec")
        
        let measurement1 = Measurement(value: 5, unit: distance)
        let measurement2 = Measurement(value: 10, unit: time)
        
        let dictionary: [Measurement<UnitMock>: String] = [
            measurement1: "Distance",
            measurement2: "Time"
        ]
        
        XCTAssertEqual(dictionary[measurement1], "Distance")
        XCTAssertEqual(dictionary[measurement2], "Time")
    }
    
    /// Tests that hash collisions are properly handled
    /// Even measurements with potentially similar hash inputs should be treated as different
    func testHashCollisions() {
        // Create measurements with different values/units but potentially similar hash inputs
        let m1 = Measurement(value: 1000, unit: UnitMock(symbol: "m"))
        let m2 = Measurement(value: 1, unit: UnitMock(symbol: "km"))
        
        // They should have different hash values as they use different units
        XCTAssertNotEqual(m1.hashValue, m2.hashValue)
        
        // Dictionary should handle both values correctly
        var dict = [Measurement<UnitMock>: String]()
        dict[m1] = "meters"
        dict[m2] = "kilometers"
        
        XCTAssertEqual(dict.count, 2)
        XCTAssertEqual(dict[m1], "meters")
        XCTAssertEqual(dict[m2], "kilometers")
    }
}
