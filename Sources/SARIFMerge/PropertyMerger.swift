internal import OrderedCollections
internal import SARIF

/// Merges the properties of one input object into an output object of the same type.
///
/// A `PropertyMerger` is created for each input that is merged into an output. The merge
/// operation is driven by a closure that calls the merging methods of this type (for example,
/// ``keepFirst(keys:)``, ``assertEqual(keys:)``, or ``union(keys:)``) once per property, to
/// describe how that property should be combined. Each method reads the property from
/// ``input`` and updates the same property of ``output``.
///
/// Most methods behave differently depending on whether the input is the first one being merged
/// (see ``first``). For the first input, the output is typically initialized from the input. For
/// subsequent inputs, the input is combined with the existing output value, or is checked
/// against it for consistency.
///
/// Inconsistencies between inputs are reported to ``sink``. Unrecoverable inconsistencies are
/// reported as fatal errors, which cause the merging method to throw.
///
/// ```swift
/// PropertyMerger.merge(
///   from: inputRun, into: &outputRun, first: isFirst, sink: sink
/// ) { merger in
///   try merger.assertEqual(keys: \.language)
///   try merger.keepFirst(keys: \.columnKind)
///   try merger.concatenate(key: \.results)
/// }
/// ```
struct PropertyMerger<T> {
  /// The object whose property values are being merged into ``output``.
  let input: T
  /// The object that accumulates the merged property values.
  var output: T
  /// `true` if ``input`` is the first input being merged into ``output``; otherwise, `false`.
  let first: Bool
  /// The sink to which merge diagnostics are reported.
  let sink: any ValidationSink

  private init(
    from input: T, into output: T, first: Bool, sink: any ValidationSink
  ) {
    self.input = input
    self.output = output
    self.first = first
    self.sink = sink
  }

  /// Merges the properties of a reference-type input into a reference-type output.
  ///
  /// Because `T` is a class type, the properties of `output` are modified in place.
  ///
  /// - Parameters:
  ///   - input: The object whose properties will be merged.
  ///   - output: The object into which the properties will be merged.
  ///   - first: `true` if `input` is the first input being merged into `output`.
  ///   - sink: The sink to which merge diagnostics are reported.
  ///   - merge: A closure that merges each property by calling methods on the provided merger.
  /// - Throws: Rethrows any error thrown by `merge`, including fatal errors reported to `sink`.
  static func merge(
    from input: T, into output: T, first: Bool, sink: any ValidationSink,
    merge: (_ merger: inout Self) throws -> Void
  ) rethrows where T: AnyObject {
    var tempOutput = output
    try Self.merge(
      from: input, into: &tempOutput, first: first, sink: sink, merge: merge)
  }

  /// Merges the properties of an input into an output value.
  ///
  /// The updated output is written back to `output` when this function returns, even if `merge`
  /// throws.
  ///
  /// - Parameters:
  ///   - input: The value whose properties will be merged.
  ///   - output: The value into which the properties will be merged.
  ///   - first: `true` if `input` is the first input being merged into `output`.
  ///   - sink: The sink to which merge diagnostics are reported.
  ///   - merge: A closure that merges each property by calling methods on the provided merger.
  /// - Throws: Rethrows any error thrown by `merge`, including fatal errors reported to `sink`.
  static func merge(
    from input: T, into output: inout T, first: Bool, sink: any ValidationSink,
    merge: (_ merger: inout Self) throws -> Void
  ) rethrows {
    var merger = Self(from: input, into: output, first: first, sink: sink)
    defer {
      output = merger.output
    }
    try merge(&merger)
  }

  /// Append the elements of the array property from each input to the output array, in the order
  /// the inputs are merged.
  ///
  /// No deduplication is performed.
  ///
  /// - Parameter key: The array property to concatenate.
  mutating func concatenate<E>(key: WritableKeyPath<T, [E]>) throws {
    let inputValue = self.input[keyPath: key]
    self.output[keyPath: key].append(contentsOf: inputValue)
  }

  /// Merge the optional, mergeable property from the first input only.
  ///
  /// For the first input, a new value is created with `make` and the input value is merged into
  /// it. If the input value is nil, the output value is set to nil. Subsequent inputs are
  /// ignored.
  ///
  /// - Parameters:
  ///   - key: The optional property to merge.
  ///   - context: The context passed to the property value's merge operation.
  ///   - make: A closure that creates the initial output value to merge into.
  mutating func mergeFirst<V: Mergeable>(
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

  /// Merge the array property from the first input only.
  ///
  /// For the first input, each element is merged into a new value created with `make`, and the
  /// results replace the output array, preserving order. Subsequent inputs are ignored.
  ///
  /// - Parameters:
  ///   - key: The array property to merge.
  ///   - context: The context passed to each element's merge operation.
  ///   - make: A closure that creates the initial output value for each element.
  mutating func mergeFirst<V: Mergeable>(
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

  /// Keep the references from the first input for a property that is an array of references.
  ///
  /// Each reference is passed through `resolve` (for example, to map it to the corresponding
  /// merged object). Subsequent inputs are ignored.
  ///
  /// - Parameters:
  ///   - key: The array property to keep.
  ///   - resolve: A closure that maps an input reference to the reference to store in the output.
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
  mutating func keepFirst<each V>(keys: repeat WritableKeyPath<T, each V>)
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
  mutating func keepFirstSpecified<each V>(
    keys: repeat WritableKeyPath<T, (each V)?>
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
  mutating func assertEqual<each V: Equatable>(
    keys: repeat WritableKeyPath<T, each V>
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
  mutating func assertEqualOrNil<each V: Equatable>(
    keys: repeat WritableKeyPath<T, (each V)?>
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

  /// Expect every input to provide an equal value for the property.
  ///
  /// If a later input differs from the output, a recoverable error is reported to the sink and
  /// the value from the first input is kept.
  ///
  /// - Parameter keys: The properties to compare.
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

  /// Assert that the property is nil in every input.
  ///
  /// - Parameter keys: The properties that must be nil.
  /// - Throws: A fatal error reported to the sink if any property is non-nil.
  func assertNil<each V>(keys: repeat KeyPath<T, (each V)?>) throws {
    for key in repeat each keys {
      guard self.input[keyPath: key] == nil else {
        try self.sink.fatalError(
          "Unexpected non-nil value for property '\(key)'.")
      }
    }
  }

  /// Create the union of all input values, deduplicating based on equality.
  mutating func union<each V: Hashable>(
    keys: repeat WritableKeyPath<T, OrderedSet<each V>>
  ) throws {
    for key in repeat each keys {
      self.output[keyPath: key].formUnion(self.input[keyPath: key])
    }
  }

  /// Explicitly ignore the property, leaving the output unchanged.
  ///
  /// This documents that a property was intentionally omitted from the merge, as opposed to
  /// having been forgotten.
  ///
  /// - Parameter keys: The properties to ignore.
  func ignore<each V>(keys: repeat KeyPath<T, each V>) throws {
    // No effect
  }
}
