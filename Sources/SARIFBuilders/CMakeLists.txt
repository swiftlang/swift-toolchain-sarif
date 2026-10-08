# This source file is part of the Swift.org open source project
#
# Copyright (c) 2025 Apple Inc. and the Swift project authors
# Licensed under Apache License v2.0 with Runtime Library Exception
#
# See http://swift.org/LICENSE.txt for license information
# See http://swift.org/CONTRIBUTORS.txt for Swift project authors

add_sarif_library(SARIFBuilders
  RunBuilder.swift
  )

# Linked PUBLIC even though 'ImmutableJSON' is only reached through a
# file-private import: a binary .swiftmodule records every module it imports.
target_link_libraries(SARIF PUBLIC
  ImmutableJSON
  SARIFRecords
  SARIF)

target_link_libraries(${SARIF_TARGET_NAMESPACE}SARIF PUBLIC
  OrderedCollections)
