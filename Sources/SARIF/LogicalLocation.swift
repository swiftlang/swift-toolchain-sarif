public import SARIFRecords

internal struct LogicalLocationLoadTraits: DefinitionLoadMapTraits {
  typealias Definition = LogicalLocation

  fileprivate let propertyProviders: PropertyProviders
  fileprivate let sink: any ValidationSink

  init(propertyProviders: PropertyProviders, sink: any ValidationSink) {
    self.propertyProviders = propertyProviders
    self.sink = sink
  }

  func keyNotFound(key: ArrayIndex) throws -> Never {
    try self.sink.fatalError("No LogicalLocation found with index '\(key)'.")
  }
}

internal typealias LogicalLocationLoadMap = DefinitionLoadMap<
  LogicalLocationLoadTraits
>

extension LogicalLocationLoadMap {
  convenience init(
    propertyProviders: PropertyProviders, sink: any ValidationSink
  ) {
    self.init(
      with: LogicalLocationLoadTraits(
        propertyProviders: propertyProviders, sink: sink))
  }

  private func validateAgainstDefinition<T: Equatable>(
    key: KeyPath<LogicalLocationRecord, T?>, reference: LogicalLocationRecord,
    definitionValue: T?
  ) throws {
    if let referenceValue = reference[keyPath: key] {
      guard referenceValue == definitionValue else {
        try self.traits.sink.fatalError(
          "'\(key)' property of LogicalLocation must match the value from the LogicalLocation object referenced by 'index'."
        )
      }
    }
  }

  func resolveOrCreate(from record: LogicalLocationRecord) throws
    -> LogicalLocation
  {
    if let index = record.index {
      let definition = try self.resolveDefinition(key: index)
      try validateAgainstDefinition(
        key: \.name, reference: record, definitionValue: definition.name)
      try validateAgainstDefinition(
        key: \.decoratedName, reference: record,
        definitionValue: definition.decoratedName)
      try validateAgainstDefinition(
        key: \.fullyQualifiedName, reference: record,
        definitionValue: definition.$fullyQualifiedName)
      try validateAgainstDefinition(
        key: \.kind, reference: record, definitionValue: definition.kind)
      return definition
    } else {
      // Create a new object.
      let parentLocation: LogicalLocation?
      if let parentIndex = record.parentIndex {
        parentLocation = try self.resolveDefinition(key: parentIndex)
      } else {
        parentLocation = nil
      }
      return try LogicalLocation(
        from: record, parentLocation: parentLocation,
        propertyProviders: self.traits.propertyProviders, sink: self.traits.sink
      )
    }
  }
}

internal typealias LogicalLocationSaveMap = DefinitionSaveMap<
  LogicalLocation, ArrayIndex
>

extension DefinitionSaveMap
where Definition == LogicalLocation, Key == ArrayIndex {
  func makeReferenceJSON(to logicalLocation: LogicalLocation)
    -> LogicalLocationRecord
  {
    if let definitionIndex = self.definitionIndex(of: logicalLocation) {
      // Just need the index to refer to the definition
      return .init(
        index: definitionIndex, name: nil, fullyQualifiedName: nil,
        decoratedName: nil, kind: nil,
        parentIndex: nil)
    } else {
      // No cached definition, so need all the other properties.
      return makeDefinitionJSON(for: logicalLocation)
    }
  }

  func makeDefinitionJSON(for logicalLocation: LogicalLocation)
    -> LogicalLocationRecord
  {
    let parentIndex = logicalLocation.parent.map { parent in
      self.definitionIndex(of: parent)!  // TODO: Report error?
    }

    return .init(
      index: nil, name: logicalLocation.name,
      fullyQualifiedName: logicalLocation.$fullyQualifiedName,
      decoratedName: logicalLocation.decoratedName, kind: logicalLocation.kind,
      parentIndex: parentIndex)
  }
}

/// Defaults the `fullyQualifiedName` property to be the value of the `name` property for a root `logicalLocation`.
@propertyWrapper
public struct LogicalFullyQualifiedName {
  private var value: String? = nil

  public init(value: String? = nil) {
    self.value = value
  }

  public static subscript<Owner: LogicalLocation>(
    _enclosingInstance owner: Owner,
    wrapped wrapped: ReferenceWritableKeyPath<Owner, String?>,
    storage storage: ReferenceWritableKeyPath<Owner, Self>
  ) -> String? {
    get {
      if let fullyQualifiedName = owner[keyPath: storage].value {
        // Explicitly specified.
        fullyQualifiedName
      } else if owner.parent == nil {
        // Fall back to the `name` property.
        owner.name
      } else {
        // Not specified, but not a root, so no default value.
        nil
      }
    }
    set { owner[keyPath: storage].value = newValue }
  }

  @available(*, unavailable, message: "Must be a member of LogicalLocation")
  public var wrappedValue: String? {
    get { fatalError() }
    set { fatalError() }
  }

  public var projectedValue: String? {
    get { value }
    set { value = newValue }
  }
}

public final class LogicalLocation: Hashable, Identifiable,
  JSONRepresentable<LogicalLocationRecord>
{
  public var name: String?
  @LogicalFullyQualifiedName
  public var fullyQualifiedName: String?
  public var decoratedName: String?
  public var kind: String?
  public var parent: LogicalLocation?
  public var properties: PropertyBag

  package init() {
    self.properties = .init()
  }

  package init(from location: LogicalLocation, parent: LogicalLocation?) {
    self.name = location.name
    self.decoratedName = location.decoratedName
    self.kind = location.kind
    self.parent = parent
    self.properties = location.properties
    self.$fullyQualifiedName = location.$fullyQualifiedName
  }

  internal init(
    from logicalLocationRecord: LogicalLocationRecord,
    parentLocation: LogicalLocation?, propertyProviders: PropertyProviders,
    sink: any ValidationSink
  )
    throws
  {
    self.name = logicalLocationRecord.name
    self.decoratedName = logicalLocationRecord.decoratedName
    self.kind = logicalLocationRecord.kind
    self.parent = parentLocation
    self.properties = try .init(
      from: logicalLocationRecord.properties ?? [:],
      providers: propertyProviders)
    self.$fullyQualifiedName = logicalLocationRecord.fullyQualifiedName
  }

  func toJSON(with logicalLocations: LogicalLocationSaveMap) throws
    -> LogicalLocationRecord
  {
    let parentIndex: Int?
    if let parentLocation = self.parent {
      parentIndex = logicalLocations.definitionIndex(of: parentLocation)
    } else {
      parentIndex = nil
    }

    return try .init(
      index: nil, name: self.name, fullyQualifiedName: self.$fullyQualifiedName,
      decoratedName: self.decoratedName, kind: self.kind,
      parentIndex: parentIndex, properties: self.properties.ifNotEmpty.toJSON())
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.id)
  }

  public static func == (lhs: LogicalLocation, rhs: LogicalLocation) -> Bool {
    lhs === rhs
  }
}
