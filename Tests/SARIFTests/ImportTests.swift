import Foundation
import ImmutableJSON
import SARIF
import SARIFRecords
import SARIFTestUtilities
import Testing

func readFile(named name: String) throws -> Data {
  try Data(contentsOf: try Bundle.module.resourceFile(named: name))
}

func readJSON<T: Decodable>(_ type: T.Type, named name: String) throws -> T {
  let data = try readFile(named: name)
  return try T.fromJSONData(data)
}

func loadSarifLog(from fileName: String, sink: any ValidationSink)
  throws -> SARIFLog
{
  let logRecord = try readJSON(SARIFLogRecord.self, named: fileName)

  return try SARIFLog(from: logRecord, sink: sink)
}

@Test("Basic import")
func basicImport() throws {
  let log = try readJSON(SARIFLogRecord.self, named: "cpp.sarif")

  #expect(log.version == "2.1.0")
}

@Test("Clang import")
func clangImport() throws {
  let log = try readJSON(SARIFLogRecord.self, named: "test.sarif")

  #expect(log.version == "2.1.0")
}

@Test("Clang semantic import")
func clangSemanticImport() throws {
  let log = try readJSON(SARIFLog.self, named: "test.sarif")

  #expect(log.version == .v2_1_0)
  #expect(log.runs[0].artifacts[0].length == 99)
  #expect(log.runs[0].logicalLocations.count == 1)
  #expect(log.runs[0].logicalLocations[0].name == "root")
  #expect(
    log.runs[0].results[0].locations[0].physicalLocation?.artifactLocation?
      .artifact
      === log.runs[0].artifacts[0])
  #expect(
    log.runs[0].results[0].locations[0].physicalLocation?.region?.textRegion
      == TextRegion(line: 3, startColumn: 16, endColumn: 18))
}

@Test("Clang semantic import 2")
func clangSemanticImport2() throws {
  let log = try readJSON(SARIFLog.self, named: "test2.sarif")

  #expect(log.version == .v2_1_0)
}

@Test("Logical location parent import")
func logicalLocationParentImport() throws {
  let log = try readJSON(SARIFLog.self, named: "logicalLocations.sarif")

  let run = try #require(log.runs.first)
  let logicalLocations = run.logicalLocations
  try #require(logicalLocations.count == 3)

  #expect(logicalLocations[0].name == "N")
  #expect(logicalLocations[1].name == "A")
  #expect(logicalLocations[2].name == "M")

  #expect(logicalLocations[0].parent == nil)
  #expect(logicalLocations[1].parent === logicalLocations[0])
  #expect(logicalLocations[2].parent == nil)

  // The result's location refers to the two leaf logical locations by index, so
  // it must resolve to the very same objects as the run's definitions.
  let result = try #require(run.results.first)
  let resultLocation = try #require(result.locations.first)
  try #require(resultLocation.logicalLocations.count == 2)
  #expect(resultLocation.logicalLocations[0] === logicalLocations[1])
  #expect(resultLocation.logicalLocations[1] === logicalLocations[2])
}

@Test("Logical location hierarchy import")
func logicalLocationHierarchyImport() throws {
  let log = try readJSON(
    SARIFLog.self, named: "logicalLocationHierarchy.sarif")

  let logicalLocations = try #require(log.runs.first).logicalLocations
  try #require(logicalLocations.count == 8)

  let namespaceN = logicalLocations[0]
  let namespaceM = logicalLocations[1]
  let typeA = logicalLocations[2]
  let typeB = logicalLocations[3]
  let functionF = logicalLocations[4]
  let functionG = logicalLocations[5]
  let typeC = logicalLocations[6]
  let functionH = logicalLocations[7]

  #expect(namespaceN.name == "N")
  #expect(namespaceM.name == "M")
  #expect(typeA.name == "A")
  #expect(typeB.name == "B")
  #expect(functionF.name == "f")
  #expect(functionG.name == "g")
  #expect(typeC.name == "C")
  #expect(functionH.name == "h")

  // Top-level locations.
  #expect(namespaceN.parent == nil)
  #expect(namespaceM.parent == nil)
  #expect(functionH.parent == nil)

  // `A` and `B` share `N` as their parent.
  #expect(typeA.parent === namespaceN)
  #expect(typeB.parent === namespaceN)

  // `f` and `g` share `A` as their parent, and `A` in turn has a parent of its
  // own, so these are three levels deep.
  #expect(functionF.parent === typeA)
  #expect(functionG.parent === typeA)
  #expect(functionF.parent?.parent === namespaceN)
  #expect(functionG.parent?.parent === namespaceN)

  // `C` hangs off the other top-level namespace.
  #expect(typeC.parent === namespaceM)
}

@Test("Reordered logical location hierarchy import")
func logicalLocationHierarchyReorderedImport() throws {
  // The same hierarchy as `logicalLocationHierarchy.sarif`, but reordered so
  // that `f`, `C`, and `B` all precede their parents, and `f` precedes both its
  // parent `A` and its grandparent `N`.
  let log = try readJSON(
    SARIFLog.self, named: "logicalLocationHierarchyReordered.sarif")

  let logicalLocations = try #require(log.runs.first).logicalLocations
  try #require(logicalLocations.count == 8)

  let functionF = logicalLocations[0]
  let typeC = logicalLocations[1]
  let typeB = logicalLocations[2]
  let functionH = logicalLocations[3]
  let namespaceN = logicalLocations[4]
  let typeA = logicalLocations[5]
  let namespaceM = logicalLocations[6]
  let functionG = logicalLocations[7]

  #expect(functionF.name == "f")
  #expect(typeC.name == "C")
  #expect(typeB.name == "B")
  #expect(functionH.name == "h")
  #expect(namespaceN.name == "N")
  #expect(typeA.name == "A")
  #expect(namespaceM.name == "M")
  #expect(functionG.name == "g")

  // Top-level locations.
  #expect(namespaceN.parent == nil)
  #expect(namespaceM.parent == nil)
  #expect(functionH.parent == nil)

  // `A` and `B` share `N` as their parent.
  #expect(typeA.parent === namespaceN)
  #expect(typeB.parent === namespaceN)

  // `f` and `g` share `A` as their parent, and `A` in turn has a parent of its
  // own, so these are three levels deep.
  #expect(functionF.parent === typeA)
  #expect(functionG.parent === typeA)
  #expect(functionF.parent?.parent === namespaceN)
  #expect(functionG.parent?.parent === namespaceN)

  // `C` hangs off the other top-level namespace.
  #expect(typeC.parent === namespaceM)
}

@Test("Logical location with out-of-bounds parent index")
func logicalLocationInvalidParentIndexImport() throws {
  // The second logical location claims index 3 as its parent, but the array
  // only has three elements, so the only valid indices are 0 through 2.
  let error = try #require(
    throws: SARIFError.self,
    performing: {
      try readJSON(
        SARIFLog.self, named: "logicalLocationInvalidParentIndex.sarif")
    })

  guard case .invalidSARIF(let message) = error else {
    Issue.record("Expected an 'invalidSARIF' error, but got '\(error)'.")
    return
  }
  #expect(message == "Parent index '3' out of bounds.")
}

@Test("Logical location with cyclic parent indices")
func logicalLocationCyclicParentIndexImport() throws {
  // `A`'s parent is `B`, whose parent is `C`, whose parent is `A` again.
  let error = try #require(
    throws: SARIFError.self,
    performing: {
      try readJSON(
        SARIFLog.self, named: "logicalLocationCyclicParentIndex.sarif")
    })

  guard case .invalidSARIF(let message) = error else {
    Issue.record("Expected an 'invalidSARIF' error, but got '\(error)'.")
    return
  }
  #expect(
    message
      == "Circular dependency in 'logicalLocation' parent chain: 0->1->2->0")
}
