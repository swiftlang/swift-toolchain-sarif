# This source file is part of the Swift.org open source project
#
# Copyright (c) 2025 Apple Inc. and the Swift project authors
# Licensed under Apache License v2.0 with Runtime Library Exception
#
# See http://swift.org/LICENSE.txt for license information
# See http://swift.org/CONTRIBUTORS.txt for Swift project authors

add_sarif_library(SARIF
  Artifact.swift
  ArtifactLocation.swift
  DefinitionLoadMap.swift
  DefinitionSaveMap.swift
  Fingerprinted.swift
  Forest.swift
  Invocation.swift
  JSONRepresentable.swift
  Location.swift
  LogicalLocation.swift
  Macros.swift
  Message.swift
  MultiFormatMessageString.swift
  PhysicalLocation.swift
  PropertyBag.swift
  PropertyProvider.swift
  Region.swift
  ReportingConfiguration.swift
  ReportingDescriptor.swift
  ReportingDescriptorLoadMap.swift
  Result.swift
  Run.swift
  SARIFLog.swift
  Spaceship.swift
  SynthesizedDefinitionLoadMap.swift
  Tool.swift
  ToolComponent.swift
  URLMapping.swift
  ValidationSink.swift
  WithDefaultValue.swift
)

# Linked PUBLIC even though 'ImmutableJSON' is only reached through a
# file-private import: a binary .swiftmodule records every module it imports.
target_link_libraries(SARIF PUBLIC
  ImmutableJSON
  SARIFRecords)

target_link_libraries(${SARIF_TARGET_NAMESPACE}SARIF PUBLIC
  BitCollections
  OrderedCollections)
