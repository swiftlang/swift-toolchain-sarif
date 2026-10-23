public import SARIFRecords

public struct TextRegion: Hashable, Comparable, SpaceshipComparable {
  internal init?(from regionRecord: RegionRecord, sink: any ValidationSink)
    throws
  {
    @Validating(sink: sink) var record = regionRecord

    if let startLine = record.startLine {
      // TODO: Reject malformed regions
      self.init(
        startLine: startLine, startColumn: record.startColumn ?? 1,
        endLine: record.endLine ?? startLine, endColumn: record.endColumn)
    } else {
      for key in [\RegionRecord.endLine, \.startColumn, \.endColumn] {
        try $record.forbid(
          key,
          message: "'\(key)' not allowed when 'startLine' is not specified.")
      }
      return nil
    }
  }

  public init(line: Int32) {
    self.init(startLine: line)
  }

  public init(line: Int32, column: Int32) {
    self.init(
      startLine: line, startColumn: column, endLine: line, endColumn: column + 1
    )
  }

  public init(line: Int32, startColumn: Int32, endColumn: Int32) {
    self.init(
      startLine: line, startColumn: startColumn,
      endColumn: endColumn)
  }

  public init(
    startLine: Int32, startColumn: Int32? = nil, endLine: Int32? = nil,
    endColumn: Int32? = nil
  ) {
    self.startLine = startLine
    self.endLine = endLine ?? startLine
    self.startColumn = startColumn ?? 1
    self.endColumn = endColumn
  }

  public let startLine: Int32
  public let endLine: Int32
  public let startColumn: Int32
  public let endColumn: Int32?

  public static func < (_ lhs: Self, _ rhs: Self) -> Bool {
    (lhs <=> rhs) == true
  }

  internal static func <=> (_ lhs: Self, _ rhs: Self) -> Bool? {
    // Reverse direction on end positions.
    (lhs.startLine <=> rhs.startLine) ?? (lhs.startColumn <=> rhs.startColumn)
      ?? (rhs.endLine <=> lhs.endLine) ?? (rhs.endColumn <=> lhs.endColumn)
  }
}

public struct TextOffsetRegion: Hashable {
  internal init?(from regionRecord: RegionRecord, sink: any ValidationSink)
    throws
  {
    @Validating(sink: sink) var record = regionRecord
    if let charOffset = regionRecord.charOffset {
      self.init(
        charOffset: charOffset, charLength: regionRecord.charLength ?? 0)
    } else {
      try $record.forbid(
        \.charLength,
        message: "'charLength' not allowed when 'charOffset' is not specified.")
      return nil
    }
  }

  public init(charOffset: Int64, charLength: Int64 = 0) {
    self.charOffset = charOffset
    self.charLength = charLength
  }

  public let charOffset: Int64
  public let charLength: Int64
}

public struct BinaryRegion: Hashable {
  internal init?(from regionRecord: RegionRecord, sink: any ValidationSink)
    throws
  {
    @Validating(sink: sink) var record = regionRecord
    if let byteOffset = regionRecord.byteOffset {
      self.init(
        byteOffset: byteOffset, byteLength: regionRecord.byteLength ?? 0)
    } else {
      try $record.forbid(
        \.byteLength,
        message: "'byteLength' not allowed when 'charOffset' is not specified.")
      return nil
    }
  }

  public init(byteOffset: Int64, byteLength: Int64 = 0) {
    self.byteOffset = byteOffset
    self.byteLength = byteLength
  }

  public let byteOffset: Int64
  public let byteLength: Int64
}

public final class Region: JSONRepresentable<RegionRecord> {
  public struct DefaultSortKey: Comparable, SpaceshipComparable {
    private let textRegion: TextRegion?

    fileprivate init(for region: Region) {
      self.textRegion = region.textRegion
    }

    public static func < (_ lhs: Self, _ rhs: Self) -> Bool {
      (lhs <=> rhs) == true
    }

    internal static func <=> (_ lhs: Self, _ rhs: Self) -> Bool? {
      lhs.textRegion <=> rhs.textRegion
    }
  }

  public var textRegion: TextRegion?
  public var textOffsetRegion: TextOffsetRegion?
  public var binaryRegion: BinaryRegion?
  public var sourceLanguage: HierarchicalString?  // TODO: Context
  public var defaultSortKey: DefaultSortKey { .init(for: self) }

  public init(text textRegion: TextRegion? = nil) {
    self.textRegion = textRegion
  }

  internal init(from regionRecord: RegionRecord, sink: any ValidationSink)
    throws
  {
    @Validating(sink: sink) var record = regionRecord

    guard
      (record.startLine != nil) || (record.charOffset != nil)
        || (record.byteOffset != nil)
    else {
      try sink.fatalError(
        "'region' must specify at least one of 'startLine', 'charOffset', or 'byteOffset'."
      )
    }

    self.textRegion = try .init(from: record, sink: sink)
    self.textOffsetRegion = try .init(from: record, sink: sink)
    self.binaryRegion = try .init(from: record, sink: sink)
    self.sourceLanguage = record.sourceLanguage

    try $record.forbid(\.snippet, message: "'snippet' NYI.")
    try $record.forbid(\.message, message: "'message' NYI.")
  }

  internal func toJSON() throws -> RegionRecord {
    .init(
      startLine: self.textRegion?.startLine.toJSON(),
      startColumn: self.textRegion?.startColumn.toJSON(),
      endLine: self.textRegion?.endLine.toJSON(),
      endColumn: try self.textRegion?.endColumn.toJSON(),
      charOffset: self.textOffsetRegion?.charOffset.toJSON(),
      charLength: self.textOffsetRegion?.charLength.toJSON(),
      byteOffset: self.binaryRegion?.byteOffset.toJSON(),
      byteLength: self.binaryRegion?.byteLength.toJSON(),
      snippet: nil,  // FIXME
      message: nil,  // FIXME
      sourceLanguage: try self.sourceLanguage.toJSON(),
    )
  }
}
