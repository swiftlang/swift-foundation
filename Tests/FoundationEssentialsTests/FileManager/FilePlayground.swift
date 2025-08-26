//===----------------------------------------------------------------------===//
//
// This source file is part of the Swift.org open source project
//
// Copyright (c) 2024 Apple Inc. and the Swift project authors
// Licensed under Apache License v2.0 with Runtime Library Exception
//
// See https://swift.org/LICENSE.txt for license information
// See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
//
//===----------------------------------------------------------------------===//

import Testing

#if canImport(FoundationEssentials)
@testable import FoundationEssentials
#else
@testable import Foundation
#endif

private protocol Buildable {
    func build(in path: String, using fileManager: FileManager) throws
}
    
struct File : ExpressibleByStringLiteral, Buildable {
    private let name: String
    private let attributes: [FileAttributeKey : Any]?
    private let contents: Data?
    
    init(_ name: String, attributes: [FileAttributeKey : Any]? = nil, contents: Data? = nil) {
        self.name = name
        self.attributes = attributes
        self.contents = contents
    }
    
    init(stringLiteral value: String) {
        self.init(value)
    }
    
    fileprivate func build(in path: String, using fileManager: FileManager) throws {
        guard fileManager.createFile(atPath: path.appendingPathComponent(name), contents: contents, attributes: attributes) else {
            throw CocoaError(.fileWriteUnknown)
        }
    }
}

struct SymbolicLink : Buildable {
    fileprivate let name: String
    private let destination: String
    
    init(_ name: String, destination: String) {
        self.name = name
        self.destination = destination
    }
    
    fileprivate func build(in path: String, using fileManager: FileManager) throws {
        let linkPath = path.appendingPathComponent(name)
        let destPath = path.appendingPathComponent(destination)
        try fileManager.createSymbolicLink(atPath: linkPath, withDestinationPath: destPath)
    }
}

struct Directory : Buildable {
    fileprivate let name: String
    private let attributes: [FileAttributeKey : Any]?
    private let contents: [FilePlayground.Item]
    
    init(_ name: String, attributes: [FileAttributeKey : Any]? = nil, @FilePlayground.DirectoryBuilder _ contentsClosure: () -> [FilePlayground.Item]) {
        self.name = name
        self.attributes = attributes
        self.contents = contentsClosure()
    }
    
    fileprivate func build(in path: String, using fileManager: FileManager) throws {
        let dirPath = path.appendingPathComponent(name)
        try fileManager.createDirectory(atPath: dirPath, withIntermediateDirectories: true, attributes: attributes)
        for item in contents {
            try item.build(in: dirPath, using: fileManager)
        }
    }
}

@globalActor
actor CurrentWorkingDirectoryActor: GlobalActor {
    static let shared = CurrentWorkingDirectoryActor()
    
    private init() {}
    
    @CurrentWorkingDirectoryActor
    static func withCurrentWorkingDirectory(
        _ path: String,
        fileManager: FileManager = .default,
        sourceLocation: SourceLocation = #_sourceLocation,
        body: @CurrentWorkingDirectoryActor () throws -> Void // Must be synchronous to prevent suspension points within body which could introduce a change in the CWD
    ) throws {
        let previousCWD = fileManager.currentDirectoryPath
        try #require(fileManager.changeCurrentDirectoryPath(path), "Failed to change CWD to '\(path)'", sourceLocation: sourceLocation)
        defer {
            #expect(fileManager.changeCurrentDirectoryPath(previousCWD), "Failed to change CWD back to the original directory '\(previousCWD)'", sourceLocation: sourceLocation)
        }
        try body()
    }
}

struct FilePlayground {
    enum Item : Buildable {
        case file(File)
        case directory(Directory)
        case symbolicLink(SymbolicLink)
        
        fileprivate func build(in path: String, using fileManager: FileManager) throws {
            switch self {
            case let .file(file): try file.build(in: path, using: fileManager)
            case let .directory(dir): try dir.build(in: path, using: fileManager)
            case let .symbolicLink(symlink): try symlink.build(in: path, using: fileManager)
            }
        }
    }
    
    @resultBuilder
    enum DirectoryBuilder {
        static func buildBlock(_ components: Item...) -> [Item] {
            components
        }
        
        static func buildExpression(_ expression: File) -> Item {
            .file(expression)
        }
        
        static func buildExpression(_ expression: Directory) -> Item {
            .directory(expression)
        }
        
        static func buildExpression(_ expression: SymbolicLink) -> Item {
            .symbolicLink(expression)
        }
    }
    
    private let directory: Directory
    
    init(@DirectoryBuilder _ contentsClosure: () -> [Item]) {
        self.directory = Directory("FilePlayground_\(UUID().uuidString)", contentsClosure)
    }
    
    func test(captureDelegateCalls: Bool = false, sourceLocation: SourceLocation = #_sourceLocation, _ tester: sending (FileManager) throws -> Void) async throws {
        let capturingDelegate = CapturingFileManagerDelegate()
        let tempDir = String.temporaryDirectoryPath
        try directory.build(in: tempDir, using: FileManager.default)
        let createdDir = tempDir.appendingPathComponent(directory.name)
        try await CurrentWorkingDirectoryActor.withCurrentWorkingDirectory(createdDir, sourceLocation: sourceLocation) {
            let fileManager = FileManager()
            if captureDelegateCalls {
                // Add the delegate after the call to `build` to ensure that the builder doesn't mutate the delegate
                fileManager.delegate = capturingDelegate
            }
            try tester(fileManager)
        }
        try FileManager.default.removeItem(atPath: createdDir)
        extendLifetime(capturingDelegate) // Ensure capturingDelegate lives beyond the tester body
    }
}
