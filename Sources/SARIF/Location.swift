public import SARIFRecords

internal struct LocationLoadContext {
  let logicalLocationMap: LogicalLocationLoadMap
}

internal struct LocationSaveContext {
  let artifacts: DefinitionSaveMap<Artifact, ArrayIndex>
  let logicalLocations: LogicalLocationSaveMap
}

public struct Location: JSONRepresentableWithContext<LocationRecord> {
  public struct DefaultSortKey: Comparable, SpaceshipComparable {
    private let physicalLocation: PhysicalLocation.DefaultSortKey?

    fileprivate init(for location: Location) {
      self.physicalLocation = location.physicalLocation?.defaultSortKey
    }

    public static func < (_ lhs: Self, _ rhs: Self) -> Bool {
      (lhs <=> rhs) ?? false
    }

    internal static func <=> (_ lhs: Self, _ rhs: Self) -> Bool? {
      (lhs.physicalLocation <=> rhs.physicalLocation)
    }
  }

  //    public var id: LocationID?
  public var physicalLocation: PhysicalLocation?
  public var logicalLocations: [LogicalLocation]
  public var message: Message?
  public var defaultSortKey: DefaultSortKey { .init(for: self) }

  public init(
    at physicalLocation: PhysicalLocation? = nil,
    logicalLocations: [LogicalLocation] = [],
    message: Message? = nil
  ) {
    self.physicalLocation = physicalLocation
    self.logicalLocations = logicalLocations
    self.message = message
  }

  public init(
    at region: Region,
    in artifact: Artifact
  ) {
    let artifactLocation = ArtifactLocationReference(to: artifact)
    self.init(
      at: PhysicalLocation(artifactLocation: artifactLocation, region: region))
  }

  public init(
    at textRegion: TextRegion,
    in artifact: Artifact
  ) {
    self.init(at: Region(text: textRegion), in: artifact)
  }

  public init(
    startLine: Int32, startColumn: Int32? = nil, endLine: Int32? = nil,
    endColumn: Int32? = nil, in artifact: Artifact
  ) {
    let textRegion = TextRegion(
      startLine: startLine, startColumn: startColumn, endLine: endLine,
      endColumn: endColumn)
    self.init(at: textRegion, in: artifact)
  }

  internal init(
    from locationRecord: LocationRecord, sink: any ValidationSink,
    artifacts: ArtifactReferenceResolver,
    logicalLocations: LogicalLocationLoadMap
  ) throws {
    @Validating(sink: sink) var record = locationRecord

    //        self.id = record.id  // TODO: Validate uniqueness
    self.physicalLocation = try record.physicalLocation.map {
      try .init(from: $0, sink: sink, artifacts: artifacts)
    }
    self.logicalLocations = try (record.logicalLocations ?? []).map { record in
      try logicalLocations.resolveOrCreate(from: record)
    }
    self.message = try record.message.map { try .init(from: $0, sink: sink) }
    try $record.forbid(\.annotations, message: "'annotations' NYI.")
    try $record.forbid(\.relationships, message: "'relationships' NYI.")
  }

  internal func toJSON(with context: LocationSaveContext) throws
    -> LocationRecord
  {
    .init(
      id: nil,  // FIXME
      physicalLocation: try self.physicalLocation.toJSON(
        with: context.artifacts),
      logicalLocations: self.logicalLocations.ifNotEmpty?.map {
        logicalLocation in
        context.logicalLocations.makeReferenceJSON(to: logicalLocation)
      },
      message: try self.message.toJSON(),
      annotations: nil,  // FIXME
      relationships: nil  // FIXME
    )
  }
}
