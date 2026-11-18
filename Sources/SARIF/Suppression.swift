import Foundation
public import SARIFRecords

/// A request to suppress a `Result`.
public struct Suppression: JSONRepresentableWithContext {
  public var kind: SuppressionKind
  public var status: SuppressionStatus?
  public var location: Location?
  public var guid: UUID?
  public var justification: String?
  public var properties: PropertyBag

  public init(
    kind: SuppressionKind,
    status: SuppressionStatus? = nil,
    location: Location? = nil,
    guid: UUID? = nil,
    justification: String? = nil,
    properties: PropertyBag = [:]
  ) {
    self.kind = kind
    self.status = status
    self.location = location
    self.guid = guid
    self.justification = justification
    self.properties = properties
  }

  internal init(
    from suppressionRecord: SuppressionRecord,
    propertyProviders: PropertyProviders,
    sink: any ValidationSink,
    artifacts: ArtifactReferenceResolver,
    logicalLocations: LogicalLocationLoadMap
  ) throws {
    self.kind = suppressionRecord.kind
    self.status = suppressionRecord.status
    self.location = try suppressionRecord.location.map {
      try Location(
        from: $0, sink: sink, artifacts: artifacts,
        logicalLocations: logicalLocations)
    }
    self.guid = suppressionRecord.guid
    self.justification = suppressionRecord.justification
    self.properties = try .init(
      from: suppressionRecord.properties ?? [:], providers: propertyProviders)
  }

  internal func toJSON(with context: LocationSaveContext) throws
    -> SuppressionRecord
  {
    .init(
      kind: self.kind,
      status: self.status,
      location: try location.toJSON(with: context),
      guid: self.guid,
      justification: self.justification,
      properties: try self.properties.toJSON()
    )
  }
}
