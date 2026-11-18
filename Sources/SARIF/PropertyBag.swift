import Foundation
fileprivate import ImmutableJSON
public import SARIFRecords

public typealias PropertyBag = JSONDictionary<HierarchicalString, AnyProperty>

extension PropertyBag {
  internal init(from record: PropertyBagRecord, providers: PropertyProviders)
    throws
  {
    self.init()
    try record.forEach { key, recordValue in
      let value = try AnyProperty(
        key: key, value: recordValue, providers: providers)
      self[key] = value
    }
  }
}

extension PropertyBag {
  public subscript<Value>(_ key: PropertyKey<Value>) -> Value? {
    get {
      guard let anyValue = self[key.key] else {
        return nil
      }

      let value = anyValue.value as! Value
      return value
    }
    set {
      self[key.key] = newValue.map { value in
        AnyProperty(value, provider: key.provider)
      }
    }
  }
}

public protocol PropertyKeyProtocol: Sendable {
  associatedtype Value

  var key: HierarchicalString { get }
  var provider: any PropertyProvider<Value>.Type { get }
}

public struct PropertyKey<Value>: PropertyKeyProtocol {
  public let key: HierarchicalString
  public let provider: any PropertyProvider<Value>.Type

  public init(_ key: HierarchicalString) where Value: Codable {
    self.init(key, provider: CodablePropertyProvider<Value>.self)
  }

  public init(
    _ key: HierarchicalString, provider: any PropertyProvider<Value>.Type
  ) {
    self.key = key
    self.provider = provider
  }
}

private struct CodablePropertyProvider<Value: Codable>: PropertyProvider<Value>
{
}

public protocol PropertyProvider<Value>: SendableMetatype {
  associatedtype Value

  static func encode(_ value: Value, to encoder: any Encoder) throws

  static func decode(from decoder: any Decoder) throws -> Value
}

extension PropertyProvider where Value: Decodable {
  public static func decode(from decoder: any Decoder) throws -> Value {
    try .init(from: decoder)
  }
}

extension PropertyProvider where Value: Encodable {
  public static func encode(_ value: Value, to encoder: any Encoder) throws {
    try value.encode(to: encoder)
  }
}

private protocol PropertyWrapperProtocol: JSONRepresentable<AnyJSON> {
  associatedtype Value

  var value: Value { get }

  func toJSON() throws -> AnyJSON
}

private struct PropertyWrapper<Provider: PropertyProvider>:
  PropertyWrapperProtocol, Codable
{
  let value: Provider.Value

  init(value: Provider.Value) {
    self.value = value
  }

  init(from decoder: any Decoder) throws {
    self.value = try Provider.decode(from: decoder)
  }

  func encode(to encoder: any Encoder) throws {
    try Provider.encode(self.value, to: encoder)
  }

  func toJSON() throws -> AnyJSON {
    let data = try ImmutableJSONEncoder.compact.encode(self)
    return try AnyJSON.fromJSONData(data)
  }
}

extension AnyJSON: PropertyWrapperProtocol {
  var value: AnyJSON { self }
}

extension PropertyProvider {
  fileprivate static func decodeWrapped(from json: AnyJSON) throws
    -> some PropertyWrapperProtocol
  {
    let data = try json.toJSONData()
    return try PropertyWrapper<Self>.fromJSONData(data)
  }
}

public struct PropertyProviders: ExpressibleByArrayLiteral, Sendable {
  private let providersByKey: [HierarchicalString: any PropertyProvider.Type]

  public init(arrayLiteral keys: (any PropertyKeyProtocol)...) {
    var providersByKey: [HierarchicalString: any PropertyProvider.Type] = [:]
    keys.forEach { key in
      if !providersByKey.keys.contains(key.key) {
        providersByKey[key.key] = key.provider
      }
    }

    self.providersByKey = providersByKey
  }

  fileprivate subscript(_ key: HierarchicalString) -> (
    any PropertyProvider.Type
  )? {
    self.providersByKey[key]
  }
}

public struct AnyProperty: JSONRepresentable<AnyJSON> {
  private let wrapper: any PropertyWrapperProtocol
  public var value: Any { self.wrapper.value }

  public init<Provider: PropertyProvider>(
    _ value: Provider.Value, provider: Provider.Type
  ) {
    self.wrapper = PropertyWrapper<Provider>(value: value)
  }

  public init(string: String) {
    self.wrapper = AnyJSON.string(string)
  }

  internal init(
    key: HierarchicalString, value: AnyJSON, providers: PropertyProviders
  ) throws {
    if let provider = providers[key] {
      self.wrapper = try provider.decodeWrapped(from: value)
    } else {
      self.wrapper = value
    }
  }

  public func toJSON() throws -> AnyJSON {
    try self.wrapper.toJSON()
  }
}
