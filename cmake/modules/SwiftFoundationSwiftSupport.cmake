function(_swift_foundation_install_target module)
  install(TARGETS ${module}
    ARCHIVE DESTINATION ${SwiftFoundation_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${SwiftFoundation_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

  get_target_property(module_name ${module} Swift_MODULE_NAME)
  if(NOT module_name)
    set(module_name ${module})
  endif()

  install(FILES $<TARGET_PROPERTY:${module},Swift_MODULE_DIRECTORY>/${module_name}.swiftdoc
    DESTINATION ${SwiftFoundation_INSTALL_SWIFTMODULEDIR}/${module_name}.swiftmodule
    RENAME ${SwiftFoundation_MODULE_TRIPLE}.swiftdoc)
  install(FILES $<TARGET_PROPERTY:${module},Swift_MODULE_DIRECTORY>/${module_name}.swiftmodule
    DESTINATION ${SwiftFoundation_INSTALL_SWIFTMODULEDIR}/${module_name}.swiftmodule
    RENAME ${SwiftFoundation_MODULE_TRIPLE}.swiftmodule)
  install(FILES $<TARGET_PROPERTY:${module},Swift_MODULE_DIRECTORY>/${module_name}.swiftsourceinfo
    DESTINATION ${SwiftFoundation_INSTALL_SWIFTMODULEDIR}/${module_name}.swiftmodule
    RENAME ${SwiftFoundation_MODULE_TRIPLE}.swiftsourceinfo)
endfunction()
