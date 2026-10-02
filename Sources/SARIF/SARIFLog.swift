import Foundation
public import SARIFRecords

@propertyWrapper
public struct FallbackToVersionSchema {
  private var value: URL? = nil

  public init(_ value: URL? = nil) {
    self.value = value
  }

  @available(
    *, unavailable,
    message: "This property wrapper can only used as a property of SARIFLog"
  )
  public var wrappedValue: URL {
    get { fatalError() }
    set { fatalError() }
  }

  public var projectedValue: URL? {
    get { value }
    set { value = newValue }
  }

  public static subscript(_enclosingInstance owner: SARIFLog,
    wrapped wrapped: ReferenceWritableKeyPath<SARIFLog, URL>,
    storage storage: ReferenceWritableKeyPath<SARIFLog, Self>
  ) -> URL {
    get { owner[keyPath: storage].value ?? owner.version.schema }
    set { owner[keyPath: storage].value = newValue }
  }
}

public final class SARIFLog: Encodable, Decodable, DecodableWithConfiguration {
  public var version: SARIFVersion {
    willSet {
      if newValue != self.version {
        // Changing the SARIF version invalidates any explicit schema.
        self.$schema = nil
      }
    }
  }
  @FallbackToVersionSchema
  public var schema: URL
  public private(set) var runs: [Run] = []

  public init(version: SARIFVersion = .v2_1_0) {
    self.version = version
  }

  public convenience init(from decoder: any Decoder) throws {
    try self.init(from: decoder, configuration: ThrowingValidationSink())
  }

  public convenience init(
    from decoder: any Decoder, configuration sink: any ValidationSink
  ) throws {
    let container = try decoder.singleValueContainer()
    try self.init(from: try container.decode(SARIFLogRecord.self), sink: sink)
  }

  public convenience init(
    from data: Data, propertyProviders: PropertyProviders = [],
    sink: any ValidationSink = ThrowingValidationSink()
  ) throws {
    let logRecord = try SARIFLogRecord.fromJSONData(data)
    try self.init(
      from: logRecord, propertyProviders: propertyProviders, sink: sink)
  }

  public init(
    from logRecord: SARIFLogRecord, propertyProviders: PropertyProviders = [],
    sink: any ValidationSink = ThrowingValidationSink()
  ) throws {
    guard let version = SARIFVersion(rawValue: logRecord.version) else {
      try sink.fatalError("Unsupported SARIF version: '\(logRecord.version)'.")
    }
    self.version = version
    self.$schema = logRecord.schema  // Assume the specified schema is valid for the specified version.

    for runRecord in logRecord.runs ?? [] {
      let run = try Run(
        from: runRecord, propertyProviders: propertyProviders, sink: sink)
      self.runs.append(run)
    }
  }

  public func canonicalize(
    sortingInvocationsBy: (_ lhs: Invocation, _ rhs: Invocation) -> Bool = {
      _, _ in false
    }
  ) {
    self.runs.sort { lhs, rhs in
      (lhs.tool.driver.name <=> rhs.tool.driver.name)
        ?? (lhs.tool.driver.version <=> rhs.tool.driver.version) ?? false
    }

    self.runs.forEach { run in
      run.canonicalize(sortingInvocationsBy: sortingInvocationsBy)
    }
  }

  @discardableResult
  public func addRun(tool: Tool) -> Run {
    let run = Run(tool: tool)
    runs.append(run)
    return run
  }

  public func toJSON() throws -> SARIFLogRecord {
    let sarifLog = SARIFLogRecord(
      version: self.version.rawValue,
      schema: self.schema,
      runs: try self.runs.map { run in
        try run.toJSON()
      },
      inlineExternalProperties: nil)
    return sarifLog
  }

  public func encode(to encoder: any Encoder) throws {
    try toJSON().encode(to: encoder)
  }
}
