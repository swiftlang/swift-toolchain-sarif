public import Foundation

extension ArtifactLocation {
  public func mappingURL(mappings: [URLBaseMapping]) -> ArtifactLocation {
    if self.uriBaseId != nil {
      // Already have a base
      return self
    }
    for mapping in mappings {
      if let relativeURL = self.uri.relativeTo(base: mapping.prefix) {
        return .init(uri: relativeURL, uriBaseId: mapping.baseId)
      }
    }

    return self
  }
}

/// Maps a URL prefix to a named `baseId`.
public struct URLBaseMapping {
  public let baseId: String
  public let prefix: URL

  public init(baseId: String, prefix: URL) {
    self.baseId = baseId
    self.prefix = prefix
  }
}

/// A URL that has been mapped based on a list of ``URLBaseMapping``s.
public struct MappedURL: Hashable, Sendable {
  /// The mapped URL.
  ///
  /// This will be relative if ``uriBaseId`` is present, and absolute if ``uriBaseId`` is nil.
  public let uri: URL
  /// The named base ID to which ``uri`` is relative, or nil if ``uri`` is absolute.
  public let uriBaseId: String?

  public init(uri: URL, uriBaseId: String?) {
    self.uri = uri
    self.uriBaseId = uriBaseId
  }
}

extension [URLBaseMapping] {
  /// Maps the specified URL according to the ``URLBaseMapping``s in the array.
  ///
  /// The URL will be mapped to the first ``URLBaseMapping`` whose prefix is a
  /// prefix of the URL. If the URL does not match any of the mappings, the result
  /// will contain the original URL with a nil ``uriBaseId``.
  public func mapURL(_ url: URL) -> MappedURL {
    for mapping in self {
      if let relativeURL = url.relativeTo(base: mapping.prefix) {
        return .init(uri: relativeURL, uriBaseId: mapping.baseId)
      }
    }

    return .init(uri: url, uriBaseId: nil)
  }
}

extension URL {
  fileprivate func relativeTo(base: URL) -> URL? {
    guard self.scheme == base.scheme else {
      return nil
    }

    let destComponents = self.pathComponents
    let baseComponents = base.pathComponents
    for (destComponent, baseComponent) in zip(destComponents, baseComponents) {
      guard destComponent == baseComponent else {
        return nil
      }
    }

    let relativePath = self.pathComponents.dropFirst(baseComponents.count)
      .joined(separator: "/")
    return URL(string: relativePath)
  }
}

extension SARIFLog {
  /// Update all artifact locations based on the specified URL base mappings.
  public func mapURLs(with mappings: [URLBaseMapping]) {
    self.runs.forEach { run in
      run.artifacts.forEach { artifact in
        if var location = artifact.location,
          location.uriBaseId == nil
        {
          let mappedURL = mappings.mapURL(location.uri)
          location.uri = mappedURL.uri
          location.uriBaseId = mappedURL.uriBaseId
          artifact.location = location
        }
      }
    }
  }
}
