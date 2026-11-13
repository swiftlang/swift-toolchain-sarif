# SARIFRecords module

This module defines the raw JSON record types used in the SARIF format. This allows clients to deserialize, manipulate, and serialize SARIF files directly. It provides very little validation of the input or output JSON. Most clients should use the `SARIF` module, which provides higher-level abstractions, mutability, and much more thorough validation.

For each SARIF object type that is represented as a JSON object, this module defines an immutable, `Codable`, `Sendable` `struct` with all of the properties of that SARIF object type. Each `struct` defines an initializer that accepts a parameter corresponding to each property, with default values for optional properties and other properties with sensible defaults. Validation during deserialization is limited as follows:

- Any property that is optional in any context is treated as optional. For example, both the `uri` and the `index` properties of `ArtifactLocationRecord` are marked as optional, even though at least one of them must be present for any given `artifactLocation` object.
- Properties with names other than those specified in the SARIF specification are silently ignored.
- Constraints between multiple properties on the same object, or between multiple objects, are not enforced. For example, the `index` property of a `ToolComponentReferenceRecord` will be accepted even if there is no corresponding `ToolComponentRecord` with that index in the run.

For any property that is an integer or string that refers to another object in the log, that property is declared as a `struct` that conforms to `TypedID`, which is a strongly-typed wrapper around the underlying property type. This ensures that code does not accidentally treat a reference to a `reportingDescriptor` object as if it referred to a `toolComponent`, for example.

This module defines the `struct`s `HierarchicalString` and `VersionedHierarchicalString`, which represent the similarly-named string types from the SARIF specification. These `struct`s do validate the format of their strings during deserialization.
