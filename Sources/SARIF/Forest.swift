fileprivate import OrderedCollections

/// An array of elements, each of which has an optional parent element within the array.
///
/// The elements need not be in any particular order with respect to their parents.
package protocol Forest {
  /// The type of the collection holding the elements.
  associatedtype CollectionType: RandomAccessCollection
  where CollectionType.Index == Int

  /// The collection of elements.
  var elements: CollectionType { get }

  /// Report a cycle detected in the parent chain.
  ///
  /// - Parameter chain: The element indices comprising the cycle, including the repeated element index at the end.
  func reportCycle(_ chain: [Int]) throws -> Never

  /// Get the parent index of the specified element.
  ///
  /// - Parameter ofIndex: The index of the child element
  /// - Returns: The index of the element's parent, or nil if the element is a root.
  func getParentIndex(ofIndex index: Int) throws -> Int?
}

extension Forest {
  /// Visit each element in the forest in top-down order (parents before children).
  package func visitTopDown<Value>(
    visit: (_ index: Int, _ parentValue: Value?) throws -> Value
  ) throws {
    // Track the state of each element. A nil value means that the element is currently
    // waiting for its ancestors to be visited. A non-nil value is the result of
    // the `visit` call for that element.
    var results: OrderedDictionary<Int, Value?> = [:]

    for (index, _) in self.elements.enumerated() {
      // Push this element and its ancestors onto the `results` stack until we hit
      // either the root of the tree or until we hit an ancestor whose result value
      // has already been computed.
      let rootValue = try pushPendingAncestors(
        startIndex: index, results: &results)

      // Pop pending elements off the `results` stack, visiting them to compute their result values.
      try Self.processStack(
        rootValue: rootValue, elements: &results.elements, visit: visit)
    }
  }

  private func pushPendingAncestors<Value>(
    startIndex: Int, results: inout OrderedDictionary<Int, Value?>
  ) throws -> Value? {
    var index: Int? = startIndex
    let chainStartIndex = results.count
    while true {
      guard let currentIndex = index else {
        // Reached the top of the tree. No parent, so return a nil parent result.
        return nil
      }
      if let result = results[currentIndex] {
        guard let value = result else {
          // This element is already in the `results` map, but has no value.
          // This means that it was pushed as part of the current `pushPendingAncestors` call.
          // This indicates a cycle in the ancestry chain.

          // The cycle consists of all of the indices in the map starting at `chainStartIndex`, with
          // the start index repeated at the end to complete the cycle.
          let chain =
            Array(
              results.elements[chainStartIndex..<results.elements.endIndex].map
              { $0.key }) + [currentIndex]
          try reportCycle(chain)
        }

        // This element already has a result value. Return it so that it can propagate back down to its descendants.
        return value
      }

      // This element has not yet been visited. Push it onto the `results` stack with a nil result.
      let result: Value? = nil
      results[currentIndex] = result

      index = try getParentIndex(ofIndex: currentIndex)
    }
  }

  private static func processStack<Value>(
    rootValue: Value?, elements: inout OrderedDictionary<Int, Value?>.Elements,
    visit: (_ index: Int, _ parentValue: Value?) throws -> Value
  ) throws {
    var parentValue = rootValue
    var stackIndex = elements.endIndex
    while stackIndex > elements.startIndex {
      stackIndex = elements.index(before: stackIndex)
      let element = elements[stackIndex]
      guard element.value == nil else {
        // Hit the bottom of the stack of unvisited elements.
        return
      }

      // Visit the element. The result will be the parent value of the next element we visit.
      parentValue = try visit(element.key, parentValue)
      // Record this element as visited.
      elements.replaceElement(
        at: stackIndex, withKey: element.key, value: parentValue)
    }
  }
}
