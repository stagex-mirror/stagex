# StageX Package Configuration Format

## Overview

The `package.toml` file defines package metadata and source information for packages in the StageX operating system. It uses the TOML (Tom's Obvious, Minimal Language) format to specify package details, dependencies, and source locations.

## File Format

The package.toml file consists of two main sections:

### [package] Section

The `[package]` section contains basic package metadata:

- **name** - The package name (string, required)
- **version** - The package version (string, required)  
- **description** - A brief description of the package (string, required)
- **license** - Software license(s) for the package in SPDX identifier format (array of strings, required)
- **website** - Homepage or project URL (string, optional)
- **subpackages** - List of subpackages included with this package (array of strings, optional)

### [sources.*] Section

The `[sources.*]` section defines source download information. The section name follows the pattern `[sources.SOURCE_NAME]` where SOURCE_NAME typically matches the package name.

- **hash** - SHA-256 hash of the source archive (string, required)
- **version** - The package version, will be inherited from the package when not set (string, optional)  
- **format** - Archive format, such as "tar.gz", "tar.xz", etc. (string, required)
- **file** - Filename template with placeholders (string, required)
- **mirrors** - Array of download URLs with placeholders (array of strings, required)

## Placeholders

Template strings in **file** and **mirrors** fields support the following placeholders:

- **{version}** - Replaced with the package version
- **{version_major}** - Replaced with the major version number (e.g. X.Y.Z -> X)
- **{version_major_minor}** - Replaced with the major and minor version number (e.g. X.Y.Z -> X.Y)
- **{version_dash}** - Replaced with the dash version (e.g. X.Y.Z -> X-Y-Z)
- **{version_strip_suffix}** - Replaced with non-candidate version (e.g. X.Y.Z-rc.1 -> X.Y.Z)
- **{version_under}** - Replaced with a snake case version number (e.g. X.Y.Z -> X_Y_Z)
- **{format}** - Replaced with the archive format


## Examples

### Basic package with single source:

```toml
[package]
name = "nodejs"
version = "24.0.2"
description = "Evented I/O for V8 javascript ('Current' release)"
license = ["MIT"]
url = "https://nodejs.org/"

[sources.nodejs]
hash = "db699b535192419b02f35668aadd48f4d80e99b8ef807997df159bcf15a5e6b9"
format = "tar.gz"
file = "nodejs-{version}.{format}"
mirrors = [ "https://nodejs.org/dist/v{version}/node-v{version}.{format}",]
```

### Package with subpackages:

```toml
[package]
name = "linux"
version = "6.6"
description = "Linux kernel"
url = "https://linux.org/"
license = ["GPL-2.0-only"]
subpackages = ["linux-generic","linux-airgap","linux-server","linux-guest","linux-guest-net","linux-nitro","gen_initramfs"]

[sources.linux]
hash = "d926a06c63dd8ac7df3f86ee1ffc2ce2a3b81a2d168484e76b5b389aba8e56d0"
format = "tar.xz"
file = "linux-{version}.{format}"
mirrors = [ "http://mirrors.edge.kernel.org/pub/linux/kernel/v{version_major}.x/linux-{version}.{format}",]
```

## Notes

- All hash values should be SHA-256 checksums in hexadecimal format
- Mirror URLs should be reliable and publicly accessible
- Version placeholders are expanded during package processing
- The sources section name should typically match the package name for consistency

# Authors

Danny Grove <danny@drgrovellc.com>
