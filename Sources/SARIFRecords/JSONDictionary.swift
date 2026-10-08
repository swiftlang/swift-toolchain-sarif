import OrderedCollections

private struct JSONCodingKey: CodingKey {
  init(stringValue: String) {
    self.stringValue = stringValue
  }

  init?(intValue: Int) {
    return nil
  }

  public let stringValue: String
  public var intValue: Int? { nil }
}

/// A JSON object with arbitrary string keys mapped to any Codable value.
/// This dictionary preserves insertion order to enable round-tripping, but its implementation of
/// Equatable ignores differences in key order.
public struct JSONDictionary<K: Hashable & Codable, V>: Sequence,
  ExpressibleByDictionaryLiteral
{
  public typealias DictionaryType = OrderedDictionary<K, V>
  public typealias Iterator = DictionaryType.Iterator
  public typealias Values = DictionaryType.Values

  private var dictionary: DictionaryType

  public var isEmpty: Bool { self.dictionary.isEmpty }
  public var keys: OrderedSet<K> { self.dictionary.keys }
  public var values: Values { self.dictionary.values }
  public var count: Int { self.dictionary.count }

  public var ifNotEmpty: Self? {
    if self.isEmpty {
      nil
    } else {
      self
    }
  }

  public init() {
    self.dictionary = [:]
  }

  public init(dictionaryLiteral elements: (K, V)...) {
    self.dictionary = .init(uniqueKeysWithValues: elements)
  }

  public init(uniqueKeysWithValues: some Sequence<(K, V)>) {
    self.dictionary = .init(uniqueKeysWithValues: uniqueKeysWithValues)
  }

  public init(from dictionary: OrderedDictionary<K, V>) {
    self.dictionary = dictionary
  }

  public func mapValues<T>(
    _ transform: (V) throws -> T
  ) rethrows -> JSONDictionary<K, T> {
    let orderedDictionary: OrderedDictionary<K, T> = try self.dictionary
      .mapValues(transform)
    return .init(from: orderedDictionary)
  }

  public func compactMapValues<T>(_ transform: (V) throws -> T?) rethrows
    -> JSONDictionary<K, T>
  {
    let orderedDictionary: OrderedDictionary<K, T> = try self.dictionary
      .compactMapValues(transform)
    return .init(from: orderedDictionary)
  }

  public mutating func updateValue(_ value: V, forKey key: K) -> V? {
    self.dictionary.updateValue(value, forKey: key)
  }

  public mutating func updateValue<R>(
    forKey key: K, default defaultValue: @autoclosure () -> V,
    with: (_ value: inout V) throws -> R
  ) rethrows -> R {
    try self.dictionary.updateValue(
      forKey: key, default: defaultValue(), with: with)
  }

  public mutating func removeAll() {
    self.dictionary.removeAll()
  }

  public var orderedDictionary: OrderedDictionary<K, V> {
    self.dictionary
  }

  public subscript(_ key: K) -> V? {
    get { dictionary[key] }
    set { dictionary[key] = newValue }
  }

  public subscript(_ key: K, default defaultValue: @autoclosure () -> V) -> V {
    get { self.dictionary[key, default: defaultValue()] }
    set { self.dictionary[key, default: defaultValue()] = newValue }
  }

  public func filter(_ isIncluded: (_ element: Element) throws -> Bool) rethrows
    -> Self
  {
    .init(from: try self.dictionary.filter(isIncluded))
  }

  public func makeIterator() -> Iterator {
    self.dictionary.makeIterator()
  }
}

extension JSONDictionary: Decodable where V: Decodable {
  public init(from decoder: any Decoder) throws {
    var dictionary: OrderedDictionary<K, V> = [:]
    let container = try decoder.container(keyedBy: JSONCodingKey.self)
    for codingKey in container.allKeys {
      let keyDecoder = KeyDecoder(
        forKey: codingKey, in: container, userInfo: decoder.userInfo)
      let key = try K(from: keyDecoder)
      dictionary[key] = try container.decode(V.self, forKey: codingKey)
    }
    self.dictionary = dictionary
  }
}

extension JSONDictionary: Encodable where V: Encodable {
  public func encode(to encoder: any Encoder) throws {
    var container = encoder.container(keyedBy: JSONCodingKey.self)
    for (key, value) in dictionary {
      let keyEncoder = KeyEncoder(in: container, userInfo: encoder.userInfo)
      try key.encode(to: keyEncoder)
      let codingKey = keyEncoder.key!
      try container.encode(value, forKey: codingKey)
    }
  }
}

extension JSONDictionary: Equatable where V: Equatable {
  public static func == (lhs: Self, rhs: Self) -> Bool {
    // Unordered comparison, similar to regular `Dictionary`.
    if lhs.dictionary.count != rhs.dictionary.count {
      return false
    }

    for (lhsKey, lhsValue) in lhs.dictionary {
      let rhsValue = rhs.dictionary[lhsKey]
      guard let rhsValue, lhsValue == rhsValue else {
        return false
      }
    }

    return true
  }
}

extension JSONDictionary: Hashable where V: Hashable {
  public func hash(into hasher: inout Hasher) {
    // Taken from https://github.com/swiftlang/swift/blob/9511b90c17db185a462c7ca33be72267a44cacb1/stdlib/public/core/Dictionary.swift#L1781
    var commutativeHash = 0
    for (k, v) in self {
      // Note that we use a copy of our own hasher here. This makes hash values
      // dependent on its state, eliminating static collision patterns.
      var elementHasher = hasher
      elementHasher.combine(k)
      elementHasher.combine(v)
      commutativeHash ^= elementHasher.finalize()
    }
    hasher.combine(commutativeHash)
  }
}

extension JSONDictionary: Sendable where K: Sendable, V: Sendable {
}
