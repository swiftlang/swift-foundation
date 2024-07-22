##===----------------------------------------------------------------------===##
##
## This source file is part of the Swift open source project
##
## Copyright (c) 2024 Apple Inc. and the Swift project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.md for the list of Swift project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

# SwiftSyntax Dependency
include(FetchContent)
find_package(SwiftSyntax)
if(NOT SwiftSyntax_FOUND)
    # If building at desk, check out and link against the SwiftSyntax repo's targets
    FetchContent_Declare(SwiftSyntax
        GIT_REPOSITORY https://github.com/swiftlang/swift-syntax.git
        GIT_TAG 4c6cc0a3b9e8f14b3ae2307c5ccae4de6167ac2c) # 600.0.0-prerelease-2024-06-12
    FetchContent_MakeAvailable(SwiftSyntax)
endif()

add_library(FoundationMacros SHARED
    FoundationMacros.swift
    PredicateMacro.swift)
    
target_compile_definitions(FoundationMacros PRIVATE FOUNDATION_MACROS_LIBRARY)

set_target_properties(FoundationMacros
    PROPERTIES
        ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib
        LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib
        INTERFACE_INCLUDE_DIRECTORIES ${CMAKE_BINARY_DIR}/lib
)

target_link_libraries(FoundationMacros PUBLIC
    SwiftSyntax::SwiftSyntax
    SwiftSyntax::SwiftSyntaxMacros
    SwiftSyntax::SwiftDiagnostics
    SwiftSyntax::SwiftSyntaxBuilder
)

set_target_properties(FoundationMacros PROPERTIES
    INSTALL_RPATH "$ORIGIN"
    INSTALL_REMOVE_ENVIRONMENT_RPATH ON)

target_compile_options(FoundationMacros PRIVATE -parse-as-library)
target_compile_options(FoundationMacros PRIVATE
    "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend AccessLevelOnImport>"
    "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend StrictConcurrency>"
    "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-upcoming-feature -Xfrontend InferSendableFromCaptures>")

install(TARGETS FoundationMacros
    ARCHIVE DESTINATION lib/swift/host/plugins
    LIBRARY DESTINATION lib/swift/host/plugins
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(FILES $<TARGET_LINKER_FILE:FoundationMacros>
  DESTINATION lib)
