import Foundation
import OrderedCollections

public typealias ArrayIndex = Int

public typealias SARIFRecordConstraints = Codable & Sendable

/// A record representing a SARIF [sarifLog](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10540916)
/// object, which specifies the version of the file format and contains the output from one or more runs.
public struct SARIFLogRecord: SARIFRecordConstraints {
  enum CodingKeys: String, CodingKey {
    case version
    case schema = "$schema"
    case runs
    case inlineExternalProperties
  }

  public let version: String
  public let schema: URL?
  public let runs: [RunRecord]?
  public let inlineExternalProperties: [ExternalPropertiesRecord]?

  public init(
    version: String, schema: URL?, runs: [RunRecord],
    inlineExternalProperties: [ExternalPropertiesRecord]? = nil
  ) {
    self.version = version
    self.schema = schema
    self.runs = runs
    self.inlineExternalProperties = inlineExternalProperties
  }

  public init(
    runs: [RunRecord],
    inlineExternalProperties: [ExternalPropertiesRecord]? = nil
  ) {
    self.init(
      version: SARIFVersion.v2_1_0.rawValue, schema: SARIFVersion.v2_1_0.schema,
      runs: runs,
      inlineExternalProperties: inlineExternalProperties)
  }
}

public enum ColumnKind: String, SARIFRecordConstraints {
  case utf16CodeUnits
  case unicodeCodePoints
}

/// A record representing a SARIF [run](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10540922)
/// object, which describes a single run of an analysis tool and contains the output of that run.
public struct RunRecord: SARIFRecordConstraints {
  public let tool: ToolRecord
  public let columnKind: ColumnKind?
  public let artifacts: [ArtifactRecord]?
  public let invocations: [InvocationRecord]?
  public let results: [ResultRecord]?
  public let externalPropertyFileReferences:
    ExternalPropertyFileReferencesRecord?
  public let automationDetails: RunAutomationDetailsRecord?
  public let runAggregates: [RunAutomationDetailsRecord]?
  public let baselineGuid: UUID?
  public let language: String?
  public let taxonomies: [ToolComponentRecord]?
  public let translations: [ToolComponentRecord]?
  public let policies: [ToolComponentRecord]?
  public let conversion: ConversionRecord?
  public let versionControlProvenance: [VersionControlDetailsRecord]?
  public let originalUriBaseIds:
    JSONDictionary<String, ArtifactLocationRecord>?  // REVIEW: Stronger key type?
  public let specialLocations: SpecialLocationsRecord?
  public let logicalLocations: [LogicalLocationRecord]?
  public let addresses: [AddressRecord]?
  public let threadFlowLocations: [ThreadFlowLocationRecord]?
  public let graphs: [GraphRecord]?
  public let webRequests: [WebRequestRecord]?
  public let webResponses: [WebResponseRecord]?
  public let defaultEncoding: String?
  public let defaultSourceLanguage: HierarchicalString?
  public let newlineSequences: [String]?
  public let redactionTokens: [String]?

  public init(
    tool: ToolRecord,
    columnKind: ColumnKind? = nil,
    artifacts: [ArtifactRecord]? = nil,
    invocations: [InvocationRecord]? = nil,
    results: [ResultRecord]? = nil,
    externalPropertyFileReferences: ExternalPropertyFileReferencesRecord? = nil,
    automationDetails: RunAutomationDetailsRecord? = nil,
    runAggregates: [RunAutomationDetailsRecord]? = nil,
    baselineGuid: UUID? = nil,
    language: String? = nil,
    taxonomies: [ToolComponentRecord]? = nil,
    translations: [ToolComponentRecord]? = nil,
    policies: [ToolComponentRecord]? = nil,
    conversion: ConversionRecord? = nil,
    versionControlProvenance: [VersionControlDetailsRecord]? = nil,
    originalUriBaseIds: JSONDictionary<String, ArtifactLocationRecord>? = nil,
    specialLocations: SpecialLocationsRecord? = nil,
    logicalLocations: [LogicalLocationRecord]? = nil,
    addresses: [AddressRecord]? = nil,
    threadFlowLocations: [ThreadFlowLocationRecord]? = nil,
    graphs: [GraphRecord]? = nil,
    webRequests: [WebRequestRecord]? = nil,
    webResponses: [WebResponseRecord]? = nil,
    defaultEncoding: String? = nil,
    defaultSourceLanguage: HierarchicalString? = nil,
    newlineSequences: [String]? = nil,
    redactionTokens: [String]? = nil,
  ) {
    self.tool = tool
    self.columnKind = columnKind
    self.artifacts = artifacts
    self.invocations = invocations
    self.results = results
    self.externalPropertyFileReferences = externalPropertyFileReferences
    self.automationDetails = automationDetails
    self.runAggregates = runAggregates
    self.baselineGuid = baselineGuid
    self.language = language
    self.taxonomies = taxonomies
    self.translations = translations
    self.policies = policies
    self.conversion = conversion
    self.versionControlProvenance = versionControlProvenance
    self.originalUriBaseIds = originalUriBaseIds
    self.specialLocations = specialLocations
    self.logicalLocations = logicalLocations
    self.addresses = addresses
    self.threadFlowLocations = threadFlowLocations
    self.graphs = graphs
    self.webRequests = webRequests
    self.webResponses = webResponses
    self.defaultEncoding = defaultEncoding
    self.defaultSourceLanguage = defaultSourceLanguage
    self.newlineSequences = newlineSequences
    self.redactionTokens = redactionTokens
  }
}

public enum ResultKind: String, SARIFRecordConstraints {
  case pass = "pass"
  case open = "open"
  case informational = "informational"
  case notApplicable = "notApplicable"
  case review = "review"
  case fail = "fail"
}

public enum ResultLevel: String, SARIFRecordConstraints {
  case warning = "warning"
  case error = "error"
  case note = "note"
  case none = "none"
}

/// A record representing a SARIF [result](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541076)
/// object, which describes a single result detected by an analysis tool.
public struct ResultRecord: SARIFRecordConstraints {
  public let message: MessageRecord
  public let ruleId: HierarchicalString?
  public let guid: UUID?
  public let kind: ResultKind?
  public let level: ResultLevel?
  public let correlationGuid: UUID?
  public let ruleIndex: ArrayIndex?
  public let rule: ReportingDescriptorReferenceRecord?
  public let locations: [LocationRecord]?
  public let relatedLocations: [LocationRecord]?
  public let suppressions: [SuppressionRecord]?
  public let fixes: [FixRecord]?
  public let fingerprints: Fingerprints?
  public let partialFingerprints: Fingerprints?
  public let taxa: [ReportingDescriptorReferenceRecord]?
  public let analysisTarget: ArtifactLocationRecord?
  public let webRequest: WebRequestRecord?
  public let webResponse: WebResponseRecord?
  public let codeFlows: [CodeFlowRecord]?
  public let graphs: [GraphRecord]?
  public let graphTraversals: [GraphTraversalRecord]?
  public let stacks: [StackRecord]?
  public let baselineState: BaselineState?
  public let rank: Float?
  public let attachments: [AttachmentRecord]?
  public let workItemUris: [URL]?
  public let hostedViewerUri: URL?
  public let provenance: ResultProvenanceRecord?
  public let occurrenceCount: Int64?

  public init(
    message: MessageRecord,
    ruleId: HierarchicalString? = nil,
    guid: UUID? = nil,
    kind: ResultKind? = nil,
    level: ResultLevel? = nil,
    correlationGuid: UUID? = nil,
    ruleIndex: ArrayIndex? = nil,
    rule: ReportingDescriptorReferenceRecord? = nil,
    locations: [LocationRecord]? = nil,
    relatedLocations: [LocationRecord]? = nil,
    suppressions: [SuppressionRecord]? = nil,
    fixes: [FixRecord]? = nil,
    fingerprints: Fingerprints? = nil,
    partialFingerprints: Fingerprints? = nil,
    taxa: [ReportingDescriptorReferenceRecord]? = nil,
    analysisTarget: ArtifactLocationRecord? = nil,
    webRequest: WebRequestRecord? = nil,
    webResponse: WebResponseRecord? = nil,
    codeFlows: [CodeFlowRecord]? = nil,
    graphs: [GraphRecord]? = nil,
    graphTraversals: [GraphTraversalRecord]? = nil,
    stacks: [StackRecord]? = nil,
    baselineState: BaselineState? = nil,
    rank: Float? = nil,
    attachments: [AttachmentRecord]? = nil,
    workItemUris: [URL]? = nil,
    hostedViewerUri: URL? = nil,
    provenance: ResultProvenanceRecord? = nil,
    occurrenceCount: Int64? = nil,
  ) {
    self.message = message
    self.ruleId = ruleId
    self.guid = guid
    self.kind = kind
    self.level = level
    self.correlationGuid = correlationGuid
    self.ruleIndex = ruleIndex
    self.rule = rule
    self.locations = locations
    self.relatedLocations = relatedLocations
    self.suppressions = suppressions
    self.fixes = fixes
    self.fingerprints = fingerprints
    self.partialFingerprints = partialFingerprints
    self.taxa = taxa
    self.analysisTarget = analysisTarget
    self.webRequest = webRequest
    self.webResponse = webResponse
    self.codeFlows = codeFlows
    self.graphs = graphs
    self.graphTraversals = graphTraversals
    self.stacks = stacks
    self.baselineState = baselineState
    self.rank = rank
    self.attachments = attachments
    self.workItemUris = workItemUris
    self.hostedViewerUri = hostedViewerUri
    self.provenance = provenance
    self.occurrenceCount = occurrenceCount
  }
}

/// A record representing a SARIF [replacement](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541327)
/// object, which represents the replacement of a single region of an artifact.
public struct ReplacementRecord: SARIFRecordConstraints {
  public let deletedRegion: RegionRecord
  public let insertedContent: ArtifactContentRecord?

  public init(
    deletedRegion: RegionRecord, insertedContent: ArtifactContentRecord? = nil
  ) {
    self.deletedRegion = deletedRegion
    self.insertedContent = insertedContent
  }
}

/// A record representing a SARIF [artifactChange](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541323)
/// object, which represents a change to a single artifact.
public struct ArtifactChangeRecord: SARIFRecordConstraints {
  public let artifactLocation: ArtifactLocationRecord
  public let replacements: [ReplacementRecord]

  public init(
    artifactLocation: ArtifactLocationRecord, replacements: [ReplacementRecord]
  ) {
    self.artifactLocation = artifactLocation
    self.replacements = replacements
  }
}

/// A record representing a SARIF [fix](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541319)
/// object, which represents a proposed fix for the problem indicated by the containing ``ResultRecord``.
public struct FixRecord: SARIFRecordConstraints {
  public let message: MessageRecord?
  public let artifactChanges: [ArtifactChangeRecord]

  public init(
    message: MessageRecord? = nil, artifactChanges: [ArtifactChangeRecord]
  ) {
    self.message = message
    self.artifactChanges = artifactChanges
  }
}

/// A record representing a SARIF [resultProvenance](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541266)
/// object, which contains information about the how and when the containing ``ResultRecord`` was detected.
public struct ResultProvenanceRecord: SARIFRecordConstraints {
  public let firstDetectionTimeUtc: String?  // TODO: Format
  public let lastDetectionTimeUtc: String?  // TODO: Format
  public let firstDetectionRunGuid: UUID?
  public let lastDetectionRunGuid: UUID?
  public let invocationIndex: ArrayIndex?
  public let conversionSources: [PhysicalLocationRecord]?

  public init(
    firstDetectionTimeUtc: String? = nil,
    lastDetectionTimeUtc: String? = nil,
    firstDetectionRunGuid: UUID? = nil,
    lastDetectionRunGuid: UUID? = nil,
    invocationIndex: ArrayIndex? = nil,
    conversionSources: [PhysicalLocationRecord]? = nil
  ) {
    self.firstDetectionTimeUtc = firstDetectionTimeUtc
    self.lastDetectionTimeUtc = lastDetectionTimeUtc
    self.firstDetectionRunGuid = firstDetectionRunGuid
    self.lastDetectionRunGuid = lastDetectionRunGuid
    self.invocationIndex = invocationIndex
    self.conversionSources = conversionSources
  }
}

/// A record representing a SARIF [rectangle](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541139)
/// object, which specifies a rectangular area within an image.
public struct RectangleRecord: SARIFRecordConstraints {
  public let left: Float64
  public let top: Float64
  public let right: Float64
  public let bottom: Float64
  public let message: MessageRecord?

  public init(
    left: Float64,
    top: Float64,
    right: Float64,
    bottom: Float64,
    message: MessageRecord? = nil
  ) {
    self.left = left
    self.top = top
    self.right = right
    self.bottom = bottom
    self.message = message
  }
}

/// A record representing a SARIF [attachment](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541029)
/// object, which describes an artifact relevant to the detection of a result.
public struct AttachmentRecord: SARIFRecordConstraints {
  public let description: MessageRecord?
  public let location: ArtifactLocationRecord
  public let regions: [RegionRecord]?
  public let rectangles: [RectangleRecord]?

  public init(
    description: MessageRecord? = nil,
    location: ArtifactLocationRecord,
    regions: [RegionRecord]? = nil,
    rectangles: [RectangleRecord]? = nil
  ) {
    self.description = description
    self.location = location
    self.regions = regions
    self.rectangles = rectangles
  }
}

public enum BaselineState: String, SARIFRecordConstraints {
  case new
  case unchanged
  case updated
  case absent
}

public enum SuppressionKind: String, SARIFRecordConstraints {
  case inSource
  case external
}

public enum SuppressionStatus: String, SARIFRecordConstraints {
  case accepted
  case underReview
  case rejected
}

/// A record representing a SARIF [suppression](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541171)
/// object, which describes a request to suppress a result.
public struct SuppressionRecord: SARIFRecordConstraints {
  public let kind: SuppressionKind
  public let status: SuppressionStatus?
  public let location: LocationRecord?
  public let guid: UUID?
  public let justification: String?

  public init(
    kind: SuppressionKind,
    status: SuppressionStatus? = nil,
    location: LocationRecord? = nil,
    guid: UUID? = nil,
    justification: String? = nil
  ) {
    self.kind = kind
    self.status = status
    self.location = location
    self.guid = guid
    self.justification = justification
  }
}

/// A record representing a SARIF [stackFrame](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541240)
/// object, which describes a single stack frame within a call stack.
public struct StackFrameRecord: SARIFRecordConstraints {
  public let location: LocationRecord?
  public let module: String?
  public let threadId: Int?
  public let parameters: [String]?

  public init(
    location: LocationRecord? = nil,
    module: String? = nil,
    threadId: Int? = nil,
    parameters: [String]? = nil
  ) {
    self.location = location
    self.module = module
    self.threadId = threadId
    self.parameters = parameters
  }
}

/// A record representing a SARIF [stack](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541236)
/// object, which describes a single call stack.
public struct StackRecord: SARIFRecordConstraints {
  public let message: MessageRecord?
  public let frames: [StackFrameRecord]

  public init(
    message: MessageRecord? = nil,
    frames: [StackFrameRecord]
  ) {
    self.message = message
    self.frames = frames
  }
}

/// A record representing a SARIF [codeFlow](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541178)
/// object, which describes the progress of one or more programs through one or more thread flows, which together lead to the detection of a problem in the
/// system being analyzed.
public struct CodeFlowRecord: SARIFRecordConstraints {
  public let message: MessageRecord?
  public let threadFlows: [ThreadFlowRecord]?

  public init(
    message: MessageRecord? = nil,
    threadFlows: [ThreadFlowRecord]? = nil
  ) {
    self.message = message
    self.threadFlows = threadFlows
  }
}

/// A record representing a SARIF [threadFlow](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541182)
/// object, which is a sequence of code locations that specify a possible path through a single thread of execution such as an operating system thread or a fiber.
public struct ThreadFlowRecord: SARIFRecordConstraints {
  public let id: String?
  public let message: MessageRecord?
  public let initialState:
    JSONDictionary<String, MultiformatMessageStringRecord>?
  public let immutableState:
    JSONDictionary<String, MultiformatMessageStringRecord>?
  public let locations: [ThreadFlowLocationRecord]

  public init(
    id: String? = nil,
    message: MessageRecord? = nil,
    initialState: JSONDictionary<String, MultiformatMessageStringRecord>? = nil,
    immutableState: JSONDictionary<String, MultiformatMessageStringRecord>? =
      nil,
    locations: [ThreadFlowLocationRecord]
  ) {
    self.id = id
    self.message = message
    self.initialState = initialState
    self.immutableState = immutableState
    self.locations = locations
  }
}

public struct LocationID: TypedID {
  public let value: UInt

  public init(value: UInt) {
    self.value = value
  }
}

/// A record representing a SARIF [location](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541108)
/// object, which describes a location.
public struct LocationRecord: SARIFRecordConstraints {
  public let id: LocationID?
  public let physicalLocation: PhysicalLocationRecord?
  public let logicalLocations: [LogicalLocationRecord]?
  public let message: MessageRecord?
  public let annotations: [RegionRecord]?
  public let relationships: [LocationRelationshipRecord]?

  public init(
    id: LocationID? = nil,
    physicalLocation: PhysicalLocationRecord? = nil,
    logicalLocations: [LogicalLocationRecord]? = nil,
    message: MessageRecord? = nil,
    annotations: [RegionRecord]? = nil,
    relationships: [LocationRelationshipRecord]? = nil
  ) {
    self.id = id
    self.physicalLocation = physicalLocation
    self.logicalLocations = logicalLocations
    self.message = message
    self.annotations = annotations
    self.relationships = relationships
  }
}

/// A record representing a SARIF [locationRelationship](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541166)
/// object, which specifies one or more directed relationships from the containing ``LocationRecord`` to another one.
public struct LocationRelationshipRecord: SARIFRecordConstraints {
  public let target: LocationID
  public let kinds: [LocationRelationshipRecord]?
  public let description: MessageRecord?

  public init(
    target: LocationID,
    kinds: [LocationRelationshipRecord]? = nil,
    description: MessageRecord? = nil
  ) {
    self.target = target
    self.kinds = kinds
    self.description = description
  }
}

/// A record representing a SARIF [region](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541123)
/// object, which is a contiguous portion of an artifact.
public struct RegionRecord: SARIFRecordConstraints {
  public let startLine: Int32?
  public let startColumn: Int32?
  public let endLine: Int32?
  public let endColumn: Int32?
  public let charOffset: Int64?
  public let charLength: Int64?
  public let byteOffset: Int64?
  public let byteLength: Int64?
  public let snippet: ArtifactContentRecord?
  public let message: MessageRecord?
  public let sourceLanguage: HierarchicalString?

  public init(
    startLine: Int32? = nil,
    startColumn: Int32? = nil,
    endLine: Int32? = nil,
    endColumn: Int32? = nil,
    charOffset: Int64? = nil,
    charLength: Int64? = nil,
    byteOffset: Int64? = nil,
    byteLength: Int64? = nil,
    snippet: ArtifactContentRecord? = nil,
    message: MessageRecord? = nil,
    sourceLanguage: HierarchicalString? = nil
  ) {
    self.startLine = startLine
    self.startColumn = startColumn
    self.endLine = endLine
    self.endColumn = endColumn
    self.charOffset = charOffset
    self.charLength = charLength
    self.byteOffset = byteOffset
    self.byteLength = byteLength
    self.snippet = snippet
    self.message = message
    self.sourceLanguage = sourceLanguage
  }
}

/// A record representing a SARIF [artifactContent](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10540860)
/// object, which represents the content of an artifact.
public struct ArtifactContentRecord: SARIFRecordConstraints {
  public let text: String?
  public let binary: String?  // TODO: Base64

  public init(
    text: String? = nil,
    binary: String? = nil
  ) {
    self.text = text
    self.binary = binary
  }
}

/// A record representing a SARIF [physicalLocation](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541116)
/// object, which represents the physical location where a result was detected.
public struct PhysicalLocationRecord: SARIFRecordConstraints {
  public let artifactLocation: ArtifactLocationRecord?
  public let region: RegionRecord?
  public let contextRegion: RegionRecord?
  public let address: AddressRecord?

  public init(
    artifactLocation: ArtifactLocationRecord? = nil,
    region: RegionRecord? = nil,
    contextRegion: RegionRecord? = nil,
    address: AddressRecord? = nil
  ) {
    self.artifactLocation = artifactLocation
    self.region = region
    self.contextRegion = contextRegion
    self.address = address
  }
}

/// A record representing a SARIF [reportingDescriptorReference](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541300)
/// object, which identifies a particular `reportingDescriptor` object.
public struct ReportingDescriptorReferenceRecord: SARIFRecordConstraints {
  public let id: HierarchicalString?
  public let index: ArrayIndex?
  public let guid: UUID?
  public let toolComponent: ToolComponentReferenceRecord?

  public init(
    id: HierarchicalString? = nil,
    index: ArrayIndex? = nil,
    guid: UUID? = nil,
    toolComponent: ToolComponentReferenceRecord? = nil
  ) {
    self.id = id
    self.index = index
    self.guid = guid
    self.toolComponent = toolComponent
  }
}

public struct MessageID: TypedID {
  public let value: String

  public init(value: String) {
    self.value = value
  }
}

/// A record representing a SARIF [message](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10540897)
/// object, which describes a message intended to be viewed by a user.
public struct MessageRecord: SARIFRecordConstraints {
  public let id: MessageID?
  public let text: String?
  public let markdown: String?
  public let arguments: [String]?

  public init(
    id: MessageID? = nil,
    text: String? = nil,
    markdown: String? = nil,
    arguments: [String]? = nil
  ) {
    self.id = id
    self.text = text
    self.markdown = markdown
    self.arguments = arguments
  }
}

/// A record representing a SARIF [webRequest](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541246)
/// object, which describes an HTTP request.
public struct WebRequestRecord: SARIFRecordConstraints {
  public let index: ArrayIndex?
  public let `protocol`: String?
  public let version: String?
  public let target: String?
  public let method: String?
  public let headers: JSONDictionary<String, String>?
  public let parameters: JSONDictionary<String, String>?
  public let body: ArtifactContentRecord?

  public init(
    index: ArrayIndex? = nil,
    protocol: String? = nil,
    version: String? = nil,
    target: String? = nil,
    method: String? = nil,
    headers: JSONDictionary<String, String>? = nil,
    parameters: JSONDictionary<String, String>? = nil,
    body: ArtifactContentRecord? = nil
  ) {
    self.index = index
    self.protocol = `protocol`
    self.version = version
    self.target = target
    self.method = method
    self.headers = headers
    self.parameters = parameters
    self.body = body
  }
}

/// A record representing a SARIF [webResponse](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541256)
/// object, which describes the response to an HTTP request.
public struct WebResponseRecord: SARIFRecordConstraints {
  public let index: Int?
  public let `protocol`: String?
  public let version: String?
  public let statusCode: Int32?
  public let reasonPhrase: String?
  public let headers: JSONDictionary<String, String>?
  public let body: ArtifactContentRecord?
  public let noResponseReceived: Bool?

  public init(
    index: Int? = nil,
    protocol: String? = nil,
    version: String? = nil,
    statusCode: Int32? = nil,
    reasonPhrase: String? = nil,
    headers: JSONDictionary<String, String>? = nil,
    body: ArtifactContentRecord? = nil,
    noResponseReceived: Bool? = nil
  ) {
    self.index = index
    self.protocol = `protocol`
    self.version = version
    self.statusCode = statusCode
    self.reasonPhrase = reasonPhrase
    self.headers = headers
    self.body = body
    self.noResponseReceived = noResponseReceived
  }
}

public struct NodeID: TypedID {
  public let value: String

  public init(value: String) {
    self.value = value
  }
}

/// A record representing a SARIF [node](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541209)
/// object, which represents a node in the graph represented by the containing `graph` object.
public struct NodeRecord: SARIFRecordConstraints {
  public let id: NodeID
  public let label: MessageRecord?
  public let location: LocationRecord?
  public let children: [NodeRecord]?

  public init(
    id: NodeID,
    label: MessageRecord? = nil,
    location: LocationRecord? = nil,
    children: [NodeRecord]? = nil
  ) {
    self.id = id
    self.label = label
    self.location = location
    self.children = children
  }
}

public struct EdgeID: TypedID {
  public let value: String

  public init(value: String) {
    self.value = value
  }
}

/// A record representing a SARIF [edge](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541215)
/// object, which represents a directed edge in the graph represented by the containing `graph` object.
public struct EdgeRecord: SARIFRecordConstraints {
  public let id: EdgeID
  public let label: MessageRecord?
  public let sourceNodeId: NodeID
  public let targetNodeId: NodeID

  public init(
    id: EdgeID,
    label: MessageRecord? = nil,
    sourceNodeId: NodeID,
    targetNodeId: NodeID
  ) {
    self.id = id
    self.label = label
    self.sourceNodeId = sourceNodeId
    self.targetNodeId = targetNodeId
  }
}

/// A record representing a SARIF [graph](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541204)
/// object, which represents a directed graph, a network of nodes and directed edges that describes some aspect of the structure of the code (for example, a
/// call graph).
public struct GraphRecord: SARIFRecordConstraints {
  public let description: MessageRecord?
  public let nodes: [NodeRecord]?
  public let edges: [EdgeRecord]?

  public init(
    description: MessageRecord? = nil,
    nodes: [NodeRecord]? = nil,
    edges: [EdgeRecord]? = nil
  ) {
    self.description = description
    self.nodes = nodes
    self.edges = edges
  }
}

/// A record representing a SARIF [edgeTraversal](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541230)
/// object, which represents the traversal of a single edge during a graph traversal.
public struct EdgeTraversalRecord: SARIFRecordConstraints {
  public let edgeId: String
  public let message: MessageRecord?
  public let finalState: JSONDictionary<String, MultiformatMessageStringRecord>?
  public let stepOverEdgeCount: Int?

  public init(
    edgeId: String,
    message: MessageRecord? = nil,
    finalState: JSONDictionary<String, MultiformatMessageStringRecord>? = nil,
    stepOverEdgeCount: Int? = nil
  ) {
    self.edgeId = edgeId
    self.message = message
    self.finalState = finalState
    self.stepOverEdgeCount = stepOverEdgeCount
  }
}

/// A record representing a SARIF [graphTraversal](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541221)
/// object, which represents a path through a graph specified by a sequence of connected “edge traversals,” each of which is represented by an `edgeTraversal`
/// object.
public struct GraphTraversalRecord: SARIFRecordConstraints {
  public let resultGraphIndex: Int?
  public let runGraphIndex: Int?
  public let description: MessageRecord?
  public let initialState:
    JSONDictionary<String, MultiformatMessageStringRecord>?
  public let immutableState:
    JSONDictionary<String, MultiformatMessageStringRecord>?
  public let edgeTraversals: [EdgeTraversalRecord]?

  public init(
    resultGraphIndex: Int? = nil,
    runGraphIndex: Int? = nil,
    description: MessageRecord? = nil,
    initialState: JSONDictionary<String, MultiformatMessageStringRecord>? = nil,
    immutableState: JSONDictionary<String, MultiformatMessageStringRecord>? =
      nil,
    edgeTraversals: [EdgeTraversalRecord]? = nil
  ) {
    self.resultGraphIndex = resultGraphIndex
    self.runGraphIndex = runGraphIndex
    self.description = description
    self.initialState = initialState
    self.immutableState = immutableState
    self.edgeTraversals = edgeTraversals
  }
}

public enum Importance: String, SARIFRecordConstraints {
  case important
  case essential
  case unimportant
}

/// A record representing a SARIF [threadFlowLocation](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541189)
/// object, which represents a location visited by an analysis tool in the course of simulating or monitoring the execution of a program.
public struct ThreadFlowLocationRecord: SARIFRecordConstraints {
  public let index: ArrayIndex?
  public let location: LocationRecord?
  public let module: String?
  public let stack: StackRecord?
  public let webRequest: WebRequestRecord?
  public let webResponse: WebResponseRecord?
  public let kinds: [String]?
  public let state: JSONDictionary<String, MultiformatMessageStringRecord>?
  public let nestingLevel: Int32?
  public let executionOrder: Int32?
  public let executionTimeUtc: String?  // TODO: Format
  public let importance: Importance?
  public let taxa: [ReportingDescriptorReferenceRecord]?

  public init(
    index: ArrayIndex? = nil,
    location: LocationRecord? = nil,
    module: String? = nil,
    stack: StackRecord? = nil,
    webRequest: WebRequestRecord? = nil,
    webResponse: WebResponseRecord? = nil,
    kinds: [String]? = nil,
    state: JSONDictionary<String, MultiformatMessageStringRecord>? = nil,
    nestingLevel: Int32? = nil,
    executionOrder: Int32? = nil,
    executionTimeUtc: String? = nil,
    importance: Importance? = nil,
    taxa: [ReportingDescriptorReferenceRecord]? = nil
  ) {
    self.index = index
    self.location = location
    self.module = module
    self.stack = stack
    self.webRequest = webRequest
    self.webResponse = webResponse
    self.kinds = kinds
    self.state = state
    self.nestingLevel = nestingLevel
    self.executionOrder = executionOrder
    self.executionTimeUtc = executionTimeUtc
    self.importance = importance
    self.taxa = taxa
  }
}

/// A record representing a SARIF [address](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541143)
/// object, which describes a physical or virtual address, or a range of addresses, in an “addressable region” (memory or a binary file).
public struct AddressRecord: SARIFRecordConstraints {
  public let index: ArrayIndex?
  public let absoluteAddress: UInt64?
  public let relativeAddress: Int64?
  public let offsetFromParent: Int64?
  public let length: Int64?
  public let name: String?
  public let fullyQualifiedName: String?
  public let kind: String?  // TODO: enum
  public let parentIndex: ArrayIndex?

  public init(
    index: ArrayIndex? = nil,
    absoluteAddress: UInt64? = nil,
    relativeAddress: Int64? = nil,
    offsetFromParent: Int64? = nil,
    length: Int64? = nil,
    name: String? = nil,
    fullyQualifiedName: String? = nil,
    kind: String? = nil,
    parentIndex: ArrayIndex? = nil
  ) {
    self.index = index
    self.absoluteAddress = absoluteAddress
    self.relativeAddress = relativeAddress
    self.offsetFromParent = offsetFromParent
    self.length = length
    self.name = name
    self.fullyQualifiedName = fullyQualifiedName
    self.kind = kind
    self.parentIndex = parentIndex
  }
}

public enum LogicalLocationKind: String, SARIFRecordConstraints {
  case function
  case member
  case module
  case namespace
  case resource
  case type
  case returnType
  case parameter
  case variable
  case element
  case attribute
  case text
  case comment
  case processingInstruction
  case dtd
  case declaration
  case object
  case array
  case property
  case value
}

/// A record representing a SARIF [logicalLocation](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541157)
/// object, which describes a location specified by a programmatic construct such as a namespace, a type, or a method, without regard to the physical location where
/// the construct occurs.
public struct LogicalLocationRecord: SARIFRecordConstraints {
  public let index: ArrayIndex?
  public let name: String?
  public let fullyQualifiedName: String?
  public let decoratedName: String?
  public let kind: String?
  public let parentIndex: ArrayIndex?
  public let properties: PropertyBagRecord?

  public init(
    index: ArrayIndex? = nil,
    name: String? = nil,
    fullyQualifiedName: String? = nil,
    decoratedName: String? = nil,
    kind: String? = nil,
    parentIndex: ArrayIndex? = nil,
    properties: PropertyBagRecord? = nil
  ) {
    self.index = index
    self.name = name
    self.fullyQualifiedName = fullyQualifiedName
    self.decoratedName = decoratedName
    self.kind = kind
    self.parentIndex = parentIndex
    self.properties = properties
  }
}

/// A record representing a SARIF [specialLocations](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541065)
/// object, which defines locations of special significance to SARIF consumers.
public struct SpecialLocationsRecord: SARIFRecordConstraints {
  public let displayBase: ArtifactLocationRecord?

  public init(displayBase: ArtifactLocationRecord? = nil) {
    self.displayBase = displayBase
  }
}

public enum ArtifactRole: String, SARIFRecordConstraints {
  case analysisTarget
  case attachment
  case conversionSource
  case debugOutputFile
  case directory
  case driver
  case `extension`
  case externalPropertyFile
  case memoryContents
  case policy
  case referencedOnCommandLine
  case repositoryRoot
  case responseFile
  case resultFile
  case standardStream
  case taxonomy
  case toolSpecifiedConfiguration
  case tracedFile
  case translation
  case userSpecifiedConfiguration
  case added
  case deleted
  case modified
  case renamed
  case uncontrolled
  case unmodified
}

/// A record representing a SARIF [artifact](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541049)
/// object, which represents a single artifact.
public struct ArtifactRecord: SARIFRecordConstraints {
  public let location: ArtifactLocationRecord?
  public let parentIndex: ArrayIndex?
  public let offset: Int64?
  public let length: Int64?
  public let mimeType: String?
  public let contents: ArtifactContentRecord?
  public let encoding: String?
  public let sourceLanguage: HierarchicalString?
  public let lastModifiedTimeUtc: String?  // TODO: Format
  public let description: MessageRecord?
  public let hashes: JSONDictionary<String, String>?
  public let roles: [ArtifactRole]?

  public init(
    location: ArtifactLocationRecord? = nil,
    parentIndex: ArrayIndex? = nil,
    offset: Int64? = nil,
    length: Int64? = nil,
    mimeType: String? = nil,
    contents: ArtifactContentRecord? = nil,
    encoding: String? = nil,
    sourceLanguage: HierarchicalString? = nil,
    lastModifiedTimeUtc: String? = nil,
    description: MessageRecord? = nil,
    hashes: JSONDictionary<String, String>? = nil,
    roles: [ArtifactRole]? = nil
  ) {
    self.location = location
    self.parentIndex = parentIndex
    self.offset = offset
    self.length = length
    self.mimeType = mimeType
    self.contents = contents
    self.encoding = encoding
    self.sourceLanguage = sourceLanguage
    self.lastModifiedTimeUtc = lastModifiedTimeUtc
    self.description = description
    self.hashes = hashes
    self.roles = roles
  }
}

/// A record representing a SARIF [artifactLocation](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10540865)
/// obkect, which specifies the location of an `artifact`.
public struct ArtifactLocationRecord: SARIFRecordConstraints {
  public let uri: URL?
  public let uriBaseId: String?
  public let index: ArrayIndex?
  public let description: MessageRecord?

  public init(
    uri: URL? = nil,
    uriBaseId: String? = nil,
    index: ArrayIndex? = nil,
    description: MessageRecord? = nil
  ) {
    self.uri = uri
    self.uriBaseId = uriBaseId
    self.index = index
    self.description = description
  }
}

/// A record representing a SARIF [versionControlDetails](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541040)
/// object, which specifies the information necessary to retrieve from a version control system (VCS) the correct revision of the files that were scanned during the run.
public struct VersionControlDetailsRecord: SARIFRecordConstraints {
  public let repositoryUri: URL
  public let revisionId: String?  // TODO: redactable
  public let branch: String?  // TODO: redactable
  public let revisionTag: String?  // TODO: redactable
  public let asOfTimeUtc: String?  // TODO: format
  public let mappedTo: ArtifactLocationRecord?

  public init(
    repositoryUri: URL,
    revisionId: String? = nil,
    branch: String? = nil,
    revisionTag: String? = nil,
    asOfTimeUtc: String? = nil,
    mappedTo: ArtifactLocationRecord? = nil
  ) {
    self.repositoryUri = repositoryUri
    self.revisionId = revisionId
    self.branch = branch
    self.revisionTag = revisionTag
    self.asOfTimeUtc = asOfTimeUtc
    self.mappedTo = mappedTo
  }
}

/// A record representing a SARIF [conversion](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541035)
/// object, which describes how a converter transformed the output of an analysis tool from the analysis tool’s native output format into the SARIF format.
public struct ConversionRecord: SARIFRecordConstraints {
  public let tool: ToolRecord
  public let invocation: InvocationRecord?
  public let analysisToolLogFiles: [ArtifactLocationRecord]?

  public init(
    tool: ToolRecord,
    invocation: InvocationRecord? = nil,
    analysisToolLogFiles: [ArtifactLocationRecord]? = nil
  ) {
    self.tool = tool
    self.invocation = invocation
    self.analysisToolLogFiles = analysisToolLogFiles
  }
}

/// A record representing a SARIF [invocation](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541005)
/// object, which describes the invocation of the analysis tool that was run.
public struct InvocationRecord: SARIFRecordConstraints {
  public let commandLine: String?
  public let arguments: [String]?
  public let responseFiles: [ArtifactLocationRecord]?
  public let ruleConfigurationOverrides: [ConfigurationOverrideRecord]?
  public let notificationConfigurationOverrides: [ConfigurationOverrideRecord]?
  public let startTimeUtc: String?  // TODO: Format
  public let endTimeUtc: String?  // TODO: Format
  public let exitCode: Int32?
  public let exitCodeDescription: String?
  public let exitSignalName: String?
  public let exitSignalNumber: Int32?
  public let processStartFailureMessage: String?
  public let executionSuccessful: Bool
  public let machine: String?
  public let account: String?
  public let processId: Int32?
  public let executableLocation: ArtifactLocationRecord?
  public let workingDirectory: ArtifactLocationRecord?
  public let environmentVariables: JSONDictionary<String, String>?
  public let toolExecutionNotifications: [NotificationRecord]?
  public let toolConfigurationNotifications: [NotificationRecord]?
  public let stdin: String?
  public let stdout: String?
  public let stderr: String?
  public let stdoutStderr: String?
  public let properties: PropertyBagRecord?

  public init(
    commandLine: String? = nil,
    arguments: [String]? = nil,
    responseFiles: [ArtifactLocationRecord]? = nil,
    ruleConfigurationOverrides: [ConfigurationOverrideRecord]? = nil,
    notificationConfigurationOverrides: [ConfigurationOverrideRecord]? = nil,
    startTimeUtc: String? = nil,
    endTimeUtc: String? = nil,
    exitCode: Int32? = nil,
    exitCodeDescription: String? = nil,
    exitSignalName: String? = nil,
    exitSignalNumber: Int32? = nil,
    processStartFailureMessage: String? = nil,
    executionSuccessful: Bool,
    machine: String? = nil,
    account: String? = nil,
    processId: Int32? = nil,
    executableLocation: ArtifactLocationRecord? = nil,
    workingDirectory: ArtifactLocationRecord? = nil,
    environmentVariables: JSONDictionary<String, String>? = nil,
    toolExecutionNotifications: [NotificationRecord]? = nil,
    toolConfigurationNotifications: [NotificationRecord]? = nil,
    stdin: String? = nil,
    stdout: String? = nil,
    stderr: String? = nil,
    stdoutStderr: String? = nil,
    properties: PropertyBagRecord? = nil,
  ) {
    self.commandLine = commandLine
    self.arguments = arguments
    self.responseFiles = responseFiles
    self.ruleConfigurationOverrides = ruleConfigurationOverrides
    self.notificationConfigurationOverrides = notificationConfigurationOverrides
    self.startTimeUtc = startTimeUtc
    self.endTimeUtc = endTimeUtc
    self.exitCode = exitCode
    self.exitCodeDescription = exitCodeDescription
    self.exitSignalName = exitSignalName
    self.exitSignalNumber = exitSignalNumber
    self.processStartFailureMessage = processStartFailureMessage
    self.executionSuccessful = executionSuccessful
    self.machine = machine
    self.account = account
    self.processId = processId
    self.executableLocation = executableLocation
    self.workingDirectory = workingDirectory
    self.environmentVariables = environmentVariables
    self.toolExecutionNotifications = toolExecutionNotifications
    self.toolConfigurationNotifications = toolConfigurationNotifications
    self.stdin = stdin
    self.stdout = stdout
    self.stderr = stderr
    self.stdoutStderr = stdoutStderr
    self.properties = properties
  }
}

/// A record representing a SARIF [notification](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541332)
/// object, which describes a condition encountered during the execution of an analysis tool which is relevant to the operation of the tool itself, as opposed to being
/// relevant to an artifact being analyzed by the tool.
public struct NotificationRecord: SARIFRecordConstraints {
  public let descriptor: ReportingDescriptorReferenceRecord?
  public let associatedRule: ReportingDescriptorReferenceRecord?
  public let locations: [LocationRecord]?
  public let message: MessageRecord
  public let level: ResultLevel?
  public let threadId: Int32?
  public let timeUtc: String?  // TODO: Format
  public let exception: ExceptionRecord?

  public init(
    descriptor: ReportingDescriptorReferenceRecord? = nil,
    associatedRule: ReportingDescriptorReferenceRecord? = nil,
    locations: [LocationRecord]? = nil,
    message: MessageRecord,
    level: ResultLevel? = nil,
    threadId: Int32? = nil,
    timeUtc: String? = nil,
    exception: ExceptionRecord? = nil
  ) {
    self.descriptor = descriptor
    self.associatedRule = associatedRule
    self.locations = locations
    self.message = message
    self.level = level
    self.threadId = threadId
    self.timeUtc = timeUtc
    self.exception = exception
  }
}

/// A record representing a SARIF [exception](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541342)
/// object, which describes a runtime exception encountered during the execution of an analysis tool.
public struct ExceptionRecord: SARIFRecordConstraints {
  public let kind: String?
  public let message: String?
  public let stack: StackRecord?
  public let innerExceptions: [ExceptionRecord]?

  public init(
    kind: String? = nil,
    message: String? = nil,
    stack: StackRecord? = nil,
    innerExceptions: [ExceptionRecord]? = nil
  ) {
    self.kind = kind
    self.message = message
    self.stack = stack
    self.innerExceptions = innerExceptions
  }
}

/// A record representing a SARIF [configurationOverride](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541296)
/// object, which modifies the effective runtime configuration of a specified `reportingDescriptor` object.
public struct ConfigurationOverrideRecord: SARIFRecordConstraints {
  public let descriptor: ReportingDescriptorReferenceRecord
  public let configuration: ReportingConfigurationRecord

  public init(
    descriptor: ReportingDescriptorReferenceRecord,
    configuration: ReportingConfigurationRecord
  ) {
    self.descriptor = descriptor
    self.configuration = configuration
  }
}

public enum ToolComponentContentsKind: String, SARIFRecordConstraints {
  case localizedData
  case nonLocalizedData
}

/// A record representing a SARIF [toolComponent](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10540971)
/// object, which represents one of the components which comprise an analysis tool or a converter, either its driver or one of its extensions.
public struct ToolComponentRecord: SARIFRecordConstraints {
  public let name: String
  public let guid: UUID?
  public let version: String?
  public let semanticVersion: String?  // TODO: SemVer
  public let fullName: String?
  public let product: String?
  public let productSuite: String?
  public let dottedQuadFileVersion: String?  // TODO: Format
  public let releaseDateUtc: String?  // TODO: Format
  public let downloadUri: URL?
  public let informationUri: URL?
  public let organization: String?
  public let language: String?
  public let isComprehensive: Bool?
  public let localizedDataSemanticVersion: String?  // TODO: SemVer
  public let minimumRequiredLocalizedDataSemanticVersion: String?  // TODO: SemVer
  public let contents: [ToolComponentContentsKind]?
  public let associatedComponent: ToolComponentReferenceRecord?
  public let shortDescription: MultiformatMessageStringRecord?
  public let fullDescription: MultiformatMessageStringRecord?
  public let translationMetadata: TranslationMetadataRecord?
  public let rules: [ReportingDescriptorRecord]?
  public let notifications: [ReportingDescriptorRecord]?
  public let locations: [ArtifactLocationRecord]?
  public let globalMessageStrings:
    JSONDictionary<MessageID, MultiformatMessageStringRecord>?
  public let taxa: [ReportingDescriptorRecord]?
  public let supportedTaxonomies: [ToolComponentReferenceRecord]?

  public init(
    name: String,
    guid: UUID? = nil,
    version: String? = nil,
    semanticVersion: String? = nil,
    fullName: String? = nil,
    product: String? = nil,
    productSuite: String? = nil,
    dottedQuadFileVersion: String? = nil,
    releaseDateUtc: String? = nil,
    downloadUri: URL? = nil,
    informationUri: URL? = nil,
    organization: String? = nil,
    language: String? = nil,
    isComprehensive: Bool? = nil,
    localizedDataSemanticVersion: String? = nil,
    minimumRequiredLocalizedDataSemanticVersion: String? = nil,
    contents: [ToolComponentContentsKind]? = nil,
    associatedComponent: ToolComponentReferenceRecord? = nil,
    shortDescription: MultiformatMessageStringRecord? = nil,
    fullDescription: MultiformatMessageStringRecord? = nil,
    translationMetadata: TranslationMetadataRecord? = nil,
    rules: [ReportingDescriptorRecord]? = nil,
    notifications: [ReportingDescriptorRecord]? = nil,
    locations: [ArtifactLocationRecord]? = nil,
    globalMessageStrings: JSONDictionary<
      MessageID, MultiformatMessageStringRecord
    >? = nil,
    taxa: [ReportingDescriptorRecord]? = nil,
    supportedTaxonomies: [ToolComponentReferenceRecord]? = nil,
  ) {
    self.name = name
    self.guid = guid
    self.version = version
    self.semanticVersion = semanticVersion
    self.fullName = fullName
    self.product = product
    self.productSuite = productSuite
    self.dottedQuadFileVersion = dottedQuadFileVersion
    self.releaseDateUtc = releaseDateUtc
    self.downloadUri = downloadUri
    self.informationUri = informationUri
    self.organization = organization
    self.language = language
    self.isComprehensive = isComprehensive
    self.localizedDataSemanticVersion = localizedDataSemanticVersion
    self.minimumRequiredLocalizedDataSemanticVersion =
      minimumRequiredLocalizedDataSemanticVersion
    self.contents = contents
    self.associatedComponent = associatedComponent
    self.shortDescription = shortDescription
    self.fullDescription = fullDescription
    self.translationMetadata = translationMetadata
    self.rules = rules
    self.notifications = notifications
    self.locations = locations
    self.globalMessageStrings = globalMessageStrings
    self.taxa = taxa
    self.supportedTaxonomies = supportedTaxonomies
  }
}

/// A record representing a SARIF [toolComponentReference](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541313)
/// object, which identifies a particular `toolComponent` object.
public struct ToolComponentReferenceRecord: SARIFRecordConstraints {
  public let index: ArrayIndex?
  public let guid: UUID?
  public let name: String?

  public init(
    index: ArrayIndex? = nil,
    guid: UUID? = nil,
    name: String? = nil
  ) {
    self.index = index
    self.guid = guid
    self.name = name
  }
}

/// A record representing a SARIF [translationMetadata](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541068)
/// object, which describes a translation.
public struct TranslationMetadataRecord: SARIFRecordConstraints {
  public let name: String
  public let fullName: String?
  public let shortDescription: String?
  public let fullDescription: String?
  public let downloadUri: URL?
  public let informationUri: URL?

  public init(
    name: String,
    fullName: String? = nil,
    shortDescription: String? = nil,
    fullDescription: String? = nil,
    downloadUri: URL? = nil,
    informationUri: URL? = nil
  ) {
    self.name = name
    self.fullName = fullName
    self.shortDescription = shortDescription
    self.fullDescription = fullDescription
    self.downloadUri = downloadUri
    self.informationUri = informationUri
  }
}

/// A record representing a SARIF [reportingDescriptor](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541274)
/// object, which contains information that describes a “reporting item” generated by a tool, either a `notification` or a `result`.
public struct ReportingDescriptorRecord: SARIFRecordConstraints {
  public let id: String
  public let name: String?
  public let guid: UUID?
  public let helpUri: URL?
  public let shortDescription: MultiformatMessageStringRecord?
  public let fullDescription: MultiformatMessageStringRecord?
  public let help: MultiformatMessageStringRecord?
  public let defaultConfiguration: ReportingConfigurationRecord?
  public let messageStrings:
    JSONDictionary<MessageID, MultiformatMessageStringRecord>?
  public let deprecatedIds: [String]?
  public let deprecatedNames: [String]?
  public let deprecatedGuids: [UUID]?
  public let relationships: [ReportingDescriptorRelationshipRecord]?

  public init(
    id: String,
    name: String? = nil,
    guid: UUID? = nil,
    helpUri: URL? = nil,
    shortDescription: MultiformatMessageStringRecord? = nil,
    fullDescription: MultiformatMessageStringRecord? = nil,
    help: MultiformatMessageStringRecord? = nil,
    defaultConfiguration: ReportingConfigurationRecord? = nil,
    messageStrings: JSONDictionary<MessageID, MultiformatMessageStringRecord>? =
      nil,
    deprecatedIds: [String]? = nil,
    deprecatedNames: [String]? = nil,
    deprecatedGuids: [UUID]? = nil,
    relationships: [ReportingDescriptorRelationshipRecord]? = nil
  ) {
    self.id = id
    self.name = name
    self.guid = guid
    self.helpUri = helpUri
    self.shortDescription = shortDescription
    self.fullDescription = fullDescription
    self.help = help
    self.defaultConfiguration = defaultConfiguration
    self.messageStrings = messageStrings
    self.deprecatedIds = deprecatedIds
    self.deprecatedNames = deprecatedNames
    self.deprecatedGuids = deprecatedGuids
    self.relationships = relationships
  }
}

/// A record representing a SARIF [reportingDescriptorRelationship](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541308)
/// object, which specifies one or more directed relationships from one `reportingDescriptor` object to another one.
public struct ReportingDescriptorRelationshipRecord: SARIFRecordConstraints {
  public let target: ReportingDescriptorReferenceRecord
  public let kinds: [String]?
  public let description: MessageRecord?

  public init(
    target: ReportingDescriptorReferenceRecord,
    kinds: [String]? = nil,
    description: MessageRecord? = nil
  ) {
    self.target = target
    self.kinds = kinds
    self.description = description
  }
}

public enum AnyJSON: Hashable, SARIFRecordConstraints {
  case null
  case string(_ value: String)
  case number(_ value: Double)
  case boolean(_ value: Bool)
  case array(_ value: [AnyJSON])
  case object(_ value: JSONDictionary<String, AnyJSON>)

  public init(from decoder: any Decoder) throws {
    if let singleValueContainer = try? decoder.singleValueContainer() {
      if singleValueContainer.decodeNil() {
        self = .null
      } else if let boolean = try? singleValueContainer.decode(Bool.self) {
        self = .boolean(boolean)
      } else if let number = try? singleValueContainer.decode(Double.self) {
        self = .number(number)
      } else if let string = try? singleValueContainer.decode(String.self) {
        self = .string(string)
      } else if let object = try? singleValueContainer.decode(
        JSONDictionary<String, AnyJSON>.self)
      {
        self = .object(object)
      } else if let array = try? singleValueContainer.decode([AnyJSON].self) {
        self = .array(array)
      } else {
        throw Self.unrecognizedJSONValue(
          codingPath: singleValueContainer.codingPath)
      }
    } else {
      throw Self.unrecognizedJSONValue(codingPath: decoder.codingPath)
    }
  }

  public enum CodingKeys: CodingKey {
    case null
    case string
    case number
    case boolean
    case array
    case object
  }

  enum NullCodingKeys: CodingKey {
  }

  enum StringCodingKeys: CodingKey {
    case _0
  }

  enum NumberCodingKeys: CodingKey {
    case _0
  }

  enum BooleanCodingKeys: CodingKey {
    case _0
  }

  enum ArrayCodingKeys: CodingKey {
    case _0
  }

  enum ObjectCodingKeys: CodingKey {
    case _0
  }

  public func encode(to encoder: any Encoder) throws {
    var container = encoder.singleValueContainer()
    switch self {
    case .null:
      try container.encodeNil()
    case .string(let value):
      try container.encode(value)
    case .number(let value):
      try container.encode(value)
    case .boolean(let value):
      try container.encode(value)
    case .array(let value):
      try container.encode(value)
    case .object(let value):
      try container.encode(value)
    }
  }

  private static func unrecognizedJSONValue(codingPath: [any CodingKey])
    -> DecodingError
  {
    let context = DecodingError.Context(
      codingPath: codingPath, debugDescription: "Unrecognized JSON value")
    return DecodingError.typeMismatch(Self.self, context)
  }
}

/// A record representing a SARIF [property bag](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10540886)
/// object, which is an object containing an unordered set of properties with arbitrary names.
public typealias PropertyBagRecord = JSONDictionary<HierarchicalString, AnyJSON>

/// A record representing a SARIF [reportingConfiguration](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541290)
/// object, which contains the information in a `reportingDescriptor` that a SARIF producer can modify at runtime, before executing its scan.
public struct ReportingConfigurationRecord: SARIFRecordConstraints {
  public let enabled: Bool?
  public let level: ResultLevel?
  public let rank: Float?
  public let parameters: PropertyBagRecord?

  public init(
    enabled: Bool? = nil,
    level: ResultLevel? = nil,
    rank: Float? = nil,
    parameters: PropertyBagRecord? = nil
  ) {
    self.enabled = enabled
    self.level = level
    self.rank = rank
    self.parameters = parameters
  }
}

/// A record representing a SARIF [tool](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10540967)
/// object, which describes the analysis tool or converter that was run.
public struct ToolRecord: SARIFRecordConstraints {
  public let driver: ToolComponentRecord
  public let extensions: [ToolComponentRecord]?

  public init(
    driver: ToolComponentRecord, extensions: [ToolComponentRecord]? = nil
  ) {
    self.driver = driver
    self.extensions = extensions
  }
}

/// A record representing a SARIF [externalPropertyFileReference](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10540955)
/// object, which contains information that enables a SARIF consumer to locate the external property file that contains the value of an externalized property associated with the `run`.`
public struct ExternalPropertyFileReferenceRecord: SARIFRecordConstraints {
  public let location: ArtifactLocationRecord?
  public let guid: UUID?
  public let itemCount: Int?

  public init(
    location: ArtifactLocationRecord? = nil,
    guid: UUID? = nil,
    itemCount: Int? = nil
  ) {
    self.location = location
    self.guid = guid
    self.itemCount = itemCount
  }
}

/// A record representing a SARIF [externalPropertyFileReferences](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10540951)
/// object, which contains information that enables a SARIF consumer to locate the external property files that contain the values of all externalized properties associated with the `run`.
public struct ExternalPropertyFileReferencesRecord: SARIFRecordConstraints {
  public let addresses: [ExternalPropertyFileReferenceRecord]?
  public let artifacts: [ExternalPropertyFileReferenceRecord]?
  public let conversion: ExternalPropertyFileReferenceRecord?
  public let graphs: [ExternalPropertiesRecord]?
  public let invocations: [ExternalPropertyFileReferenceRecord]?
  public let logicalLocations: [ExternalPropertyFileReferenceRecord]?
  public let policies: [ExternalPropertyFileReferenceRecord]?
  public let externalizedProperties: ExternalPropertyFileReferenceRecord?
  public let webRequests: [ExternalPropertyFileReferenceRecord]?
  public let webResponses: [ExternalPropertyFileReferenceRecord]?
  public let results: [ExternalPropertyFileReferenceRecord]?
  public let taxonomies: [ExternalPropertyFileReferenceRecord]?
  public let threadFlowLocations: [ExternalPropertyFileReferenceRecord]?
  public let translations: [ExternalPropertyFileReferenceRecord]?
  public let driver: ExternalPropertyFileReferenceRecord?
  public let extensions: [ExternalPropertyFileReferenceRecord]?

  public init(
    addresses: [ExternalPropertyFileReferenceRecord]? = nil,
    artifacts: [ExternalPropertyFileReferenceRecord]? = nil,
    conversion: ExternalPropertyFileReferenceRecord? = nil,
    graphs: [ExternalPropertiesRecord]? = nil,
    invocations: [ExternalPropertyFileReferenceRecord]? = nil,
    logicalLocations: [ExternalPropertyFileReferenceRecord]? = nil,
    policies: [ExternalPropertyFileReferenceRecord]? = nil,
    externalizedProperties: ExternalPropertyFileReferenceRecord? = nil,
    webRequests: [ExternalPropertyFileReferenceRecord]? = nil,
    webResponses: [ExternalPropertyFileReferenceRecord]? = nil,
    results: [ExternalPropertyFileReferenceRecord]? = nil,
    taxonomies: [ExternalPropertyFileReferenceRecord]? = nil,
    threadFlowLocations: [ExternalPropertyFileReferenceRecord]? = nil,
    translations: [ExternalPropertyFileReferenceRecord]? = nil,
    driver: ExternalPropertyFileReferenceRecord? = nil,
    extensions: [ExternalPropertyFileReferenceRecord]? = nil
  ) {
    self.addresses = addresses
    self.artifacts = artifacts
    self.conversion = conversion
    self.graphs = graphs
    self.invocations = invocations
    self.logicalLocations = logicalLocations
    self.policies = policies
    self.externalizedProperties = externalizedProperties
    self.webRequests = webRequests
    self.webResponses = webResponses
    self.results = results
    self.taxonomies = taxonomies
    self.threadFlowLocations = threadFlowLocations
    self.translations = translations
    self.driver = driver
    self.extensions = extensions
  }
}

/// A record representing a SARIF [runAutomationDetails](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10540961)
/// object, which contains information that specifies the `run`'s identity and role within an engineering system.
public struct RunAutomationDetailsRecord: SARIFRecordConstraints {
  public let description: MessageRecord?
  public let id: HierarchicalString?
  public let guid: UUID?
  public let correlationGuid: UUID?

  public init(
    description: MessageRecord? = nil,
    id: HierarchicalString? = nil,
    guid: UUID? = nil,
    correlationGuid: UUID? = nil
  ) {
    self.description = description
    self.id = id
    self.guid = guid
    self.correlationGuid = correlationGuid
  }
}

/// A record representing a SARIF [externalProperties](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10541351)
/// object, which is the top-level element of an external property file.
public struct ExternalPropertiesRecord: SARIFRecordConstraints {
  public enum CodingKeys: String, CodingKey {
    case schema = "$schema"
    case version
    case guid
    case runGuid
    case artifacts
    case addresses
    case conversion
    case graphs
    case invocations
    case logicalLocations
    case policies
    case externalizedProperties
    case webRequests
    case webResponses
    case results
    case taxonomies
    case threadFlowLocations
    case translations
    case driver
    case extensions
  }

  public let schema: URL?
  public let version: SARIFVersion?
  public let guid: UUID?
  public let runGuid: UUID?

  // Externalized properties from `RunRecord`

  public let artifacts: [ArtifactRecord]?
  public let addresses: [AddressRecord]?
  public let conversion: ConversionRecord?
  public let graphs: [GraphRecord]?
  public let invocations: [InvocationRecord]?
  public let logicalLocations: [LogicalLocationRecord]?
  public let policies: [ToolComponentRecord]?
  public let externalizedProperties: JSONDictionary<String, String>?
  public let webRequests: [WebRequestRecord]?
  public let webResponses: [WebResponseRecord]?
  public let results: [ResultRecord]?
  public let taxonomies: [ToolComponentRecord]?
  public let threadFlowLocations: [ThreadFlowLocationRecord]?
  public let translations: [ToolComponentRecord]?

  // Externalized properties from `ToolRecord`

  public let driver: ToolComponentRecord?
  public let extensions: [ToolComponentRecord]?

  public init(
    schema: URL? = nil,
    version: SARIFVersion? = nil,
    guid: UUID? = nil,
    runGuid: UUID? = nil,
    artifacts: [ArtifactRecord]? = nil,
    addresses: [AddressRecord]? = nil,
    conversion: ConversionRecord? = nil,
    graphs: [GraphRecord]? = nil,
    invocations: [InvocationRecord]? = nil,
    logicalLocations: [LogicalLocationRecord]? = nil,
    policies: [ToolComponentRecord]? = nil,
    externalizedProperties: JSONDictionary<String, String>? = nil,
    webRequests: [WebRequestRecord]? = nil,
    webResponses: [WebResponseRecord]? = nil,
    results: [ResultRecord]? = nil,
    taxonomies: [ToolComponentRecord]? = nil,
    threadFlowLocations: [ThreadFlowLocationRecord]? = nil,
    translations: [ToolComponentRecord]? = nil,
    driver: ToolComponentRecord? = nil,
    extensions: [ToolComponentRecord]? = nil
  ) {
    self.schema = schema
    self.version = version
    self.guid = guid
    self.runGuid = runGuid
    self.artifacts = artifacts
    self.addresses = addresses
    self.conversion = conversion
    self.graphs = graphs
    self.invocations = invocations
    self.logicalLocations = logicalLocations
    self.policies = policies
    self.externalizedProperties = externalizedProperties
    self.webRequests = webRequests
    self.webResponses = webResponses
    self.results = results
    self.taxonomies = taxonomies
    self.threadFlowLocations = threadFlowLocations
    self.translations = translations
    self.driver = driver
    self.extensions = extensions
  }
}

/// A record representing a SARIF [multiformatMessageString](https://docs.oasis-open.org/sarif/sarif/v2.1.0/csprd01/sarif-v2.1.0-csprd01.html#_Toc10540911)
/// object, which groups together all available textual formats for a message string.
public struct MultiformatMessageStringRecord: SARIFRecordConstraints {
  public let text: String
  public let markdown: String?

  public init(text: String, markdown: String? = nil) {
    self.text = text
    self.markdown = markdown
  }
}
