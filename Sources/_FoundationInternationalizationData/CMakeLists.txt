##===----------------------------------------------------------------------===##
##
## This source file is part of the Swift open source project
##
## Copyright (c) 2026 Apple Inc. and the Swift project authors
## Licensed under Apache License v2.0
##
## See LICENSE.txt for license information
## See CONTRIBUTORS.md for the list of Swift project authors
##
## SPDX-License-Identifier: Apache-2.0
##
##===----------------------------------------------------------------------===##

add_library(_FoundationInternationalizationData STATIC
    ListFormatData.swift)

target_compile_options(_FoundationInternationalizationData PRIVATE
    "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend AccessLevelOnImport>"
    "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend Lifetimes>"
    "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend ImportMacroAliases>"
    "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-experimental-feature -Xfrontend StrictConcurrency>"
    "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-upcoming-feature -Xfrontend InferSendableFromCaptures>"
    "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -enable-upcoming-feature -Xfrontend MemberImportVisibility>")
target_compile_options(_FoundationInternationalizationData PRIVATE ${_SwiftFoundation_availability_macros})
target_compile_options(_FoundationInternationalizationData PRIVATE -package-name "SwiftFoundation")
target_compile_options(_FoundationInternationalizationData PRIVATE
    "SHELL:$<$<COMPILE_LANGUAGE:Swift>:-Xfrontend -allowable-client -Xfrontend FoundationInternationalization>")

set_property(GLOBAL APPEND PROPERTY SWIFT_FOUNDATION_EXPORTS _FoundationInternationalizationData)

# Only install the binary if we're building a static SDK, otherwise just install the swift module
if (NOT BUILD_SHARED_LIBS)
    _swift_foundation_install_target_options(_FoundationInternationalizationData YES)
else()
    _swift_foundation_install_target_options(_FoundationInternationalizationData NO)
endif()

