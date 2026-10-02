fileprivate import BitCollections
import Foundation
public import OrderedCollections
public import SARIFRecords

internal final class RunContext {
  internal fileprivate(set) var defaultEncoding: String? = nil
  internal fileprivate(set) var defaultSourceLanguage: HierarchicalString? = nil

  fileprivate init() {
  }

  fileprivate init(from record: RunRecord, sink: any ValidationSink) throws {
    self.defaultEncoding = record.defaultEncoding
  }
}

internal final class RunSaveContext {
  private let artifactIndices: [Artifact: ArrayIndex]

  fileprivate init(from run: Run) {
    var indices: [Artifact: ArrayIndex] = [:]

    run.artifacts.enumerated().forEach { index, artifact in
      indices[artifact] = index
    }

    self.artifactIndices = indices
  }

  internal func artifactIndex(of artifact: Artifact) -> ArrayIndex {
    self.artifactIndices[artifact]!
  }
}

public final class Run: JSONRepresentable<RunRecord> {
  public var columnKind: ColumnKind?
  public private(set) var artifacts: [Artifact]
  public var tool: Tool
  public private(set) var results: [Result]
  public var logicalLocations: OrderedSet<LogicalLocation>
  public var defaultEncoding: String?
  public var defaultSourceLanguage: HierarchicalString?
  public var invocations: [Invocation]

  internal init(
    from record: RunRecord, propertyProviders: PropertyProviders,
    sink: any ValidationSink
  ) throws {
    self.columnKind = record.columnKind

    let artifactMap = ArtifactLoadMap(sink: sink)
    let artifactDefaults = try RunContext(from: record, sink: sink)
    self.artifacts = try (record.artifacts ?? []).enumerated().map {
      index, artifactRecord in
      let artifact = try Artifact(
        from: artifactRecord, sink: sink, index: ArrayIndex(index),
        defaults: artifactDefaults)
      artifactMap.add(artifact, key: ArrayIndex(index))
      return artifact
    }
    let artifactResolver = ArtifactReferenceResolver(artifacts: artifactMap)

    self.invocations = try (record.invocations ?? []).map { invocationRecord in
      try Invocation(
        from: invocationRecord, propertyProviders: propertyProviders, sink: sink
      )
    }

    let ruleMap = try RuleLoadMap(
      driverGuid: record.tool.driver.guid, sink: sink)
    self.tool = try .init(from: record.tool, sink: sink, with: ruleMap)
    let ruleResolver = RuleResolver(ruleMap: ruleMap, driver: self.tool.driver)

    let (logicalLocations, logicalLocationMap) = try Self.loadLogicalLocations(
      records: record.logicalLocations, propertyProviders: propertyProviders,
      sink: sink)
    self.logicalLocations = logicalLocations

    self.results = try (record.results ?? [])
      .filter {
        // REVIEW: We really should just fix Clang to not emit as separate results.
        $0.level != .note
      }
      .map { resultRecord in
        try Result(
          from: resultRecord, sink: sink, rules: ruleResolver,
          artifacts: artifactResolver,
          logicalLocations: logicalLocationMap)
      }
  }

  public init(tool: Tool) {
    self.tool = tool
    self.artifacts = []
    self.results = []
    self.logicalLocations = []
    self.invocations = []
  }

  @discardableResult
  public func addResult(rule: Rule, message: Message) -> Result {
    let result = Result(rule: rule, message: message)
    self.results.append(result)

    return result
  }

  @discardableResult
  public func addResult(
    rule: Rule, messageText: String, arguments: [String] = []
  ) -> Result {
    addResult(
      rule: rule, message: Message(text: messageText, arguments: arguments))
  }

  @discardableResult
  public func addArtifact() -> Artifact {
    let artifact = Artifact()
    self.artifacts.append(artifact)

    return artifact
  }

  @discardableResult
  public func addLogicalLocation() -> LogicalLocation {
    let location = LogicalLocation()
    self.logicalLocations.append(location)

    return location
  }

  public func canonicalize(
    sortingInvocationsBy: (_ lhs: Invocation, _ rhs: Invocation) -> Bool = {
      _, _ in false
    }
  ) {
    // Sort artifacts by location:
    self.artifacts.sort { lhs, rhs in
      (lhs.location?.defaultSortKey <=> rhs.location?.defaultSortKey) ?? false
    }

    // Sort results by location, then by rule ID
    self.results.sort { lhs, rhs in
      (lhs.locations.first?.defaultSortKey
        <=> rhs.locations.first?.defaultSortKey)
        ?? (lhs.rule.id <=> rhs.rule.id)
        ?? (lhs.ruleIdSuffix <=> rhs.ruleIdSuffix) ?? false
    }

    self.invocations.sort(by: sortingInvocationsBy)
  }

  internal func toJSON() throws -> RunRecord {
    let ruleMap = DefinitionSaveMap<Rule, RuleKey>()
    let artifactMap = DefinitionSaveMap<Artifact, ArrayIndex>()
    let (logicalLocations, logicalLocationMap) = try Self.saveLogicalLocations(
      locations: self.logicalLocations)

    return RunRecord(
      tool: try self.tool.toJSON(with: ToolSaveContext(ruleMap: ruleMap)),
      columnKind: self.columnKind,
      artifacts: try self.artifacts.ifNotEmpty?.enumerated().map {
        index, artifact in
        artifactMap.add(artifact, key: ArrayIndex(index))
        return try artifact.toJSON(with: artifactMap)
      },
      invocations: try self.invocations.ifNotEmpty.toJSON(),
      results: try self.results.ifNotEmpty.toJSON(
        with: ResultSaveContext(
          rules: ruleMap, artifacts: artifactMap,
          logicalLocations: logicalLocationMap)),
      externalPropertyFileReferences: nil,  // FIXME
      automationDetails: nil,  // FIXME
      runAggregates: nil,  // FIXME
      baselineGuid: nil,  // FIXME
      language: nil,  // FIXME
      taxonomies: nil,  // FIXME
      translations: nil,  // FIXME
      policies: nil,  // FIXME
      conversion: nil,  // FIXME
      versionControlProvenance: nil,  // FIXME
      originalUriBaseIds: nil,  // FIXME
      specialLocations: nil,  // FIXME
      logicalLocations: logicalLocations.isEmpty ? nil : logicalLocations,
      addresses: nil,  // FIXME
      threadFlowLocations: nil,  // FIXME
      graphs: nil,  // FIXME
      webRequests: nil,  // FIXME
      webResponses: nil,  // FIXME
      defaultEncoding: try self.defaultEncoding.toJSON(),
      defaultSourceLanguage: try self.defaultSourceLanguage.toJSON(),  // FIXME
      newlineSequences: nil,  // FIXME
      redactionTokens: nil  // FIXME
    )
  }

  private static func saveLogicalLocations(
    locations: OrderedSet<LogicalLocation>
  ) throws
    -> (locations: [LogicalLocationRecord], map: LogicalLocationSaveMap)
  {
    let map = LogicalLocationSaveMap()
    var records: [LogicalLocationRecord?] = .init(
      repeating: nil, count: locations.count)

    for (index, location) in locations.enumerated() {
      map.add(location, key: index)
    }

    let forest = LogicalLocationForest(elements: locations)
    try forest.visitTopDown { index, parentIndex in
      let location = locations[index]
      records[index] = try location.toJSON(with: map)
      map.add(location, key: index)

      return index
    }

    return (locations: records.compactMap { $0 }, map: map)
  }

  private static func loadLogicalLocations(
    records: [LogicalLocationRecord]?,
    propertyProviders: PropertyProviders,
    sink: any ValidationSink
  ) throws -> (
    locations: OrderedSet<LogicalLocation>, map: LogicalLocationLoadMap
  ) {

    let map = LogicalLocationLoadMap(
      propertyProviders: propertyProviders, sink: sink)

    guard let records,
      !records.isEmpty
    else {
      return (locations: [], map: map)
    }

    var locations: [LogicalLocation?] = .init(
      repeating: nil, count: records.count)

    let forest = LogicalLocationRecordForest(elements: records, sink: sink)
    try forest.visitTopDown { index, parentLocation in
      let location = try LogicalLocation(
        from: records[index], parentLocation: parentLocation,
        propertyProviders: propertyProviders, sink: sink)
      locations[index] = location
      map.add(location, key: index)

      return location
    }

    return (locations: .init(locations.compactMap { $0 }), map: map)
  }
}

private struct LogicalLocationRecordForest: Forest {
  let elements: [LogicalLocationRecord]
  let sink: any ValidationSink

  func reportCycle(_ chain: [Int]) throws -> Never {
    let chainString = chain.map { String($0) }.joined(separator: "->")
    try sink.fatalError(
      "Circular dependency in 'logicalLocation' parent chain: \(chainString)")
  }

  func getParentIndex(ofIndex index: Int) throws -> Int? {
    let parentIndex = self.elements[index].parentIndex
    if let parentIndex {
      guard self.elements.indices.contains(parentIndex) else {
        try sink.fatalError("Parent index '\(parentIndex)' out of bounds.")
      }
    }

    return parentIndex
  }
}

package struct LogicalLocationForest: Forest {
  package let elements: OrderedSet<LogicalLocation>

  package init(elements: OrderedSet<LogicalLocation>) {
    self.elements = elements
  }

  package func reportCycle(_ chain: [Int]) throws -> Never {
    let chainDescription = chain.map(String.init).joined(separator: "->")

    throw SARIFError.invalidSARIF(
      message: "Cycle in logicalLocation parent chain: \(chainDescription)")
  }

  package func getParentIndex(ofIndex index: Int) throws -> Int? {
    guard let parent = self.elements[index].parent else {
      return nil
    }
    guard let parentIndex = self.elements.firstIndex(of: parent) else {
      throw SARIFError.invalidSARIF(
        message:
          "Parent of logicalLocation at index '\(index)' is not in the 'logicalLocations' array."
      )
    }

    return parentIndex
  }
}
