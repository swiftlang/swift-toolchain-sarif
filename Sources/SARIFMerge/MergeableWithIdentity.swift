internal protocol MergeStateProtocolWithContext<Object> {
  associatedtype Object: Mergeable where Object.MergeState == Self

  typealias Context = Object.Context

  init()

  mutating func merge(
    merger: inout PropertyMerger<Object>, with context: Context) throws
}

internal protocol MergeStateProtocol<Object>: MergeStateProtocolWithContext
where Context == Void {
  mutating func merge(merger: inout PropertyMerger<Object>) throws
}

extension MergeStateProtocol {
  mutating func merge(
    merger: inout PropertyMerger<Object>, with context: Context
  ) throws {
    try merge(merger: &merger)
  }
}

internal protocol Mergeable: MergeHashable {
  associatedtype MergeState: MergeStateProtocolWithContext
  where MergeState.Object == Self
}

internal protocol MergeableWithIdentity: AnyObject, Mergeable {
}
