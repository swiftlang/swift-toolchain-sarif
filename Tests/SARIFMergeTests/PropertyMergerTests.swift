import OrderedCollections
import SARIF
import Testing

@testable import SARIFMerge

internal final class Holder<T> {
  var value: T

  init(_ value: T) {
    self.value = value
  }
}

/// A reference type with identity-based equality, for testing the reference-keeping merge operations.
internal final class Reference: Equatable {
  static func == (lhs: Reference, rhs: Reference) -> Bool {
    lhs === rhs
  }
}

internal func testPropertyMerger<Value: Equatable>(
  inputs: [Value], expectedOutput: Value, defaultValue: Value,
  merge: (_ merger: inout PropertyMerger<Holder<Value>>) throws -> Void
) throws {
  let sink = ThrowingValidationSink()

  let outputHolder = Holder(defaultValue)
  var first = true
  for input in inputs {
    try PropertyMerger.merge(
      from: Holder(input), into: outputHolder, first: first, sink: sink
    ) { merger in
      try merge(&merger)
    }
    first = false
  }

  #expect(outputHolder.value == expectedOutput)
}

@Test
func keepFirst() throws {
  try testPropertyMerger(inputs: [1, 2, 3], expectedOutput: 1, defaultValue: 0)
  {
    merger in
    try merger.keepFirst(keys: \.value)
  }
}

@Test
func keepFirstSingleInput() throws {
  try testPropertyMerger(inputs: [7], expectedOutput: 7, defaultValue: 0) {
    merger in
    try merger.keepFirst(keys: \.value)
  }
}

@Test
func keepFirstSpecifiedSkipsLeadingNil() throws {
  try testPropertyMerger(
    inputs: [nil, 2, 3], expectedOutput: 2, defaultValue: Int?.none
  ) { merger in
    try merger.keepFirstSpecified(keys: \.value)
  }
}

@Test
func keepFirstSpecifiedAllNil() throws {
  try testPropertyMerger(
    inputs: [Int?.none, nil], expectedOutput: nil, defaultValue: Int?.none
  ) { merger in
    try merger.keepFirstSpecified(keys: \.value)
  }
}

@Test
func assertEqualSucceeds() throws {
  try testPropertyMerger(inputs: [5, 5, 5], expectedOutput: 5, defaultValue: 0)
  {
    merger in
    try merger.assertEqual(keys: \.value)
  }
}

@Test
func assertEqualFailsOnMismatch() {
  #expect(throws: (any Error).self) {
    try testPropertyMerger(
      inputs: [5, 5, 6], expectedOutput: 5, defaultValue: 0
    ) {
      merger in
      try merger.assertEqual(keys: \.value)
    }
  }
}

@Test
func assertEqualOrNilIgnoresNil() throws {
  try testPropertyMerger(
    inputs: [nil, 4, nil, 4], expectedOutput: 4, defaultValue: Int?.none
  ) { merger in
    try merger.assertEqualOrNil(keys: \.value)
  }
}

@Test
func assertEqualOrNilAllNil() throws {
  try testPropertyMerger(
    inputs: [Int?.none, nil], expectedOutput: nil, defaultValue: Int?.none
  ) { merger in
    try merger.assertEqualOrNil(keys: \.value)
  }
}

@Test
func assertEqualOrNilFailsOnMismatch() {
  #expect(throws: (any Error).self) {
    try testPropertyMerger(
      inputs: [1, nil, 2], expectedOutput: 1, defaultValue: Int?.none
    ) { merger in
      try merger.assertEqualOrNil(keys: \.value)
    }
  }
}

@Test
func expectEqualMatchingValues() throws {
  try testPropertyMerger(
    inputs: ["a", "a"], expectedOutput: "a", defaultValue: ""
  ) {
    merger in
    try merger.expectEqual(keys: \.value)
  }
}

@Test
func expectEqualMismatchReportsToSink() {
  // `ThrowingValidationSink` treats recoverable errors as fatal, so a mismatch throws.
  #expect(throws: (any Error).self) {
    try testPropertyMerger(
      inputs: ["a", "b"], expectedOutput: "a", defaultValue: ""
    ) {
      merger in
      try merger.expectEqual(keys: \.value)
    }
  }
}

@Test
func assertNilSucceedsWhenNil() throws {
  try testPropertyMerger(
    inputs: [Int?.none, nil], expectedOutput: nil, defaultValue: Int?.none
  ) { merger in
    try merger.assertNil(keys: \.value)
  }
}

@Test
func assertNilFailsWhenNonNil() {
  #expect(throws: (any Error).self) {
    try testPropertyMerger(
      inputs: [nil, 3], expectedOutput: nil, defaultValue: Int?.none
    ) { merger in
      try merger.assertNil(keys: \.value)
    }
  }
}

@Test
func concatenateAppendsInOrder() throws {
  try testPropertyMerger(
    inputs: [[1, 2], [], [3]], expectedOutput: [1, 2, 3], defaultValue: [Int]()
  ) { merger in
    try merger.concatenate(key: \.value)
  }
}

@Test
func unionDeduplicatesPreservingOrder() throws {
  try testPropertyMerger(
    inputs: [OrderedSet([1, 2]), OrderedSet([2, 3]), OrderedSet([4, 1])],
    expectedOutput: OrderedSet([1, 2, 3, 4]),
    defaultValue: OrderedSet<Int>()
  ) { merger in
    try merger.union(keys: \.value)
  }
}

@Test
func ignoreHasNoEffect() throws {
  try testPropertyMerger(inputs: [1, 2], expectedOutput: 0, defaultValue: 0) {
    merger in
    try merger.ignore(keys: \.value)
  }
}

@Test
func keepFirstReferenceKeepsFirstOnly() throws {
  let r1 = Reference()
  try testPropertyMerger(
    inputs: [r1, Reference()], expectedOutput: r1, defaultValue: Reference()
  ) { merger in
    try merger.keepFirstReference(key: \.value) { $0 }
  }
}

@Test
func keepFirstReferenceAppliesResolve() throws {
  let resolved = Reference()
  try testPropertyMerger(
    inputs: [Reference()], expectedOutput: resolved, defaultValue: Reference()
  ) { merger in
    try merger.keepFirstReference(key: \.value) { _ in resolved }
  }
}

@Test
func keepFirstOptionalReferenceKeepsFirst() throws {
  let r1 = Reference()
  try testPropertyMerger(
    inputs: [r1, Reference()], expectedOutput: r1, defaultValue: Reference?.none
  ) { merger in
    try merger.keepFirstReference(key: \.value) { $0 }
  }
}

@Test
func keepFirstOptionalReferenceNilFirst() throws {
  try testPropertyMerger(
    inputs: [nil, Reference()], expectedOutput: nil,
    defaultValue: Reference?.none
  ) { merger in
    try merger.keepFirstReference(key: \.value) { $0 }
  }
}

@Test
func keepFirstReferencesKeepsFirstArray() throws {
  let r1 = Reference()
  let r2 = Reference()
  try testPropertyMerger(
    inputs: [[r1, r2], [Reference()]], expectedOutput: [r1, r2],
    defaultValue: [Reference]()
  ) { merger in
    try merger.keepFirstReferences(key: \.value) { $0 }
  }
}
