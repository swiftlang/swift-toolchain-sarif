public import SARIF

public protocol RunObjectFactory {
  associatedtype ArtifactKey: Hashable
  associatedtype RuleKey: Hashable

  func makeArtifact(key: ArtifactKey, in builder: RunBuilder<Self>) throws
    -> Artifact
  func makeRule(key: RuleKey, in builder: RunBuilder<Self>) throws -> Rule
}

/// Helper to create a ``Run`` in terms of client objects, rather than SARIF objects.
///
/// The client supplies an implementation of ``RunObjectFactory`` to translate the client representation
/// of artifacts and rules into the SARIF definitions of those objects. The SARIF objects are created on demand
/// and cached based on the identity of the client object. This relieves the client from the responsibility of
/// tracking which client objects have already been translated to SARIF objects.
public final class RunBuilder<ObjectFactory: RunObjectFactory> {
  public typealias ArtifactKey = ObjectFactory.ArtifactKey
  public typealias RuleKey = ObjectFactory.RuleKey

  public let run: Run
  private let factory: ObjectFactory
  private var artifacts: [ArtifactKey: Artifact] = [:]
  private var rules: [RuleKey: Rule] = [:]
  private var results: [ArtifactLocation: Result] = [:]

  public init(for run: Run, factory: ObjectFactory) {
    self.run = run
    self.factory = factory
  }

  /// Get the SARIF ``Artifact`` for the specified client artifact.
  ///
  /// If the client artifact has already been translated in a previous call to ``getArtifact(forKey:)``,
  /// the result of the previous translation is returned. Otherwise, this function returns a new instance
  /// of ``Artifact`` created by a call to ``RunObjectFactory.makeArtifact(key:in:)``.
  ///
  /// The returned ``Artifact`` is added to the list of rules for the ``Run``.
  public func getArtifact(forKey key: ArtifactKey) throws -> Artifact {
    let artifact = try getObject(
      \.artifacts, key: key, makeObject: self.factory.makeArtifact)
    self.run.artifacts.append(artifact)
    return artifact
  }

  /// Get the SARIF ``Rule`` for the specified client artifact.
  ///
  /// If the client rule has already been translated in a previous call to ``getRule(forKey:)``,
  /// the result of the previous translation is returned. Otherwise, this function returns a new instance
  /// of ``Rule`` created by a call to ``RunObjectFactory.makeRule(key:in:)``.
  ///
  /// The returned ``Rule`` is added to the list of rules for the driver.
  public func getRule(forKey key: RuleKey) throws -> Rule {
    let rule = try getObject(
      \.rules, key: key, makeObject: self.factory.makeRule)
    self.run.tool.driver.rules.append(rule)
    return rule
  }

  private func getObject<Key: Hashable, Object: AnyObject>(
    _ map: ReferenceWritableKeyPath<RunBuilder, [Key: Object]>,
    key: Key, makeObject: (_ key: Key, _ builder: RunBuilder) throws -> Object
  ) throws -> Object {
    if let object = self[keyPath: map][key] {
      return object
    } else {
      let object = try makeObject(key, self)
      self[keyPath: map][key] = object
      return object
    }
  }

  /// Creates a new ``Result`` and adds it to the ``Run``.
  public func addResult(
    rule: RuleKey, artifact: ArtifactKey,
    logicalLocations: [LogicalLocation] = [], messageText: String,
    kind: Result.Kind? = nil
  ) throws -> Result {
    let ruleObject = try getRule(forKey: rule)
    let result = self.run.addResult(rule: ruleObject, messageText: messageText)
    if let kind {
      result.kind = kind
    }

    // Add all logical locations and their ancestors to the run.
    for logicalLocation in logicalLocations {
      var ancestor = logicalLocation
      while true {
        self.run.logicalLocations.append(ancestor)
        if let parent = ancestor.parent {
          ancestor = parent
        } else {
          break
        }
      }
    }

    let artifact = try self.getArtifact(forKey: artifact)
    let location = Location(
      at: PhysicalLocation(
        artifactLocation: ArtifactLocationReference(to: artifact)),
      logicalLocations: logicalLocations)
    result.locations.append(location)

    return result
  }
}
