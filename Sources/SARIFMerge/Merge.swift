import Foundation
internal import OrderedCollections
public import SARIF
internal import SARIFRecords

extension ToolComponent: MergeableWithIdentity {
  struct Context {
    let rules: ReferenceMergeMap<Rule>
  }

  internal struct MergeKey: MergeKeyProtocol<ToolComponent> {
    private let name: String
    private let guid: UUID?
    private let version: String?
    private let semanticVersion: String?

    public init(for toolComponent: ToolComponent, with context: Context) {
      self.name = toolComponent.name
      self.guid = toolComponent.guid
      self.version = toolComponent.version
      self.semanticVersion = toolComponent.semanticVersion
    }

    public static func == (lhs: MergeKey, rhs: MergeKey) -> Bool {
      if lhs.guid != rhs.guid {
        // Either only one side has a GUID, or they have unequal GUIDs. Treat as unequal.
        return false
      }
      if lhs.guid == nil {
        // No GUIDs, so fall back to comparing names.
        if lhs.name != rhs.name {
          return false
        }
      }

      // Equal so far, based on either GUID or name. Compare versions, if available. If either
      // of the version properties mismatch, including the case where one side has that version
      // property and one does not, treat as unequal.
      return (lhs.version == rhs.version)
        && (lhs.semanticVersion == rhs.semanticVersion)
    }

    public func hash(into hasher: inout Hasher) {
      hasher.combine(self.guid)
      if self.guid == nil {
        // Only care about name if there's no GUID.
        hasher.combine(self.name)
      }
      hasher.combine(self.version)
      hasher.combine(self.semanticVersion)
    }
  }

  internal struct MergeState: MergeStateProtocolWithContext<ToolComponent> {
    private var rules = ArrayMerger<Rule, ToolComponent>()

    mutating func merge(
      merger: inout PropertyMerger<ToolComponent>, with context: Context
    ) throws {
      try merger.keepFirst(keys: \.name)
      try merger.assertEqual(keys: \.guid, \.version, \.semanticVersion)
      try merger.keepFirstSpecified(
        keys: \.fullName, \.shortDescription, \.fullDescription, \.downloadUri,
        \.informationUri,
        \.organization, \.product, \.productSuite, \.releaseDateUtc)
      try merger.expectEqual(
        keys: \.dottedQuadFileVersion, \.language,
        \.localizedDataSementicVersion, \.contents)
      // Ignore `isComprehensive` for now, since we don't really expesct it to be set by Clang anyway.
      try merger.ignore(keys: \.$isComprehensive)

      let output = merger.output
      try self.rules.merge(key: \.rules, merger: &merger, map: context.rules) {
        inputRule in
        output.addRule(id: inputRule.id)
      }
    }
  }
}

extension Rule: MergeableWithIdentity, MergeHashable {
  typealias Context = Void

  internal struct MergeKey: MergeKeyProtocol<Rule> {
    private let id: String
    private let guid: UUID?

    init(for rule: Rule, with context: Void) {
      // REVIEW: The SARIF spec allows multiple Rule descriptors with the same ID. How should we distinguish between these?
      // The rule records in the same ToolComponent _do_ have to be unique, though, so there must be some property that is
      // different between different rules with the same ID.
      self.id = rule.id
      self.guid = rule.guid
    }
  }

  internal struct MergeState: MergeStateProtocol<Rule> {
    func merge(merger: inout PropertyMerger<Rule>) throws {
      try merger.assertEqual(keys: \.id, \.guid)
      try merger.keepFirstSpecified(
        keys: \.name, \.shortDescription, \.fullDescription, \.helpUri, \.help)
      try merger.union(
        keys: \.deprecatedIds, \.deprecatedGuids, \.deprecatedNames)
      try merger.ignore(keys: \.defaultConfiguration, \.messageStrings)  // TODO
    }
  }
}

extension Tool: MergeableWithIdentity {
  struct Context {
    let rules: ReferenceMergeMap<Rule>
  }

  internal struct MergeKey: MergeKeyProtocol<Tool> {
    private let driver: ToolComponent.MergeKey

    init(for tool: Tool, with context: Context) throws {
      self.driver = try tool.driver.mergeKey(with: .init(rules: context.rules))
    }
  }

  internal struct MergeState: MergeStateProtocolWithContext<Tool> {
    private let driver = Merger<ToolComponent>()
    private var extensions = ArrayMerger<ToolComponent, Tool>()

    mutating func merge(
      merger: inout PropertyMerger<Tool>, with context: Context
    ) throws {
      let toolComponentContext = ToolComponent.Context(rules: context.rules)
      try self.driver.merge(
        key: \.driver, merger: &merger, with: toolComponentContext)
      try self.extensions.merge(
        key: \.extensions, merger: &merger, with: toolComponentContext,
        map: .init()
      ) { inputToolComponent in
        ToolComponent(named: inputToolComponent.name)
      }
    }
  }
}

extension Artifact: MergeableWithIdentity {
  typealias Context = Void

  internal struct MergeKey: MergeKeyProtocol<Artifact> {
    private let location: ArtifactLocation?
    // TODO: Parent

    init(for artifact: Artifact, with context: Void) {
      self.location = artifact.location
      // TODO: Parent
    }
  }

  internal struct MergeState: MergeStateProtocol<Artifact> {
    func merge(merger: inout PropertyMerger<Artifact>) throws {
      try merger.assertEqualOrNil(
        keys: \.location, \.length, \.mimeType, \.sourceLanguage, \.encoding)
      try merger.union(keys: \.roles)
      try merger.assertNil(keys: \.parent)
    }
  }
}

internal final class ReferenceMergeMap<Object: AnyObject> {
  private var outputsByInput: [ObjectIdentifier: Object] = [:]

  func addDefinition(from input: Object, into output: Object) {
    self.outputsByInput[ObjectIdentifier(input)] = output
  }

  func resolve(from input: Object) -> Object {
    self.outputsByInput[ObjectIdentifier(input)]!
  }

  func resolveOptional(from input: Object?) -> Object? {
    if let input {
      resolve(from: input)
    } else {
      nil
    }
  }
}

extension Result: MergeableWithIdentity {
  internal struct Context {
    fileprivate var rules: ReferenceMergeMap<Rule>
    fileprivate var artifacts: ReferenceMergeMap<Artifact>
    fileprivate var logicalLocations: ReferenceMergeMap<LogicalLocation>
    fileprivate var inputSharedLogicalLocations: OrderedSet<LogicalLocation>

    fileprivate var locationContext: Location.Context {
      .init(
        artifacts: self.artifacts, logicalLocations: self.logicalLocations,
        inputSharedLogicalLocations: self.inputSharedLogicalLocations)
    }
  }

  internal struct MergeKey: MergeKeyProtocol<Result> {
    private let rule: Rule
    private let locations: [Location.MergeKey]

    init(for result: Result, with context: Context) throws {
      self.rule = context.rules.resolve(from: result.rule)
      try self.locations = result.locations.map {
        try $0.mergeKey(with: context.locationContext)
      }
    }
  }

  internal struct MergeState: MergeStateProtocolWithContext<Result> {
    func merge(merger: inout PropertyMerger<Result>, with context: Context)
      throws
    {
      let output = merger.output
      try merger.assertIdentical(key: \.rule, definitions: context.rules)
      try merger.assertEqualOrNil(keys: \.guid)
      try merger.assertNil(keys: \.correlationGuid)
      try merger.assertEqual(keys: \.kind)
      try merger.mergeFirst(key: \.locations, with: context.locationContext) {
        let location = Location()
        output.locations.append(location)
        return location
      }
      try merger.keepFirst(keys: \.message)
    }
  }
}

extension Region: MergeableValue {
  typealias Context = Void

  internal struct MergeKey: MergeKeyProtocol<Region> {
    private let textRegion: TextRegion?
    private let textOffsetRegion: TextOffsetRegion?
    private let binaryRegion: BinaryRegion?

    init(for region: Region, with context: Void) {
      self.textRegion = region.textRegion
      self.textOffsetRegion = region.textOffsetRegion
      self.binaryRegion = region.binaryRegion
    }
  }

  internal struct MergeState: ValueMergeStateProtocolWithContext<Region> {
    func merge(merger: inout PropertyMerger<Region>, with context: Context)
      throws
    {
      try merger.keepFirst(
        keys: \.textRegion, \.textOffsetRegion, \.binaryRegion, \.sourceLanguage
      )
    }
  }
}

extension ArtifactLocation: MergeHashable {
  typealias Context = Void

  internal struct MergeKey: MergeKeyProtocol<ArtifactLocation> {
    private let uri: URL?
    private let uriBaseId: String?

    init(for artifactLocation: ArtifactLocation, with context: Void) {
      self.uri = artifactLocation.uri
      self.uriBaseId = artifactLocation.uriBaseId
    }
  }

}

extension ArtifactLocationReference: MergeableValue {
  typealias Context = ReferenceMergeMap<Artifact>

  internal struct MergeKey: MergeKeyProtocol<ArtifactLocationReference> {
    private let artifact: Artifact?

    init(
      for artifactLocation: ArtifactLocationReference,
      with context: ReferenceMergeMap<Artifact>
    ) {
      self.artifact = context.resolve(from: artifactLocation.artifact)
    }

    static func == (lhs: MergeKey, rhs: MergeKey) -> Bool {
      lhs.artifact === rhs.artifact
    }

    func hash(into hasher: inout Hasher) {
      hasher.combine(self.artifact.map { ObjectIdentifier($0) })
    }
  }

  internal struct MergeState: ValueMergeStateProtocolWithContext {
    func merge(
      merger: inout PropertyMerger<ArtifactLocationReference>,
      with context: Context
    )
      throws
    {
      try merger.keepFirstReference(key: \.artifact) {
        context.resolve(from: $0)
      }
    }
  }
}

extension LogicalLocation: MergeableWithIdentity {
  typealias Context = ReferenceMergeMap<LogicalLocation>

  internal struct MergeState: MergeStateProtocolWithContext<LogicalLocation> {
    func merge(
      merger: inout PropertyMerger<LogicalLocation>,
      with context: Context
    )
      throws
    {
      try merger.keepFirstSpecified(
        keys: \.name, \.$fullyQualifiedName, \.decoratedName, \.kind)
      try merger.keepFirstReference(key: \.parent) { inputParent in
        context.resolve(from: inputParent)
      }
    }
  }

  internal struct MergeKey: MergeKeyProtocol<LogicalLocation> {
    private let name: String?
    private let decoratedName: String?
    private let fullyQualifiedName: String?
    private let kind: String?
    private let parent: LogicalLocation?

    init(for logicalLocation: LogicalLocation, with context: Context) {
      self.name = logicalLocation.name
      self.decoratedName = logicalLocation.decoratedName
      self.fullyQualifiedName = logicalLocation.fullyQualifiedName
      self.kind = logicalLocation.kind
      if let parent = logicalLocation.parent {
        self.parent = context.resolve(from: parent)
      } else {
        self.parent = nil
      }
    }
  }
}

extension PhysicalLocation: MergeableValue {
  typealias Context = ReferenceMergeMap<Artifact>

  internal struct MergeKey: MergeKeyProtocol<PhysicalLocation> {
    private let artifactLocation: ArtifactLocationReference.MergeKey?
    private let region: Region.MergeKey?

    init(
      for physicalLocation: PhysicalLocation,
      with context: ReferenceMergeMap<Artifact>
    ) throws {
      try self.artifactLocation = physicalLocation.artifactLocation?.mergeKey(
        with: context)
      try self.region = physicalLocation.region?.mergeKey(with: ())
    }
  }

  internal struct MergeState: ValueMergeStateProtocolWithContext<
    PhysicalLocation
  >
  {
    func merge(
      merger: inout PropertyMerger<PhysicalLocation>, with context: Context
    ) throws {
      try merger.mergeFirst(key: \.artifactLocation, with: context) {
        ArtifactLocationReference(to: Artifact())
      }
      try merger.mergeFirst(key: \.region, with: ()) {
        Region()
      }
      try merger.mergeFirst(key: \.contextRegion, with: ()) {
        Region()
      }
    }
  }
}

extension Location: MergeableValue {
  struct Context {
    let artifacts: ReferenceMergeMap<Artifact>
    let logicalLocations: ReferenceMergeMap<LogicalLocation>
    let inputSharedLogicalLocations: OrderedSet<LogicalLocation>
  }

  internal struct MergeKey: MergeKeyProtocol<Location> {
    private let physicalLocation: PhysicalLocation.MergeKey?
    private let logicalLocations: [LogicalLocation.MergeKey]

    init(for location: Location, with context: Context)
      throws
    {
      self.physicalLocation = try location.physicalLocation?.mergeKey(
        with: context.artifacts)
      self.logicalLocations = try location.logicalLocations.map {
        try $0.mergeKey(with: context.logicalLocations)
      }
    }
  }

  internal struct MergeState: ValueMergeStateProtocolWithContext<Location> {
    func merge(merger: inout PropertyMerger<Location>, with context: Context)
      throws
    {
      try merger.mergeFirst(key: \.physicalLocation, with: context.artifacts) {
        PhysicalLocation()
      }
      try merger.keepFirstReferences(key: \.logicalLocations) { inputLocation in
        if context.inputSharedLogicalLocations.contains(inputLocation) {
          // This logicalLocation was in the `run.logicalLocations` array, so we
          // will find the resolved version in the map.
          context.logicalLocations.resolve(from: inputLocation)
        } else {
          // This logicalLocation was defined directly in `location.logicalLocations`,
          // so we need to create a new definition cloned from the input location.
          // The parent must be a shared logicalLocation, so we resolve that normally.
          LogicalLocation(
            from: inputLocation,
            parent: context.logicalLocations.resolveOptional(
              from: inputLocation.parent))
        }
      }
    }
  }
}

extension Run: MergeableWithIdentity {
  typealias Context = Void

  internal struct MergeKey: MergeKeyProtocol<Run> {
    private let tool: Tool.MergeKey

    init(for run: Run, with context: Context) throws {
      let toolContext = Tool.Context(rules: .init())
      try self.tool = run.tool.mergeKey(with: toolContext)
    }
  }

  internal struct MergeState: MergeStateProtocolWithContext<Run> {
    private var tool = Merger<Tool>()
    private var artifacts = ArrayMerger<Artifact, Run>()
    private var results = ArrayMerger<Result, Run>()
    private var logicalLocations = ArrayMerger<LogicalLocation, Run>()

    mutating func merge(
      merger: inout PropertyMerger<Run>, with context: Context
    ) throws {
      let output = merger.output

      try merger.assertEqualOrNil(keys: \.columnKind)
      try merger.concatenate(key: \.invocations)

      let rules = ReferenceMergeMap<Rule>()
      let toolContext = Tool.Context(rules: rules)
      try self.tool.merge(key: \.tool, merger: &merger, with: toolContext)

      let artifactsMap = ReferenceMergeMap<Artifact>()
      try self.artifacts.merge(
        key: \.artifacts, merger: &merger, map: artifactsMap
      ) { inputArtifact in
        output.addArtifact()
      }

      let logicalLocationsMap = ReferenceMergeMap<LogicalLocation>()
      try self.logicalLocations.mergeForest(
        key: \.logicalLocations, merger: &merger, with: logicalLocationsMap,
        map: logicalLocationsMap,
        makeForest: { LogicalLocationForest(elements: $0) }
      ) {
        inputLocation, parentLocation in
        LogicalLocation()
      } addOutput: { outputLocation in
        output.logicalLocations.append(outputLocation)
      }

      let resultContext = Result.Context(
        rules: rules, artifacts: artifactsMap,
        logicalLocations: logicalLocationsMap,
        inputSharedLogicalLocations: merger.input.logicalLocations)
      try self.results.merge(
        key: \.results, merger: &merger, with: resultContext, map: .init()
      ) {
        inputResult in
        output.addResult(
          rule: rules.resolve(from: inputResult.rule),
          message: inputResult.message)
      }
    }
  }
}

extension SARIFLog: MergeableWithIdentity {
  typealias Context = Void

  internal struct MergeState: MergeStateProtocol<SARIFLog> {
    private var runs: ArrayMerger<Run, SARIFLog> = .init()

    internal mutating func merge(merger: inout PropertyMerger<SARIFLog>) throws
    {
      // Ensure the SARIF versions match.
      // TODO: Once we support multiple SARIF versions, auto-upgrade the output log to the greatest version of the input logs.
      if merger.first {
        merger.output.version = merger.input.version
        merger.output.$schema = merger.input.$schema
      } else if merger.input.version > merger.output.version {
        merger.output.version = merger.input.version
        merger.output.$schema = merger.input.$schema
      }

      let output = merger.output
      try self.runs.merge(key: \.runs, merger: &merger, map: .init()) {
        inputRun in
        let inputDriver = inputRun.tool.driver
        return output.addRun(
          tool: Tool(
            driver: ToolComponent(
              named: inputDriver.name, guid: inputDriver.guid)))
      }
    }
  }

  internal struct MergeKey: MergeKeyProtocol<SARIFLog> {
    init(for object: SARIFLog, with context: Void) {
    }
  }
}

public struct SARIFLogMerger: ~Copyable {
  public let outputLog: SARIFLog
  private var mergeState = SARIFLog.MergeState()
  private let sink: any ValidationSink
  private var first = true

  public init(into outputLog: SARIFLog, sink: any ValidationSink) {
    self.outputLog = outputLog
    self.sink = sink
  }

  public mutating func merge(from inputLog: SARIFLog) throws {
    var merger = PropertyMerger(
      from: inputLog, into: self.outputLog, first: self.first, sink: self.sink)
    try self.mergeState.merge(merger: &merger)
    self.first = false
  }
}
