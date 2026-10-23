import Foundation
public import SARIFRecords

private struct RuleReferenceJSON {
  public let ruleId: HierarchicalString?
  public let ruleIndex: ArrayIndex?
  public let rule: ReportingDescriptorReferenceRecord?
}

internal final class RuleResolver {
  private let driver: ToolComponent
  private let ruleMap: RuleLoadMap

  init(ruleMap: RuleLoadMap, driver: ToolComponent) {
    self.ruleMap = ruleMap
    self.driver = driver
  }

  fileprivate func resolveRule(
    reference: ReportingDescriptorReferenceRecord?, ruleIndex: ArrayIndex?,
    ruleId: String
  ) throws -> Rule {
    if (ruleIndex != nil) || (reference != nil) {
      return try self.ruleMap.resolveDescriptor(
        reference: reference, shorthandIndex: ruleIndex)
    } else {
      // No rule metadata. Synthesize a `Rule` based on the `ruleId` property.
      // Note that we only need to consult `ruleId`, not `rule.id`, because if `rule` is present, there must be metadata.
      return self.driver.synthesizeRule(id: ruleId)
    }
  }
}

internal struct ResultSaveContext {
  let rules: DefinitionSaveMap<Rule, RuleKey>
  let artifacts: DefinitionSaveMap<Artifact, ArrayIndex>
  let logicalLocations: LogicalLocationSaveMap

  fileprivate func makeRuleReference(to rule: Rule, suffix: String?)
    -> RuleReferenceJSON
  {
    var ruleId = HierarchicalString(fromComponents: [rule.id])
    if let suffix {
      ruleId = ruleId.appending(suffix)
    }

    // TODO: Customize serialization options.
    if let key = self.rules.definitionIndex(of: rule) {
      if let extensionIndex = key.toolComponentIndex {
        // Rule is defined in an extension. Use a `ReportingDescriptorReference` with a `ToolComponentReference`
        return .init(
          ruleId: ruleId, ruleIndex: key.index,
          rule: ReportingDescriptorReferenceRecord(
            id: nil,  // Already specified in `Result`
            index: nil,  // Already specified in `Result`
            guid: nil,  // Ignored for now.
            toolComponent: ToolComponentReferenceRecord(
              index: extensionIndex,
              guid: nil,  // Ignored for now.
              name: nil  // Ignored for now.
            )
          ))
      } else {
        // Rule is defined in driver. No need for a `ReportingDescriptorReference`.
        return .init(ruleId: ruleId, ruleIndex: key.index, rule: nil)
      }
    } else {
      // Rule is not defined. Just emit the `ruleId`.
      return .init(ruleId: ruleId, ruleIndex: nil, rule: nil)
    }
  }
}

extension Validating {
  fileprivate func validateRuleId(_ key: KeyPath<T, HierarchicalString?>) throws
  {
    if let ruleId = self.value[keyPath: key] {
      guard !ruleId.components.isEmpty else {
        try self.sink.fatalError("'\(key)' must not be an empty string.")
      }
      guard ruleId.components.count <= 2 else {
        try self.sink.fatalError(
          "'\(key)' must not specify more than one additional component.")
      }
    }
  }
}

public final class Result: JSONRepresentableWithContext<ResultRecord>,
  Fingerprinted
{
  public enum Kind: Equatable {
    case pass
    case open
    case informational
    case notApplicable
    case review
    case fail(level: ResultLevel)
  }

  public struct DefaultSortKey: Comparable, SpaceshipComparable {
    private let location: Location.DefaultSortKey?
    private let rule: Rule
    private let ruleIdSuffix: String?

    fileprivate init(for result: Result) {
      self.location = result.locations.first?.defaultSortKey
      self.rule = result.rule
      self.ruleIdSuffix = result.ruleIdSuffix
    }

    public static func < (_ lhs: Self, _ rhs: Self) -> Bool {
      (lhs <=> rhs) ?? false
    }

    internal static func <=> (_ lhs: Self, _ rhs: Self) -> Bool? {
      (lhs.location <=> rhs.location) ?? (lhs.rule.id <=> rhs.rule.id)
        ?? (lhs.ruleIdSuffix <=> rhs.ruleIdSuffix)
    }
  }

  public var guid: UUID? = nil
  public var correlationGuid: UUID? = nil
  public var message: Message
  public var locations: [Location] = []
  public var analysisTarget: ArtifactLocationReference? = nil
  public var fingerprints: Fingerprints = .empty
  public var partialFingerprints: Fingerprints = .empty
  public var ruleIdSuffix: String? = nil
  public var rule: Rule
  public var kind: Kind = .fail(level: .warning)
  public var rank: Float? = nil
  public var resolvedMessage: MultiFormatMessageString {
    self.getMessageString()!
  }
  public var baselineState: BaselineState?
  public var defaultSortKey: DefaultSortKey { .init(for: self) }

  public convenience init(rule: Rule, messageText: String) {
    self.init(rule: rule, message: Message(text: messageText))
  }

  public init(rule: Rule, message: Message) {
    self.rule = rule
    self.message = message
  }

  internal init(
    from resultRecord: ResultRecord, sink: any ValidationSink,
    rules: RuleResolver,
    artifacts: ArtifactReferenceResolver,
    logicalLocations: LogicalLocationLoadMap
  ) throws {
    @Validating(sink: sink) var record = resultRecord

    try $record.forbid(\.taxa, message: "'taxa' NYI")

    let kind = record.kind ?? .fail
    let level = record.level ?? ((kind == .fail) ? .warning : .none)  // TODO: Inheritance
    if (kind != .fail) && (level != .none) {
      try sink.recoverableError(
        "Result with 'kind' = '\(kind)' must have 'level' = 'none'.")
    }
    self.kind =
      switch kind {
      case .fail: .fail(level: level)
      case .informational: .informational
      case .notApplicable: .notApplicable
      case .open: .open
      case .pass: .pass
      case .review: .review
      }
    self.message = try .init(from: record.message, sink: sink)
    self.locations = try (record.locations ?? []).map {
      try Location(
        from: $0, sink: sink, artifacts: artifacts,
        logicalLocations: logicalLocations)
    }
    self.analysisTarget = try record.analysisTarget.map {
      try ArtifactLocationReference(from: $0, sink: sink, artifacts: artifacts)
    }
    self.fingerprints = record.fingerprints ?? .init()
    self.partialFingerprints = record.partialFingerprints ?? .init()
    self.rank = record.rank  // TODO: Validation
    self.baselineState = record.baselineState

    // TODO: codeFlows, graphs, graphTraversals, stacks, relatedLocations, suppressions, attachments, workItemUris, hostedViewerUri, provenance, fixes, occurrenceCount,

    try $record.validateRuleId(\.ruleId)
    if let rule = record.rule {
      @Validating(sink: sink) var ruleRecord = rule
      try $ruleRecord.validateRuleId(\.id)
    }
    let ruleId: HierarchicalString
    if let resultRuleId = record.ruleId {
      ruleId = resultRuleId
      if let ruleDotId = record.rule?.id {
        guard ruleDotId == resultRuleId else {
          try sink.fatalError(
            "'ruleId' property of Result must match value of 'rule.id'.")
        }
      }
    } else if let ruleDotId = record.rule?.id {
      ruleId = ruleDotId
    } else {
      try sink.fatalError(
        "Result must specify at least one of 'ruleId' and 'rule.id'.")
    }

    self.rule = try rules.resolveRule(
      reference: record.rule, ruleIndex: record.ruleIndex,
      ruleId: ruleId.components[0])

    if ruleId.components.count > 1 {
      self.ruleIdSuffix = ruleId.components.last
    } else {
      self.ruleIdSuffix = nil
    }

    guard getMessageString() != nil else {
      try sink.fatalError("No message resolved")
    }
  }

  public func getPartialFingerprints() -> Fingerprints {
    self.partialFingerprints
  }

  internal func toJSON(with context: ResultSaveContext) throws -> ResultRecord {
    let ruleReference = context.makeRuleReference(
      to: self.rule, suffix: self.ruleIdSuffix)
    let (kind, level): (ResultKind?, ResultLevel?) =
      switch self.kind {
      case .fail(.warning): (nil, nil)
      case .fail(let failLevel): (nil, failLevel)
      case .informational: (.informational, nil)
      case .notApplicable: (.notApplicable, nil)
      case .open: (.open, nil)
      case .pass: (.pass, nil)
      case .review: (.review, nil)
      }

    let locationsContext = LocationSaveContext(
      artifacts: context.artifacts, logicalLocations: context.logicalLocations)
    return .init(
      message: try message.toJSON(),
      ruleId: try ruleReference.ruleId.toJSON(),
      guid: guid,
      kind: kind,
      level: level,
      correlationGuid: try correlationGuid.toJSON(),
      ruleIndex: ruleReference.ruleIndex,
      rule: ruleReference.rule,
      locations: try locations.ifNotEmpty?.toJSON(with: locationsContext),
      relatedLocations: nil,  // FIXME
      suppressions: nil,  // FIXME
      fixes: nil,  // FIXME
      fingerprints: try fingerprints.ifNotEmpty?.toJSON(),
      partialFingerprints: try partialFingerprints.ifNotEmpty?.toJSON(),
      taxa: nil,  // FIXME
      analysisTarget: try analysisTarget.toJSON(with: context.artifacts),
      webRequest: nil,  // FIXME
      webResponse: nil,  // FIXME
      codeFlows: nil,  // FIXME
      graphs: nil,  // FIXME
      graphTraversals: nil,  // FIXME
      stacks: nil,  // FIXME
      baselineState: self.baselineState,
      rank: try rank.toJSON(),
      attachments: nil,  // FIXME
      workItemUris: nil,  // FIXME
      hostedViewerUri: nil,  // FIXME
      provenance: nil,  // FIXME
      occurrenceCount: nil  // FIXME
    )
  }

  private func getMessageString() -> MultiFormatMessageString? {
    // TODO: Translations
    if let defaultMessage = self.message.defaultMessage {
      defaultMessage
    } else if let id = self.message.id {
      self.rule.getMessageString(id: id)
    } else {
      nil
    }
  }
}
