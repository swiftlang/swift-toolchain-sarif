# swift-toolchain-sarif

The swift-toolchain-sarif package is a set of libraries for working with SARIF (Static Analysis Results Interchange Format) files, based on the the open standard available [here](https://docs.oasis-open.org/sarif/sarif/v2.1.0/sarif-v2.1.0.html). This package is used by the Swift front-end to generate SARIF files containing Swift diagnostics, and by the Swift driver to merge the SARIF files produced by multiple front-end invocations into a single SARIF file for each Swift module. This package can also be used by custom tools that need to manipulate SARIF files.

## Modules

The swift-toolchain-sarif package defines the following modules:

- `SARIFRecords` - Provides immutable types representing the raw JSON records of a SARIF file.
- `SARIF` - Provides a higher-level object model for a SARIF file, allowing mutation, more comprehensive validation, and resolution of cross-references between SARIF objects.
- `SARIFMerge` - Provides functions for merging multiple SARIF files into a single SARIF file, deduplicating results as needed.

More detailed documentation for each module can be found in a markdown file in that module's source directory.

## Releases

This package is changing rapidly as SARIF support is added to the rest of the Swift toolchain. There are not yet stable, semantically-versioned releases of this package. Once the package's API has stabilized, versioned releases will be made available.

## Contributing

To start contributing to swift-toolchain-sarif see, [this guide](CONTRIBUTING.md) for more information.

## License

Please see [LICENSE](LICENSE.txt) for more information.
