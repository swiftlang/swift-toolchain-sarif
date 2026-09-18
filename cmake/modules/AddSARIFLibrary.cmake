##===----------------------------------------------------------------------===##
##
## This source file is part of the Swift.org open source project
##
## Copyright (c) 2025 Apple Inc. and the Swift project authors
## Licensed under Apache License v2.0 with Runtime Library Exception
##
## See https://swift.org/LICENSE.txt for license information
## See https://swift.org/CONTRIBUTORS.txt for the list of Swift project authors
##
##===----------------------------------------------------------------------===##

function(target_link_sarif_libraries TARGET)
  cmake_parse_arguments(ARGS "PUBLIC;PRIVATE;INTERFACE" "" "" ${ARGN})
  set(link_type)
  if(ARGS_PUBLIC)
    set(link_type PUBLIC)
  elseif(ARGS_PRIVATE)
    set(link_type PRIVATE)
  elseif(ARGS_INTERFACE)
    set(link_type INTERFACE)
  endif()

  string(PREPEND TARGET ${SARIF_TARGET_NAMESPACE})
  list(TRANSFORM ARGS_UNPARSED_ARGUMENTS PREPEND "${SARIF_TARGET_NAMESPACE}" OUTPUT_VARIABLE dependencies)

  target_link_libraries(${TARGET} ${link_type} ${dependencies})
endfunction()

# Add a new host library with the given name.
function(add_sarif_library name)
  set(ASL_SOURCES ${ARGN})

  set(target ${SARIF_TARGET_NAMESPACE}${name})

  # Create the library target.
  add_library(${target} ${ASL_SOURCES})
  if(CMAKE_BUILD_TYPE STREQUAL "Debug")
    target_link_libraries(${target} PUBLIC swiftSwiftOnoneSupport)
  endif()

  # Unlike swift-syntax this package does not emit resilient modules or
  # .swiftinterface files, since the compiler links the non-resilient copy.
  set(module_dir ${CMAKE_CURRENT_BINARY_DIR})

  set_target_properties(${target} PROPERTIES
    Swift_MODULE_NAME ${name}
    Swift_MODULE_DIRECTORY ${module_dir}
    Swift_LANGUAGE_VERSION ${SARIF_SWIFT_LANGUAGE_VERSION}
    INTERFACE_INCLUDE_DIRECTORIES ${module_dir}
  )

  # Give the modules a distinct ABI name when requested, so that a toolchain
  # copy of this library can coexist in one process with a copy that a client
  # built as a SwiftPM dependency.
  target_compile_options("${target}" PRIVATE
    $<$<COMPILE_LANGUAGE:Swift>:
      "SHELL:-Xfrontend -module-abi-name -Xfrontend ${SWIFT_MODULE_ABI_NAME_PREFIX}${name}"
  >)

  if(SWIFT_HOST_LIBRARIES_RPATH)
    # Don't add builder's stdlib RPATH automatically.
    target_compile_options(${target} PRIVATE -no-toolchain-stdlib-rpath)
    set_property(TARGET ${target}
      PROPERTY INSTALL_RPATH "${SWIFT_HOST_LIBRARIES_RPATH}"
    )
  endif()

  if(PROJECT_IS_TOP_LEVEL OR SARIF_INSTALL_TARGETS)
    # Install this target
    install(TARGETS ${target}
      EXPORT SARIFTargets
      ARCHIVE DESTINATION lib/${SWIFT_HOST_LIBRARIES_SUBDIRECTORY}
      LIBRARY DESTINATION lib/${SWIFT_HOST_LIBRARIES_SUBDIRECTORY}
      RUNTIME DESTINATION bin
    )

    # Install the module files.
    install(FILES ${module_dir}/${name}.swiftmodule
      DESTINATION lib/${SWIFT_HOST_LIBRARIES_SUBDIRECTORY}/${name}.swiftmodule
      RENAME ${SWIFT_HOST_MODULE_TRIPLE}.swiftmodule
    )
    install(FILES ${module_dir}/${name}.swiftdoc
      DESTINATION lib/${SWIFT_HOST_LIBRARIES_SUBDIRECTORY}/${name}.swiftmodule
      RENAME ${SWIFT_HOST_MODULE_TRIPLE}.swiftdoc
      OPTIONAL
    )
  else()
    set_property(GLOBAL APPEND PROPERTY SWIFT_EXPORTS ${target})
  endif()
  add_library(SARIF::${target} ALIAS ${target})
endfunction()
