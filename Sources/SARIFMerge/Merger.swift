/// Merges a single object-valued property across multiple input objects into one output object.
///
/// A `Merger` is used for a property that holds exactly one `Object` (as opposed to an array of
/// them). Each call to `merge(key:merger:)` folds the corresponding property of the current input
/// parent into the property of the output parent. The first call copies the input value into the
/// output; later calls merge into the existing output value using the object's `MergeState`, which
/// persists across calls.
internal struct Merger<Object>
where Object: MergeableWithIdentity, Object.MergeState.Object == Object {
  /// `true` until the first input has been merged.
  private var first: Bool = true
  /// Per-object state carried across successive merges.
  private var mergeState = Object.MergeState()

  /// Merges the property at `key` from the current input parent into the output parent, for
  /// objects whose merge state requires no context.
  ///
  /// - Parameters:
  ///   - key: The key path of the property to merge on `Parent`.
  ///   - merger: The property merger holding the current input parent, the output parent, and the
  ///     diagnostic sink.
  mutating func merge<Parent: AnyObject>(
    key: WritableKeyPath<Parent, Object>, merger: inout PropertyMerger<Parent>
  )
    throws where Object.MergeState.Context == Void
  {
    try merge(key: key, merger: &merger, with: ())
  }

  /// Merges the property at `key` from the current input parent into the output parent, passing
  /// `context` through to the object's merge state.
  ///
  /// - Parameters:
  ///   - key: The key path of the property to merge on `Parent`.
  ///   - merger: The property merger holding the current input parent, the output parent, and the
  ///     diagnostic sink.
  ///   - context: Additional context required by the object's `MergeState` to perform the merge.
  mutating func merge<Parent: AnyObject>(
    key: WritableKeyPath<Parent, Object>, merger: inout PropertyMerger<Parent>,
    with context: Object.MergeState.Context
  ) throws {
    try PropertyMerger.merge(
      from: merger.input[keyPath: key], into: &merger.output[keyPath: key],
      first: self.first, sink: merger.sink
    ) { objectMerger in
      try self.mergeState.merge(merger: &objectMerger, with: context)
    }
    self.first = false
  }
}
