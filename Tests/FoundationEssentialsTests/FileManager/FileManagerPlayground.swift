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

#if canImport(TestSupport)
import TestSupport
#endif

#if FOUNDATION_FRAMEWORK
import Foundation
#else
import FoundationEssentials
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
    private let contents: [FileManagerPlayground.Item]
    
    init(_ name: String, attributes: [FileAttributeKey : Any]? = nil, @FileManagerPlayground.DirectoryBuilder _ contentsClosure: () -> [FileManagerPlayground.Item]) {
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

struct FileManagerPlayground {
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
        self.directory = Directory("FileManagerPlayground_\(UUID().uuidString)", contentsClosure)
    }
    
    func test(captureDelegateCalls: Bool = false, file: StaticString = #filePath, line: UInt = #line, _ tester: (FileManager) throws -> Void) throws {
        let capturingDelegate = CapturingFileManagerDelegate()
        try withExtendedLifetime(capturingDelegate) {
            let fileManager = FileManager()
            let tempDir = String.temporaryDirectoryPath
            try directory.build(in: tempDir, using: fileManager)
            let previousCWD = fileManager.currentDirectoryPath
            if captureDelegateCalls {
                // Add the delegate after the call to `build` to ensure that the builder doesn't mutate the delegate
                fileManager.delegate = capturingDelegate
            }
            let createdDir = tempDir.appendingPathComponent(directory.name)
            XCTAssertTrue(fileManager.changeCurrentDirectoryPath(createdDir), "Failed to change CWD to the newly created playground directory", file: file, line: line)
            try tester(fileManager)
            XCTAssertTrue(fileManager.changeCurrentDirectoryPath(previousCWD), "Failed to change CWD back to the original directory", file: file, line: line)
            try fileManager.removeItem(atPath: createdDir)
        }
    }
}
