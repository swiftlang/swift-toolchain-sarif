public import Foundation

extension JSONEncoder.OutputFormatting {
  public static let pretty: JSONEncoder.OutputFormatting = [
    .sortedKeys, .prettyPrinted, .withoutEscapingSlashes,
  ]
  public static let compact: JSONEncoder.OutputFormatting = [
    .sortedKeys, .withoutEscapingSlashes,
  ]
}

private struct EncodingWrapper<Value>: EncodableWithConfiguration {
  let value: Value

  func encode(
    to encoder: any Encoder,
    configuration encode: (_ value: Value, _ encoder: any Encoder) throws ->
      Void
  ) throws {
    try encode(self.value, encoder)
  }
}

private struct DecodingWrapper<Value>: DecodableWithConfiguration {
  let value: Value

  init(
    from decoder: any Decoder,
    configuration decode: (_ decoder: any Decoder) throws -> Value
  )
    throws
  {
    self.value = try decode(decoder)
  }
}

public struct ImmutableJSONEncoder: Sendable {
  private let encoder: JSONEncoder

  public static let pretty = ImmutableJSONEncoder(formatting: .pretty)

  public static let compact = ImmutableJSONEncoder(formatting: .compact)

  public static let defaultDateEncodingStrategy = JSONEncoder
    .DateEncodingStrategy.iso8601

  public init(
    formatting: JSONEncoder.OutputFormatting? = nil,
    dateEncoding: JSONEncoder.DateEncodingStrategy? = nil
  ) {
    self.encoder = JSONEncoder()
    self.encoder.outputFormatting = formatting ?? .pretty
    self.encoder.dateEncodingStrategy =
      dateEncoding ?? Self.defaultDateEncodingStrategy
  }

  public func encode(_ value: some Encodable) throws -> Data {
    try self.encoder.encode(value)
  }

  @available(macOS 14, *)
  public func encode<Value: EncodableWithConfiguration>(
    _ value: Value, configuration: Value.EncodingConfiguration
  ) throws -> Data {
    try self.encoder.encode(value, configuration: configuration)
  }
}

public struct ImmutableJSONDecoder: Sendable {
  private let decoder: JSONDecoder

  public static let shared = ImmutableJSONDecoder()
  public static let json5 = ImmutableJSONDecoder(allowsJSON5: true)

  public static let defaultDateDecodingStrategy = JSONDecoder
    .DateDecodingStrategy.iso8601

  public init(
    dateDecoding: JSONDecoder.DateDecodingStrategy? = nil,
    allowsJSON5: Bool? = nil
  ) {
    self.decoder = Self.makeDecoder(
      dateDecoding: dateDecoding, allowsJSON5: allowsJSON5)
  }

  public func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T
  {
    try self.decoder.decode(type, from: data)
  }

  @available(macOS 14, *)
  public func decode<T: DecodableWithConfiguration>(
    _ type: T.Type, from data: Data, configuration: T.DecodingConfiguration
  ) throws -> T {
    try self.decoder.decode(type, from: data, configuration: configuration)
  }

  public func makeDecoder() -> JSONDecoder {
    Self.makeDecoder(
      dateDecoding: self.decoder.dateDecodingStrategy,
      allowsJSON5: self.decoder.allowsJSON5)
  }

  private static func makeDecoder(
    dateDecoding: JSONDecoder.DateDecodingStrategy?,
    allowsJSON5: Bool?
  ) -> JSONDecoder {
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy =
      dateDecoding ?? Self.defaultDateDecodingStrategy
    if let allowsJSON5 {
      decoder.allowsJSON5 = allowsJSON5
    }
    return decoder
  }
}

extension Encodable {
  public func toJSONData(formatting: JSONEncoder.OutputFormatting? = nil) throws
    -> Data
  {
    let encoder = ImmutableJSONEncoder(formatting: formatting)

    return try encoder.encode(self)
  }

  public func toJSONString(formatting: JSONEncoder.OutputFormatting? = nil)
    throws -> String
  {
    String(data: try toJSONData(formatting: formatting), encoding: .utf8)!
  }
}

extension Decodable {
  public static func fromJSONString(_ string: String) throws -> Self {
    try fromJSONData(string.data(using: .utf8)!)
  }

  public static func fromJSON5String(_ string: String) throws -> Self {
    try fromJSON5Data(string.data(using: .utf8)!)
  }

  public static func fromJSONData(_ data: Data) throws -> Self {
    try ImmutableJSONDecoder.shared.decode(Self.self, from: data)
  }

  public static func fromJSON5Data(_ data: Data) throws -> Self {
    try ImmutableJSONDecoder.json5.decode(Self.self, from: data)
  }
}

extension DecodableWithConfiguration {
  @available(macOS 14, *)
  public static func fromJSONData(
    _ data: Data, configuration: DecodingConfiguration
  ) throws -> Self {
    try ImmutableJSONDecoder.shared.decode(
      Self.self, from: data, configuration: configuration)
  }
}
