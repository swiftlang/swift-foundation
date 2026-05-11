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

set(print_target_info_invocation "${CMAKE_Swift_COMPILER}" -print-target-info)
if(CMAKE_Swift_COMPILER_TARGET)
  list(APPEND print_target_info_invocation -target ${CMAKE_Swift_COMPILER_TARGET})
endif()
execute_process(COMMAND ${print_target_info_invocation} OUTPUT_VARIABLE target_info_json)
message(CONFIGURE_LOG "Swift Target Info: ${print_target_info_invocation}\n"
"${target_info_json}")

if(NOT SwiftFoundation_MODULE_TRIPLE)
  string(JSON module_triple GET "${target_info_json}" "target" "moduleTriple")
  set(SwiftFoundation_MODULE_TRIPLE "${module_triple}" CACHE STRING "Triple used for installed swift{doc,module,interface} files")
  mark_as_advanced(SwiftFoundation_MODULE_TRIPLE)

  message(CONFIGURE_LOG "Swift Module Triple: ${module_triple}")
endif()

if(NOT SwiftFoundation_PLATFORM_SUBDIR)
  string(JSON platform GET "${target_info_json}" "target" "platform")
  if(NOT platform)
    if(NOT SWIFT_SYSTEM_NAME)
      if(CMAKE_SYSTEM_NAME STREQUAL Darwin)
        set(platform macosx)
      else()
        set(platform $<LOWER_CASE:${CMAKE_SYSTEM_NAME}>)
      endif()
    endif()
  endif()
  set(SwiftFoundation_PLATFORM_SUBDIR "${platform}" CACHE STRING "Platform name used for installed swift{doc,module,interface} files")
  mark_as_advanced(SwiftFoundation_PLATFORM_SUBDIR)

  message(CONFIGURE_LOG "Swift Platform: ${platform}")
endif()

if(NOT SwiftFoundation_ARCH_SUBDIR)
  string(JSON arch GET "${target_info_json}" "target" "arch")
  set(SwiftFoundation_ARCH_SUBDIR "${arch}" CACHE STRING "Architecture used for setting the architecture subdirectory")
  mark_as_advanced(SwiftFoundation_ARCH_SUBDIR)

  message(CONFIGURE_LOG "Swift Architecture: ${arch}")
endif()
