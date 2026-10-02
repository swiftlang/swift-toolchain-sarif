internal import OrderedCollections
internal import SARIF

struct PropertyMerger<T> {
  let input: T
  var output: T
  let first: Bool
  let sink: any ValidationSink

  init(from input: T, into output: T, first: Bool, sink: any ValidationSink) {
    self.input = input
    self.output = output
    self.first = first
    self.sink = sink
  }

  mutating func concatenate<E>(key: WritableKeyPath<T, [E]>) throws {
    let inputValue = self.input[keyPath: key]
    self.output[keyPath: key].append(contentsOf: inputValue)
  }

  mutating func mergeFirst<V: MergeableValue>(
    key: WritableKeyPath<T, V?>, with context: V.Context, make: () -> V
  ) throws {
    if self.first {
      let inputValue = self.input[keyPath: key]
      if let inputValue {
        var mergeState = V.MergeState()
        var valueMerger = PropertyMerger<V>(
          from: inputValue, into: make(), first: true, sink: self.sink)
        try mergeState.merge(merger: &valueMerger, with: context)
        self.output[keyPath: key] = valueMerger.output
      } else {
        self.output[keyPath: key] = nil
      }
    }
  }

  mutating func mergeFirst<V: MergeableValue>(
    key: WritableKeyPath<T, [V]>, with context: V.Context, make: () -> V
  ) throws {
    if self.first {
      let inputValues = self.input[keyPath: key]
      var outputValues: [V] = []
      outputValues.reserveCapacity(inputValues.count)

      for inputValue in inputValues {
        var mergeState = V.MergeState()
        var valueMerger = PropertyMerger<V>(
          from: inputValue, into: make(), first: true, sink: self.sink)
        try mergeState.merge(merger: &valueMerger, with: context)
        outputValues.append(valueMerger.output)
      }

      self.output[keyPath: key] = outputValues
    }
  }

  mutating func keepFirstReferences<V: AnyObject>(
    key: WritableKeyPath<T, [V]>, resolve: (V) throws -> V
  ) throws {
    if self.first {
      let inputReferences = self.input[keyPath: key]
      let outputReferences = try inputReferences.map(resolve)
      self.output[keyPath: key] = outputReferences
    }
  }

  /// Keep the reference from the first input for a property that is non-optional.
  mutating func keepFirstReference<V: AnyObject>(
    key: WritableKeyPath<T, V>, resolve: (V) throws -> V
  ) throws {
    if self.first {
      let inputReference = self.input[keyPath: key]
      let outputReference = try resolve(inputReference)
      self.output[keyPath: key] = outputReference
    }
  }

  /// Keep the reference from the first input for a property that is optional.
  ///
  /// The output reference will be nil if the first input reference was nil,
  /// regardless of whether any subsequence input reference was non-nil.
  mutating func keepFirstReference<V: AnyObject>(
    key: WritableKeyPath<T, V?>, resolve: (V) throws -> V
  ) throws {
    if self.first {
      let inputReference = self.input[keyPath: key]
      if let inputReference {
        let outputReference = try resolve(inputReference)
        self.output[keyPath: key] = outputReference
      }
    }
  }

  /// Keep the value of the property from the first input.
  func keepFirst<each V>(keys: repeat ReferenceWritableKeyPath<T, each V>)
    throws
  {
    if self.first {
      for key in repeat each keys {
        self.output[keyPath: key] = self.input[keyPath: key]
      }
    }
  }

  /// Keep the value of the property from the first input for which the property is non-nil.
  ///
  /// If all inputs have a nil value for the property, the output value will be nil as well.
  func keepFirstSpecified<each V>(
    keys: repeat ReferenceWritableKeyPath<T, (each V)?>
  ) throws {
    for key in repeat each keys {
      if self.output[keyPath: key] == nil {
        if let inputValue = self.input[keyPath: key] {
          self.output[keyPath: key] = inputValue
        }
      }
    }
  }

  /// Assert that every input specifies the same reference for the property.
  func assertIdentical<V: AnyObject>(
    key: ReferenceWritableKeyPath<T, V>, definitions: ReferenceMergeMap<V>
  ) throws {
    let originalInputValue = self.input[keyPath: key]
    let resolvedInputValue = definitions.resolve(from: originalInputValue)
    if self.first {
      self.output[keyPath: key] = resolvedInputValue
    } else {
      let outputValue = self.output[keyPath: key]
      guard resolvedInputValue === outputValue else {
        try sink.fatalError(
          "Unexpected unequal values for property '\(key)'.")
      }
    }
  }

  /// Assert that every input provides an equal value for the property.
  func assertEqual<each V: Equatable>(
    keys: repeat ReferenceWritableKeyPath<T, each V>
  ) throws {
    for key in repeat each keys {
      let inputValue = self.input[keyPath: key]
      if self.first {
        self.output[keyPath: key] = inputValue
      } else {
        let outputValue = self.output[keyPath: key]
        guard inputValue == outputValue else {
          try sink.fatalError(
            "Unexpected unequal values for property '\(key)'.")
        }
      }
    }
  }

  /// Assert that every input provides an equal value for the property, ignoring
  /// inputs for which the property was nil.
  func assertEqualOrNil<each V: Equatable>(
    keys: repeat ReferenceWritableKeyPath<T, (each V)?>
  )
    throws
  {
    for key in repeat each keys {
      if let inputValue = self.input[keyPath: key] {
        if let outputValue = self.output[keyPath: key] {
          guard inputValue == outputValue else {
            try sink.fatalError(
              "Unexpected unequal values for property '\(key)'."
            )
          }
        } else {
          self.output[keyPath: key] = inputValue
        }
      }
    }
  }

  mutating func expectEqual<each V: Equatable>(
    keys: repeat WritableKeyPath<T, each V>
  ) throws {
    for key in repeat each keys {
      let inputValue = self.input[keyPath: key]
      if self.first {
        self.output[keyPath: key] = inputValue
      } else {
        let outputValue = self.output[keyPath: key]
        if inputValue != outputValue {
          try sink.recoverableError(
            "Expected values for property '\(key)' to be equal. Using the first value specified."
          )
        }
      }
    }
  }

  func assertNil<each V>(keys: repeat KeyPath<T, (each V)?>) throws {
    for key in repeat each keys {
      guard self.input[keyPath: key] == nil else {
        try self.sink.fatalError(
          "Unexpected non-nil value for property '\(key)'.")
      }
    }
  }

  /// Create the union of all input values, deduplicating based on equality.
  func union<each V: Hashable>(
    keys: repeat ReferenceWritableKeyPath<T, OrderedSet<each V>>
  ) throws {
    for key in repeat each keys {
      self.output[keyPath: key].formUnion(self.input[keyPath: key])
    }
  }

  func ignore<each V>(keys: repeat KeyPath<T, each V>) throws {
    // No effect
  }
}
