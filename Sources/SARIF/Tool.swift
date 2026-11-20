import Foundation
internal import SARIFRecords

internal struct ToolSaveContext {
  public let ruleMap: DefinitionSaveMap<Rule, RuleKey>
}

//@Mergeable
public final class Tool: JSONRepresentable<ToolRecord> {
  public var driver: ToolComponent
  public var extensions: [ToolComponent] = []

  public convenience init(driverName: String) {
    self.init(driver: ToolComponent(named: driverName))
  }

  public init(driver: ToolComponent) {
    self.driver = driver
  }

  internal init(
    from toolRecord: ToolRecord, sink: any ValidationSink,
    with context: RuleLoadMap
  )
    throws
  {
    self.driver = try ToolComponent(
      from: toolRecord.driver, sink: sink, with: context.driver)

    self.extensions = try (toolRecord.extensions ?? []).map {
      try ToolComponent(
        from: $0, sink: sink, with: context.addExtension(guid: $0.guid))
    }
  }

  internal func toJSON(with context: ToolSaveContext) throws -> ToolRecord {
    let driver = try self.driver.toJSON(
      with: ToolComponentSaveContext(
        extensionIndex: nil, ruleMap: context.ruleMap))
    let extensions = try self.extensions.ifNotEmpty?.enumerated().map {
      index, extensionComponent in
      try extensionComponent.toJSON(
        with: ToolComponentSaveContext(
          extensionIndex: ArrayIndex(index), ruleMap: context.ruleMap))
    }
    return ToolRecord(driver: driver, extensions: extensions)
  }
}
