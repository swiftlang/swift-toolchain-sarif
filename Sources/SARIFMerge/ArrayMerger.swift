internal import OrderedCollections
internal import SARIF

/// A collection that can be used by ``ArrayMerger`` or ``ForestMerger``
internal protocol MergeableSequence<Element>: RandomAccessCollection
where Index == Int {
  init()

  /// Appends a new element to the collection.
  mutating func append(newElement: Element)

  /// Accesses the element at the specified index.
  subscript(updating index: Int) -> Element { get set }
}

extension Array: MergeableSequence {
  mutating func append(newElement: Element) {
    self.append(newElement)
  }

  subscript(updating index: Int) -> Element {
    get { self[index] }
    set { self[index] = newValue }
  }
}

extension OrderedSet: MergeableSequence {
  mutating func append(newElement: Element) {
    self.append(newElement)
  }

  subscript(updating index: Int) -> Element {
    get { self[index] }
    set { self.update(newValue, at: index) }
  }
}

/// Merge state for a property of array type.
internal struct ArrayMerger<Object: Mergeable, Parent: AnyObject> {
  typealias RecordReference = (_ input: Object, _ output: Object) -> Void

  /// Holds the merge state for an individual element.
  private struct ElementMerger {
    /// The index of the element in the output array.
    /// Used to access the output element when merging.
    private let outputIndex: Int
    /// `true` until the first input has been merged.
    private var first: Bool = true
    /// The merge state for the element.
    private var mergeState = Object.MergeState()

    init(outputIndex: Int) {
      self.outputIndex = outputIndex
    }

    mutating func merge(
      from input: Object, into outputs: inout some MergeableSequence<Object>,
      with context: Object.MergeState.Context, sink: any ValidationSink
    ) throws -> Int {
      try PropertyMerger.merge(
        from: input, into: &outputs[updating: self.outputIndex],
        first: self.first, sink: sink
      ) { merger in
        try self.mergeState.merge(merger: &merger, with: context)
      }
      self.first = false

      return self.outputIndex
    }
  }

  private var byIdentity: [Object.MergeKey: ElementMerger] = [:]

  /// Merges the array property at `key` from the input object into the output
  /// object, for element types that don't need a merge context.
  ///
  /// This is a convenience overload of
  /// ``merge(key:merger:with:makeOutput:recordReference:)`` that passes `()` as
  /// the context.
  mutating func merge(
    key: ReferenceWritableKeyPath<Parent, some MergeableSequence<Object>>,
    merger: inout PropertyMerger<Parent>,
    makeOutput: (_ firstInput: Object) -> Object,
    recordReference: RecordReference? = nil
  ) throws where Object.MergeState.Context == Void {
    try merge(
      key: key, merger: &merger, with: (), makeOutput: makeOutput,
      recordReference: recordReference)
  }

  /// Merges the array property at `key` from the input object into the output
  /// object.
  ///
  /// Each element of the input array is matched against previously merged
  /// elements by its merge key. If no element with the same key has been seen
  /// before, a new output element is created with `makeOutput` and appended to
  /// the output array. Otherwise, the input element is merged into the existing
  /// output element. New elements are appended in input order.
  ///
  /// - Parameters:
  ///   - key: The key path of the array property to merge.
  ///   - merger: The merger for the parent object, which provides the input
  ///     and output objects and the validation sink.
  ///   - context: The context used to compute merge keys and merge elements.
  ///   - makeOutput: Creates a new output element from the first input element
  ///     with a given merge key.
  ///   - recordReference: An optional closure called for every input element
  ///     with the corresponding output element, whether newly created or
  ///     merged into an existing one.
  mutating func merge<S: MergeableSequence<Object>>(
    key: ReferenceWritableKeyPath<Parent, S>,
    merger: inout PropertyMerger<Parent>,
    with context: Object.MergeState.Context,
    makeOutput: (_ firstInput: Object) -> Object,
    recordReference: RecordReference? = nil
  ) throws {
    let inputs = merger.input[keyPath: key]
    var outputs = merger.output[keyPath: key]
    // Temporarily store an empty sequence into the property so that modifying
    // our local copy doesn't force a copy-on-write of the old version.
    merger.output[keyPath: key] = S()
    defer {
      merger.output[keyPath: key] = outputs
    }

    precondition(outputs.count == self.byIdentity.count)

    for input in inputs {
      let identity = try input.mergeKey(with: context)

      func makeElementMerger() -> ElementMerger {
        let outputIndex = outputs.endIndex
        outputs.append(newElement: makeOutput(input))
        return .init(outputIndex: outputIndex)
      }

      let outputIndex = try self.byIdentity[
        identity, default: makeElementMerger()
      ].merge(from: input, into: &outputs, with: context, sink: merger.sink)

      // Record the mapping from input to output.
      recordReference?(input, outputs[outputIndex])
    }
  }
}

/// Merge state for a property containing a forest of nodes.
internal struct ForestMerger<ForestType: Forest, Parent: AnyObject>
where
  ForestType.CollectionType.Element: MergeableWithIdentity,
  ForestType.CollectionType: MergeableSequence
{
  typealias Object = ForestType.CollectionType.Element
  typealias RecordReference = (_ input: Object, _ output: Object) -> Void

  private struct ElementMerger {
    // We know the output is a class, so we can store the output directly.
    let output: Object
    /// `true` until the first input has been merged.
    private var first = true
    private var mergeState = Object.MergeState()

    init(output: Object) {
      self.output = output
    }

    mutating func merge(
      from input: Object,
      with context: Object.MergeState.Context,
      sink: any ValidationSink
    ) throws -> Object {
      try PropertyMerger.merge(
        from: input, into: self.output, first: self.first, sink: sink
      ) { merger in
        try self.mergeState.merge(merger: &merger, with: context)
      }

      return self.output
    }
  }

  private var byIdentity: [Object.MergeKey: ElementMerger] = [:]

  /// Merges the forest-structured collection property at `key` from the input
  /// object into the output object.
  ///
  /// Each element is matched against previously merged elements
  /// by its merge key. If no element with the same key has been seen before, a
  /// new output element is created with `makeOutput`; otherwise, the input
  /// element is merged into the existing output element. Newly created output
  /// elements are appended to the output collection in input order.
  ///
  /// - Parameters:
  ///   - key: The key path of the collection property to merge.
  ///   - merger: The merger for the parent object, which provides the input
  ///     and output objects and the validation sink.
  ///   - context: The context used to compute merge keys and merge elements.
  ///   - recordReference: An optional closure called for every input element
  ///     with the corresponding output element, whether newly created or
  ///     merged into an existing one.
  ///   - makeForest: Creates the forest describing the parent/child structure
  ///     of the input elements.
  ///   - makeOutput: Creates a new output element from the first input element
  ///     with a given merge key, and the output element corresponding to its
  ///     parent (`nil` for a root element).
  mutating func merge(
    key: WritableKeyPath<Parent, ForestType.CollectionType>,
    merger: inout PropertyMerger<Parent>,
    with context: Object.MergeState.Context,
    recordReference: RecordReference?,
    makeForest: (_ elements: ForestType.CollectionType) -> ForestType,
    makeOutput: (_ firstInput: Object, _ parentOutput: Object?) -> Object
  ) throws {
    let inputs = merger.input[keyPath: key]
    let forest = makeForest(inputs)
    var outputs = merger.output[keyPath: key]
    // Temporarily store an empty sequence into the property so that modifying
    // our local copy doesn't force a copy-on-write of the old version.
    merger.output[keyPath: key] = ForestType.CollectionType()
    defer {
      merger.output[keyPath: key] = outputs
    }

    precondition(outputs.count == self.byIdentity.count)

    var newOutputs: [(inputIndex: Int, output: Object)] = []

    try forest.visitTopDown { inputIndex, parentOutput in
      let input = inputs[inputIndex]
      let identity = try input.mergeKey(with: context)

      func makeElementMerger() -> ElementMerger {
        let output = makeOutput(input, parentOutput)
        newOutputs.append((inputIndex: inputIndex, output: output))
        return .init(output: output)
      }

      let output = try self.byIdentity[identity, default: makeElementMerger()]
        .merge(from: input, with: context, sink: merger.sink)

      /// Record the mapping from input to output.
      recordReference?(input, output)

      return output
    }

    // Sort the new outputs by input index to preserve input order.
    newOutputs.sort { $0.inputIndex < $1.inputIndex }
    newOutputs.forEach { outputs.append(newElement: $0.output) }
  }
}
