import Foundation
import SARIF
import SARIFMerge
import SARIFTestUtilities
import Testing

private func loadSARIFLog(named name: String, sink: any ValidationSink) throws
  -> SARIFLog
{
  try SARIFLog(from: try Bundle.module.loadResource(named: name), sink: sink)
}

@Test
func mergeSingleFile() throws {
  let sink = StdOutValidationSink()

  let outputLog = SARIFLog()
  var merger = SARIFLogMerger(into: outputLog, sink: sink)

  let inputLog = try loadSARIFLog(named: "test.sarif", sink: sink)
  try merger.merge(from: inputLog)

  // We don't handle `defaultConfiguration` yet.
  withKnownIssue {
    expectJSON(expected: inputLog, actual: outputLog)
  }
}

@Test
func mergeDuplicateFiles() throws {
  let sink = StdOutValidationSink()

  let outputLog = SARIFLog()
  var merger = SARIFLogMerger(into: outputLog, sink: sink)

  let inputLog1 = try loadSARIFLog(named: "test.sarif", sink: sink)
  try merger.merge(from: inputLog1)
  let inputLog2 = try loadSARIFLog(named: "test.sarif", sink: sink)
  try merger.merge(from: inputLog2)

  // We don't handle `defaultConfiguration` yet.
  withKnownIssue {
    expectJSON(expected: inputLog1, actual: outputLog)
  }
}
