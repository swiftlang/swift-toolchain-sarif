internal import SARIF

private final class ElementMerger<Object: MergeableWithIdentity> {
  let output: Object
  private var mergeState = Object.MergeState()

  init(into output: Object) {
    self.output = output
  }

  func merge(
    from input: Object, first: Bool, with context: Object.MergeState.Context,
    sink: any ValidationSink
  ) throws {
    var propertyMerger = PropertyMerger(
      from: input, into: self.output, first: first, sink: sink)
    try self.mergeState.merge(merger: &propertyMerger, with: context)
  }
}

internal struct ArrayMerger<Object: MergeableWithIdentity, Parent: AnyObject> {
  private var byIdentity: [Object.MergeKey: ElementMerger<Object>] = [:]

  mutating func merge(
    key: KeyPath<Parent, some Sequence<Object>>,
    merger: inout PropertyMerger<Parent>,
    map: ReferenceMergeMap<Object>, makeOutput: (_ firstInput: Object) -> Object
  ) throws where Object.MergeState.Context == Void {
    try merge(
      key: key, merger: &merger, with: (), map: map, makeOutput: makeOutput)
  }

  mutating func mergeForest<ForestType: Forest>(
    key: KeyPath<Parent, ForestType.CollectionType>,
    merger: inout PropertyMerger<Parent>,
    with context: Object.MergeState.Context,
    map: ReferenceMergeMap<Object>,
    makeForest: (_ elements: ForestType.CollectionType) -> ForestType,
    makeOutput: (_ firstInput: Object, _ parentOutput: Object?) -> Object,
    addOutput: (_ output: Object) -> Void
  ) throws where ForestType.CollectionType.Element == Object {
    let inputs = merger.input[keyPath: key]
    let forest = makeForest(inputs)
    var newOutputs: [(index: Int, output: Object)] = []
    try forest.visitTopDown { index, parentOutput in
      let input = forest.elements[index]
      let identity = try input.mergeKey(with: context)
      let existingMerger = self.byIdentity[identity]
      let elementMerger: ElementMerger<Object>
      let first: Bool
      if let existingMerger {
        elementMerger = existingMerger
        first = false
      } else {
        // Need to create a new object and its merger.
        let newOutput = makeOutput(input, parentOutput)
        newOutputs.append((index: index, output: newOutput))
        elementMerger = .init(into: newOutput)
        first = true
        self.byIdentity[identity] = elementMerger
      }
      try elementMerger.merge(
        from: input, first: first, with: context, sink: merger.sink)
      map.addDefinition(from: input, into: elementMerger.output)
      return elementMerger.output
    }

    newOutputs.sort { $0.index < $1.index }
    newOutputs.map(\.output).forEach(addOutput)
  }

  mutating func merge(
    key: KeyPath<Parent, some Sequence<Object>>,
    merger: inout PropertyMerger<Parent>,
    with context: Object.MergeState.Context, map: ReferenceMergeMap<Object>,
    makeOutput: (_ firstInput: Object) -> Object
  ) throws {
    let inputs = merger.input[keyPath: key]
    for input in inputs {
      let identity = try input.mergeKey(with: context)
      let existingMerger = self.byIdentity[identity]
      let elementMerger: ElementMerger<Object>
      let first: Bool
      if let existingMerger {
        elementMerger = existingMerger
        first = false
      } else {
        // Need to create a new object and its merger.
        elementMerger = .init(into: makeOutput(input))
        first = true
        self.byIdentity[identity] = elementMerger
      }
      try elementMerger.merge(
        from: input, first: first, with: context, sink: merger.sink)
      map.addDefinition(from: input, into: elementMerger.output)
    }
  }
}

internal struct FixedArrayMerger<
  Object: MergeableWithIdentity, Parent: AnyObject
> {
  private var elements: [ElementMerger<Object>] = []

  mutating func merge(
    key: ReferenceWritableKeyPath<Parent, [Object]>,
    merger: inout PropertyMerger<Parent>,
    with context: Object.Context, make: () -> Object
  ) throws {
    let inputElements = merger.input[keyPath: key]
    if merger.first {
      self.elements = try inputElements.map { inputElement in
        let elementMerger = ElementMerger(into: make())
        try elementMerger.merge(
          from: inputElement, first: true, with: context, sink: merger.sink)
        return elementMerger
      }
    } else {
      guard inputElements.count == self.elements.count else {
        try merger.sink.fatalError(
          "Array size mismatch for property '\(key)'.")
      }

      try self.elements.enumerated().forEach { index, elementMerger in
        let inputElement = inputElements[index]
        try elementMerger.merge(
          from: inputElement, first: false, with: context, sink: merger.sink)
      }
    }
  }
}
