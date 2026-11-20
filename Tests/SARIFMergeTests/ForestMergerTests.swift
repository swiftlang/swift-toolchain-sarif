import OrderedCollections
import SARIF
import Testing

@testable import SARIFMerge

final class ForestNode: MergeableWithIdentity, Hashable, Identifiable,
  CustomStringConvertible
{
  typealias Context = ReferenceMergeMap<ForestNode>

  struct MergeKey: MergeKeyProtocol {
    let name: String

    init(for object: ForestNode, with context: Context) throws {
      self.name = object.name
    }
  }

  struct MergeState: MergeStateProtocolWithContext<ForestNode> {
    mutating func merge(
      merger: inout PropertyMerger<ForestNode>,
      with context: ReferenceMergeMap<ForestNode>
    ) throws {
      try merger.assertEqual(keys: \ForestNode.name)
      try merger.keepFirstSpecified(keys: \.value)
      try merger.keepFirstReference(key: \.parent, resolve: context.resolve)
    }
  }

  var name: String
  var value: Int?
  var parent: ForestNode?

  var description: String {
    "\(self.name) = \(self.value.map(String.init(describing:)) ?? "nil")\(parent.map({ " in \($0.name)" }) ?? "")"
  }

  init(_ name: String, _ value: Int? = nil, in parent: ForestNode? = nil) {
    self.name = name
    self.value = value
    self.parent = parent
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(self.id)
  }

  static func == (_ lhs: ForestNode, _ rhs: ForestNode) -> Bool {
    (lhs.name == rhs.name) && (lhs.value == rhs.value)
      && (lhs.parent == rhs.parent)
  }
}

struct NodeForest: Forest {
  typealias Element = ForestNode
  typealias CollectionType = OrderedSet<ForestNode>

  let elements: OrderedSet<ForestNode>

  func reportCycle(_ chain: [Int]) throws -> Never {
    preconditionFailure()
  }

  func getParentIndex(ofIndex index: Int) throws -> Int? {
    guard let parent = self.elements[index].parent else {
      return nil
    }

    return self.elements.firstIndex(of: parent)!
  }
}

func testForestMerger<ForestType: Forest>(
  inputs: [ForestType.CollectionType],
  expectedOutput: ForestType.CollectionType,
  makeForest: (_ elements: ForestType.CollectionType) -> ForestType,
  makeOutput: (
    _ firstInput: ForestType.Element, _ parentOutput: ForestType.Element?
  ) -> ForestType.Element
) throws
where
  ForestType.Element: MergeableWithIdentity, ForestType.Element: Equatable,
  ForestType.CollectionType: MergeableSequence,
  ForestType.CollectionType: Equatable,
  ForestType.Element.Context == ReferenceMergeMap<ForestType.Element>
{
  var forestMerger = ForestMerger<
    ForestType, Holder<ForestType.CollectionType>
  >()

  let references = ReferenceMergeMap<ForestType.Element>()

  try testPropertyMerger(
    inputs: inputs, expectedOutput: expectedOutput,
    defaultValue: ForestType.CollectionType()
  ) { merger in
    try forestMerger.merge(
      key: \.value, merger: &merger, with: references,
      recordReference: references.addDefinition, makeForest: makeForest,
      makeOutput: makeOutput)
  }
}

func testForestMerger(
  inputs: [OrderedSet<ForestNode>],
  expectedOutput: OrderedSet<ForestNode>
) throws {
  try testForestMerger(
    inputs: inputs, expectedOutput: expectedOutput, makeForest: NodeForest.init
  ) { firstInput, parentOutput in
    ForestNode(firstInput.name, in: parentOutput)
  }
}

@Test
func mergeForest() throws {
  var inputs: [OrderedSet<ForestNode>] = []
  do {
    let a = ForestNode("a", 0)
    let b = ForestNode("b", 1)
    let ac = ForestNode("ac", 2, in: a)
    inputs.append([a, b, ac])
  }

  let expectedOutput: OrderedSet<ForestNode>
  do {
    let a = ForestNode("a", 0)
    let b = ForestNode("b", 1)
    let ac = ForestNode("ac", 2, in: a)

    expectedOutput = [a, b, ac]
  }

  try testForestMerger(inputs: inputs, expectedOutput: expectedOutput)
}

@Test
func mergeForestOutOfOrder() throws {
  // The child appears before its parent. Output order must match input order.
  var inputs: [OrderedSet<ForestNode>] = []
  do {
    let a = ForestNode("a", 0)
    let b = ForestNode("b", 1)
    let ac = ForestNode("ac", 2, in: a)
    inputs.append([ac, b, a])
  }

  let expectedOutput: OrderedSet<ForestNode>
  do {
    let a = ForestNode("a", 0)
    let b = ForestNode("b", 1)
    let ac = ForestNode("ac", 2, in: a)

    expectedOutput = [ac, b, a]
  }

  try testForestMerger(inputs: inputs, expectedOutput: expectedOutput)
}

@Test
func mergeForestOutOfOrderMultipleInputs() throws {
  // New elements from later inputs are appended in their own input order, even
  // when they appear before their parents.
  var inputs: [OrderedSet<ForestNode>] = []
  do {
    let a = ForestNode("a", 0)
    let ac = ForestNode("ac", 2, in: a)
    inputs.append([ac, a])
  }
  do {
    let b = ForestNode("b", 1)
    let bd = ForestNode("bd", 3, in: b)
    let a = ForestNode("a", 5)
    let ae = ForestNode("ae", 4, in: a)
    inputs.append([bd, ae, b, a])
  }

  let expectedOutput: OrderedSet<ForestNode>
  do {
    let a = ForestNode("a", 0)
    let ac = ForestNode("ac", 2, in: a)
    let b = ForestNode("b", 1)
    let bd = ForestNode("bd", 3, in: b)
    let ae = ForestNode("ae", 4, in: a)

    expectedOutput = [ac, a, bd, ae, b]
  }

  try testForestMerger(inputs: inputs, expectedOutput: expectedOutput)
}

@Test
func mergeForestKeepsFirstName() throws {
  // Nodes with the same name in different inputs merge into one node, and the
  // name is preserved.
  var inputs: [OrderedSet<ForestNode>] = []
  do {
    let a = ForestNode("a", 0)
    inputs.append([a])
  }
  do {
    let a = ForestNode("a", 7)
    let b = ForestNode("b", 1, in: a)
    inputs.append([a, b])
  }

  let expectedOutput: OrderedSet<ForestNode>
  do {
    let a = ForestNode("a", 0)
    let b = ForestNode("b", 1, in: a)

    expectedOutput = [a, b]
  }

  try testForestMerger(inputs: inputs, expectedOutput: expectedOutput)
}

@Test
func mergeForestNamesDistinguishNodes() throws {
  // Nodes with different names are never merged, and each keeps its own name.
  // A later input's value is used only to fill in a missing (nil) value.
  var inputs: [OrderedSet<ForestNode>] = []
  do {
    let a = ForestNode("a")
    let b = ForestNode("b", 1)
    inputs.append([a, b])
  }
  do {
    let a = ForestNode("a", 4)
    let c = ForestNode("c", 5)
    inputs.append([c, a])
  }

  let expectedOutput: OrderedSet<ForestNode>
  do {
    let a = ForestNode("a", 4)
    let b = ForestNode("b", 1)
    let c = ForestNode("c", 5)

    expectedOutput = [a, b, c]
  }

  try testForestMerger(inputs: inputs, expectedOutput: expectedOutput)
}
