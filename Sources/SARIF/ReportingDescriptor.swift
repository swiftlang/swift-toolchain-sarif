public import Foundation
public import OrderedCollections
public import SARIFRecords

public protocol ReportingDescriptorKind {
}

public struct RuleDescriptorKind: ReportingDescriptorKind {
}

public typealias Rule = ReportingDescriptor<RuleDescriptorKind>

public struct NotificationDescriptorKind: ReportingDescriptorKind {
}

public typealias Notification = ReportingDescriptor<NotificationDescriptorKind>

internal struct ReportingDescriptorKey<Kind: ReportingDescriptorKind> {
  public let toolComponentIndex: ArrayIndex?
  public let index: ArrayIndex
}

internal typealias RuleKey = ReportingDescriptorKey<RuleDescriptorKind>

//@Mergeable
public final class ReportingDescriptor<Kind: ReportingDescriptorKind>: Hashable,
  Identifiable,
  JSONRepresentable<ReportingDescriptorRecord>
{
  public var id: String
  public weak let toolComponent: ToolComponent?
  public private(set) var isSynthetic: Bool
  @WithDefaultValue<DefaultEmptyOrderedSet>
  public var deprecatedIds: OrderedSet<String>
  public var guid: UUID?
  @WithDefaultValue<DefaultEmptyOrderedSet>
  public var deprecatedGuids: OrderedSet<UUID>
  public var name: String?
  @WithDefaultValue<DefaultEmptyOrderedSet>
  public var deprecatedNames: OrderedSet<String>
  public var shortDescription: MultiFormatMessageString?
  public var fullDescription: MultiFormatMessageString?
  @WithDefaultValue<DefaultEmptyOrderedDictionary>
  public var messageStrings:
    OrderedDictionary<MessageID, MultiFormatMessageString>
  public var helpUri: URL?
  public var help: MultiFormatMessageString?
  public var defaultConfiguration: ReportingConfiguration?

  public convenience init(id: String, in toolComponent: ToolComponent) {
    self.init(id: id, in: toolComponent, isSynthetic: false)
  }

  internal init(id: String, in toolComponent: ToolComponent, isSynthetic: Bool)
  {
    self.id = id
    self.toolComponent = toolComponent
    self.isSynthetic = isSynthetic
  }

  internal init(
    from reportingDescriptorRecord: ReportingDescriptorRecord,
    in toolComponent: ToolComponent,
    sink: any ValidationSink
  ) throws {
    @Validating(sink: sink) var record = reportingDescriptorRecord

    self.id = record.id
    self.isSynthetic = false
    self.toolComponent = toolComponent
    self.$deprecatedIds = record.deprecatedIds.map { .init($0) }
    self.guid = record.guid
    self.$deprecatedGuids = record.deprecatedGuids.map { .init($0) }
    self.name = record.name
    self.$deprecatedNames = record.deprecatedNames.map { .init($0) }
    self.shortDescription = try record.shortDescription.map {
      try .init(from: $0, sink: sink)
    }
    self.fullDescription = try record.fullDescription.map {
      try .init(from: $0, sink: sink)
    }
    self.$messageStrings = try record.messageStrings.map { record in
      try record.mapValues { messageRecord in
        try MultiFormatMessageString(from: messageRecord, sink: sink)
      }
    }
    self.helpUri = record.helpUri  // TODO: Must be absolute
    self.help = try record.help.map { try .init(from: $0, sink: sink) }
    self.defaultConfiguration = try record.defaultConfiguration.map {
      try .init(from: $0, sink: sink)
    }
    try $record.forbid(\.relationships, message: "'relationships' NYI.")
  }

  internal func toJSON() throws -> ReportingDescriptorRecord {
    .init(
      id: id.toJSON(),
      name: try name.toJSON(),
      guid: try guid.toJSON(),
      helpUri: try helpUri.toJSON(),
      shortDescription: try shortDescription.toJSON(),
      fullDescription: try fullDescription.toJSON(),
      help: try help.toJSON(),
      defaultConfiguration: try defaultConfiguration.toJSON(),
      messageStrings: try messageStrings.ifNotEmpty?.toJSON(),
      deprecatedIds: try deprecatedIds.ifNotEmpty.toJSON(),
      deprecatedNames: try deprecatedNames.ifNotEmpty.toJSON(),
      deprecatedGuids: try deprecatedGuids.ifNotEmpty.toJSON(),
      relationships: nil  // FIXME
    )
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.id)
  }

  public static func == (lhs: ReportingDescriptor, rhs: ReportingDescriptor)
    -> Bool
  {
    lhs === rhs
  }

  internal func getMessageString(id: MessageID) -> MultiFormatMessageString? {
    self.messageStrings[id] ?? self.toolComponent?.getMessageString(id: id)
  }
}
