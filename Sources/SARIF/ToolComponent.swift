import Foundation
public import OrderedCollections
public import SARIFRecords

public struct ToolComponentContents: OptionSet, Sendable, Codable,
  JSONRepresentable<
    [ToolComponentContentsKind]
  >
{
  public let rawValue: UInt8

  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  public init(_ elements: [ToolComponentContentsKind]) {
    self = .neither

    for value in elements {
      switch value {
      case .localizedData:
        self.insert(.localizedData)
      case .nonLocalizedData:
        self.insert(.nonLocalizedData)
      }
    }
  }

  internal func toJSON() -> [ToolComponentContentsKind] {
    var result: [ToolComponentContentsKind] = []
    if self.contains(.localizedData) {
      result.append(.localizedData)
    }
    if self.contains(.nonLocalizedData) {
      result.append(.nonLocalizedData)
    }

    return result
  }

  internal var ifNotDefault: Self? {
    if self == Self.both {
      nil
    } else {
      self
    }
  }

  public static let localizedData = ToolComponentContents(rawValue: 0x01)
  public static let nonLocalizedData = ToolComponentContents(rawValue: 0x02)

  public static let neither: ToolComponentContents = []
  public static let both: ToolComponentContents = [
    .localizedData, .nonLocalizedData,
  ]
}

@propertyWrapper
public struct WithFallbackToSemanticVersion {
  private var value: String? = nil

  public init(value: String? = nil) {
    self.value = value
  }

  public static subscript<Owner: ToolComponent>(_enclosingInstance owner: Owner,
    wrapped wrapped: ReferenceWritableKeyPath<Owner, String?>,
    storage storage: ReferenceWritableKeyPath<Owner, Self>
  ) -> String? {
    get { owner[keyPath: storage].value ?? owner.semanticVersion }
    set { owner[keyPath: storage].value = newValue }
  }

  @available(*, unavailable, message: "Must be a member of ToolComponent")
  public var wrappedValue: String? {
    get { fatalError() }
    set { fatalError() }
  }

  public var projectedValue: String? {
    get { value }
    set { value = newValue }
  }
}

internal struct ToolComponentSaveContext {
  public let extensionIndex: ArrayIndex?
  private let ruleMap: DefinitionSaveMap<Rule, RuleKey>

  internal init(
    extensionIndex: ArrayIndex?, ruleMap: DefinitionSaveMap<Rule, RuleKey>
  ) {
    self.extensionIndex = extensionIndex
    self.ruleMap = ruleMap
  }

  internal func addRule(_ rule: Rule, index: ArrayIndex) {
    self.ruleMap.add(
      rule, key: RuleKey(toolComponentIndex: extensionIndex, index: index))
  }
}

public struct DefaultBothContents: DefaultValueProvider {
  public static let defaultValue = ToolComponentContents.both
}

//@Mergeable
public final class ToolComponent: JSONRepresentable<ToolComponentRecord> {
  public var version: String?
  public var semanticVersion: String?
  public var guid: UUID?
  public var name: String
  public var fullName: String?
  public var product: String?
  public var productSuite: String?
  public var dottedQuadFileVersion: String?
  public var releaseDateUtc: String?
  public var downloadUri: URL?
  public var informationUri: URL?
  public var organization: String?
  public var shortDescription: MultiFormatMessageString?
  public var fullDescription: MultiFormatMessageString?
  public var language: String?
  @WithDefaultValue<DefaultBothContents>
  public var contents: ToolComponentContents
  @WithDefaultValue<DefaultFalse>
  public var isComprehensive: Bool
  @WithFallbackToSemanticVersion
  public var localizedDataSementicVersion: String?
  @WithFallbackToSemanticVersion
  public var minimumRequiredLocalizedDataSemanticVersion: String?
  public var rules: OrderedSet<Rule> = []
  public var notifications: [Notification] = []
  public var globalMessageStrings:
    OrderedDictionary<MessageID, MultiFormatMessageString> = [:]
  private var synthesizedRules: [String: Rule] = [:]

  public init(named name: String, guid: UUID? = nil) {
    self.name = name
    self.guid = guid
  }

  internal init(
    from componentRecord: ToolComponentRecord, sink: any ValidationSink,
    with context: RuleLoadMap.DescriptorIndex
  ) throws {
    @Validating(sink: sink) var record = componentRecord

    self.version = record.version
    self.semanticVersion = record.semanticVersion
    self.guid = record.guid
    self.name = record.name
    self.fullName = record.fullName
    self.dottedQuadFileVersion = record.dottedQuadFileVersion
    self.releaseDateUtc = record.releaseDateUtc
    self.downloadUri = record.downloadUri  // TODO: Must be absolute
    self.informationUri = record.informationUri  // TODO: Must be absolute
    self.organization = record.organization
    self.shortDescription = try record.shortDescription.map {
      try .init(from: $0, sink: sink)
    }
    self.fullDescription = try record.fullDescription.map {
      try .init(from: $0, sink: sink)
    }
    self.language = record.language  // TODO: Required for translation
    self.globalMessageStrings =
      try record.globalMessageStrings.map { messageStrings in
        try messageStrings.orderedDictionary.mapValues { messageString in
          try MultiFormatMessageString(from: messageString, sink: sink)
        }
      } ?? [:]

    try $record.forbid(\.taxa, message: "'taxa' NYI.")
    try $record.forbid(
      \.supportedTaxonomies, message: "'supportedTaxonomies' NYI.")
    try $record.forbid(
      \.translationMetadata, message: "'translationMetadata' NYI.")
    try $record.forbid(\.locations, message: "'locations' NYI.")

    self._localizedDataSementicVersion = .init()
    self._minimumRequiredLocalizedDataSemanticVersion = .init()

    let rules = try (record.rules ?? []).map { ruleRecord in
      let rule = try Rule(from: ruleRecord, in: self, sink: sink)
      try context.append(rule, guid: rule.guid)
      return rule
    }
    self.rules = .init(rules)

    self.notifications = try (record.notifications ?? []).map {
      try Notification(from: $0, in: self, sink: sink)
    }

    try $record.forbid(
      \.associatedComponent, message: "'associatedComponent' NYI.")

    self.$isComprehensive = record.isComprehensive

    self.$contents = record.contents.map { ToolComponentContents($0) }

    self.$localizedDataSementicVersion = record.localizedDataSemanticVersion
    self.$minimumRequiredLocalizedDataSemanticVersion =
      record.minimumRequiredLocalizedDataSemanticVersion
  }

  public func addRule(id: String) -> Rule {
    let rule = Rule(id: id, in: self, isSynthetic: false)
    self.rules.append(rule)
    return rule
  }

  public func synthesizeRule(id: String) -> Rule {
    if let rule = self.synthesizedRules[id] {
      return rule
    } else {
      let rule = Rule(id: id, in: self, isSynthetic: true)
      self.synthesizedRules[id] = rule
      return rule
    }
  }

  internal func toJSON(with context: ToolComponentSaveContext) throws
    -> ToolComponentRecord
  {
    ToolComponentRecord(
      name: self.name.toJSON(),
      guid: try guid.toJSON(),
      version: try version.toJSON(),
      semanticVersion: try semanticVersion.toJSON(),
      fullName: try fullName.toJSON(),
      product: try product.toJSON(),
      productSuite: try productSuite.toJSON(),
      dottedQuadFileVersion: try dottedQuadFileVersion.toJSON(),
      releaseDateUtc: try releaseDateUtc.toJSON(),
      downloadUri: try downloadUri.toJSON(),
      informationUri: try informationUri.toJSON(),
      organization: try organization.toJSON(),
      language: try language.toJSON(),
      isComprehensive: try $isComprehensive.toJSON(),
      localizedDataSemanticVersion: nil,  // FIXME
      minimumRequiredLocalizedDataSemanticVersion:
        try minimumRequiredLocalizedDataSemanticVersion.toJSON(),
      contents: try self.contents.ifNotDefault.toJSON(),
      associatedComponent: nil,  // FIXME
      shortDescription: try shortDescription.toJSON(),
      fullDescription: try fullDescription.toJSON(),
      translationMetadata: nil,  // FIXME
      rules: try rules.ifNotEmpty?.enumerated().map { index, rule in
        context.addRule(rule, index: ArrayIndex(index))
        return try rule.toJSON()
      },
      notifications: try notifications.ifNotEmpty?.toJSON(),
      locations: nil,  // FIXME
      globalMessageStrings: nil,  // FIXME
      taxa: nil,  // FIXME
      supportedTaxonomies: nil  // FIXME
    )
  }

  internal func getMessageString(id: MessageID) -> MultiFormatMessageString? {
    self.globalMessageStrings[id]
  }
}
