import SARIF
import Testing

@testable import SARIFMerge

struct Pair: Mergeable, Equatable {
  typealias Context = Void

  struct MergeState: MergeStateProtocol<Pair> {
    mutating func merge(merger: inout PropertyMerger<Pair>) throws {
      try merger.assertEqual(keys: \.key)
      try merger.keepFirstSpecified(keys: \.value)
    }
  }

  struct MergeKey: MergeKeyProtocol<Pair> {
    let key: String

    init(for object: Pair, with context: Void) throws {
      self.key = object.key
    }
  }

  var key: String
  var value: Int?

  init(_ key: String, _ value: Int?) {
    self.key = key
    self.value = value
  }
}

func testArrayMerger<Value: Mergeable & Equatable>(
  inputs: [[Value]], expectedOutput: [Value]
) throws where Value.Context == Void {
  var arrayMerger = ArrayMerger<Value, Holder<[Value]>>()

  try testPropertyMerger(
    inputs: inputs, expectedOutput: expectedOutput, defaultValue: []
  ) { merger in
    try arrayMerger.merge(key: \.value, merger: &merger) { firstInput in
      firstInput
    }
  }
}

@Test
func mergeArray() throws {
  let inputs: [[Pair]] = [
    [.init("a", nil), .init("b", nil), .init("c", 3)],
    [.init("b", 2), .init("a", nil), .init("d", 4)],
    [],
    [.init("b", nil), .init("d", 4), .init("b", nil)],
  ]
  let output: [Pair] = [
    .init("a", nil), .init("b", 2), .init("c", 3), .init("d", 4),
  ]

  try testArrayMerger(inputs: inputs, expectedOutput: output)
}
