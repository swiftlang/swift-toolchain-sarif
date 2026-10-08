public import Foundation
public import OrderedCollections
public import SARIFRecords

public final class Artifact: Identifiable, Hashable, SynthesizableDefinition,
  JSONRepresentableWithContext<ArtifactRecord>
{
  public var parent: Artifact? = nil
  public var location: ArtifactLocation?
  public var length: Int64? = nil
  public var roles: OrderedSet<ArtifactRole> = []
  public var mimeType: String? = nil
  public var encoding: String? = nil
  public var sourceLanguage: HierarchicalString? = nil

  internal struct Key: Hashable {
    let uri: URL
    let uriBaseId: String?
  }

  public init(
    location: ArtifactLocation? = nil, length: Int64? = nil,
    roles: some Sequence<ArtifactRole> = [], mimeType: String? = nil,
    encoding: String? = nil, sourceLanguage: HierarchicalString? = nil
  ) {
    self.location = location
    self.length = length
    self.roles = .init(roles)
    self.mimeType = mimeType
    self.encoding = encoding
    self.sourceLanguage = sourceLanguage
  }

  internal init(synthesizedFromKey key: Key) {
    self.location = ArtifactLocation(uri: key.uri, uriBaseId: key.uriBaseId)
  }

  internal init(
    from artifactRecord: ArtifactRecord, sink: any ValidationSink,
    index: ArrayIndex,
    defaults: RunContext
  ) throws {
    @Validating(sink: sink) var artifact = artifactRecord

    try $artifact.forbid(\.parentIndex, message: "Nested artifacts NYI.")
    try $artifact.forbid(
      \.offset, message: "Unexpected 'offset' property in non-nested artifact.")
    let location = try $artifact.require(
      \.location,
      message: "Missing required 'location' property in non-nested artifact.'")
    self.location = try ArtifactLocation(
      from: location, artifactIndex: index, sink: sink)
    self.length = artifact.length
    self.roles = .init(artifact.roles ?? [])  // TODO: Uniqueness validation
    self.mimeType = artifact.mimeType
    try $artifact.forbid(\.contents, message: "Artifact contents NYI.")
    self.encoding = artifact.encoding ?? defaults.defaultEncoding
    self.sourceLanguage =
      artifact.sourceLanguage ?? defaults.defaultSourceLanguage
  }

  internal func toJSON(with context: DefinitionSaveMap<Artifact, ArrayIndex>)
    throws
    -> ArtifactRecord
  {
    .init(
      location: try location.toJSON(),
      parentIndex: self.parent.map { parent in
        context.definitionIndex(of: parent)!
      },
      offset: nil,  // FIXME
      length: try length.toJSON(),
      mimeType: try mimeType.toJSON(),
      contents: nil,  // FIXME
      encoding: try encoding.toJSON(),
      sourceLanguage: try sourceLanguage.toJSON(),
      lastModifiedTimeUtc: nil,  // FIXME
      description: nil,  // FIXME
      hashes: nil,  // FIXME
      roles: roles.elements
    )
  }

  public func hash(into hasher: inout Hasher) {
    hasher.combine(self.id)
  }

  public static func == (lhs: Artifact, rhs: Artifact) -> Bool {
    lhs === rhs
  }
}
