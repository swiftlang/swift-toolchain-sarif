import Foundation
import SARIF
import SARIFRecords
import SARIFTestUtilities
import Testing

@Test
func serializeEmpty() throws {
  let actual = SARIFLog()
  let expected = SARIFLogRecord(runs: [])
  expectJSON(expected: expected, actual: actual)
}

@Test
func serializeEmptyRun() throws {
  let actual = SARIFLog()
  actual.addRun(tool: Tool(driverName: "driver"))
  let expected = SARIFLogRecord(runs: [
    RunRecord(tool: ToolRecord(driver: ToolComponentRecord(name: "driver")))
  ])
  expectJSON(expected: expected, actual: actual)
}

@Test
func serializeWithDriverRules() throws {
  let actual = SARIFLog()
  let driver = ToolComponent(named: "driver")
  let rule1 = driver.addRule(id: "Don'tDoThat")
  let rule2 = driver.addRule(id: "Don'tDoThatEither")

  let run = actual.addRun(tool: Tool(driver: driver))

  run.addResult(rule: rule1, messageText: "Don't do that!")
  run.addResult(rule: rule1, messageText: "Don't do that!")
  run.addResult(rule: rule2, messageText: "Don't do that either!")

  let expected = SARIFLogRecord(
    runs: [
      .init(
        tool: .init(
          driver: .init(
            name: "driver",
            rules: [
              .init(id: rule1.id),
              .init(id: rule2.id),
            ]
          )
        ),
        results: [
          .init(
            message: .init(text: "Don't do that!"),
            ruleId: .init(fromComponents: rule1.id),
            ruleIndex: 0
          ),
          .init(
            message: .init(text: "Don't do that!"),
            ruleId: .init(fromComponents: rule1.id),
            ruleIndex: 0
          ),
          .init(
            message: .init(text: "Don't do that either!"),
            ruleId: .init(fromComponents: rule2.id),
            ruleIndex: 1
          ),
        ]
      )
    ]
  )

  expectJSON(expected: expected, actual: actual)
}
