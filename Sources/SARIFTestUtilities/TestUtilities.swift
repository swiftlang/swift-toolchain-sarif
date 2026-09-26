package import Foundation
import ImmutableJSON
import Testing

extension Bundle {
  package func resourceDirectory() throws -> URL {
    let resourcePath = URL(
      filePath: self.resourcePath!, directoryHint: .isDirectory)
    return resourcePath.appending(
      path: "Resources", directoryHint: .isDirectory)
  }

  package func resourceFile(named name: String) throws -> URL {
    try resourceDirectory().appending(path: name, directoryHint: .notDirectory)
  }

  package func loadResource(named name: String) throws -> Data {
    try Data(contentsOf: resourceFile(named: name))
  }
}

private func difference(expected: String, actual: String) -> String? {
  let expectedLines = expected.split(
    separator: "\n", omittingEmptySubsequences: false)
  let actualLines = actual.split(
    separator: "\n", omittingEmptySubsequences: false)

  let diff = actualLines.difference(from: expectedLines)
  if diff.isEmpty {
    return nil
  } else {
    var diffLines = [""]  // Add an empty line at the beginning to make the Xcode failure UI look cleaner.
    var expectedLineIndex = 0
    var actualLineIndex = 0
    var nextRemovalIndex = 0
    var nextInsertionIndex = 0
    while (expectedLineIndex < expectedLines.count)
      || (actualLineIndex < actualLines.count)
    {
      if nextRemovalIndex < diff.removals.count,
        case .remove(let offset, let removedLine, _) = diff.removals[
          nextRemovalIndex],
        offset == expectedLineIndex
      {
        // We have a removal.
        diffLines.append("- \(removedLine)")
        nextRemovalIndex += 1
        expectedLineIndex += 1
      } else if nextInsertionIndex < diff.insertions.count,
        case .insert(let offset, let insertedLine, _) = diff.insertions[
          nextInsertionIndex],
        offset == actualLineIndex
      {
        // We have an insertion.
        diffLines.append("+ \(insertedLine)")
        nextInsertionIndex += 1
        actualLineIndex += 1
      } else {
        diffLines.append("  \(expectedLines[expectedLineIndex])")
        expectedLineIndex += 1
        actualLineIndex += 1
      }
    }

    return diffLines.joined(separator: "\n") + "\n"  // Add a final newline
  }
}

package func expectJSON(
  expected: some Encodable, actual: some Encodable,
  sourceLocation: SourceLocation = #_sourceLocation
) {
  let expectedText = try! expected.toJSONString()
  let actualText = try! actual.toJSONString()
  let diff = difference(expected: expectedText, actual: actualText)
  #expect(diff == nil, sourceLocation: sourceLocation)
}
