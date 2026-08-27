#!/usr/bin/env python3
"""provenance.py - compute the build-provenance document for an image target.

Usage: python3 src/provenance.py [target] [--raw|--embed]

Default target: distro-enclave-dev-img.

The document records where an image came from: the stagex source
package (origin URL with credentials stripped, branch, commit, dirty
flag) and, for every package in the target's transitive make dependency
closure, its name, version, and digests (sha256 of the package's
rootfs manifest, plus chained source-sentinel and OCI digests), along
with the DEPENDS_ON relationships of the make dependency graph.

--embed / --raw print the complete SPDX 2.3 (SPDXTagValue) document
(one Package per make package). The build generates this into the
distro's build context and COPYs it into the rootfs, where it is packed
into disk.img and installed at /provenance.spdx in the image. It is a
deterministic function of (commit, branch, origin, dependency digests),
so baking it in keeps the disk bit-reproducible. --raw is the same
document for local records and SPDX tooling.

The default (no flag) mode prints a compact document that binds the
closure by chained-sha256 Merkle roots (rootfsset/srcset/ociset) instead
of listing every package, for consumers with a small payload budget.

The document is quote-free by design (hex, paths, git refs, SPDX
keywords) so it can be interpolated into shell variables and HCL
strings safely.
"""
import hashlib
import os
import re
import subprocess
import sys
import tomllib
from datetime import datetime, timezone
from pathlib import Path

MANIFEST_SUFFIX = "/manifest.txt"
METADATA_SUFFIX = "/metadata.json"
SPDX_VERSION = "SPDX-2.3"
LICENSE_LIST_VERSION = "3.21"


def sha256_file(path):
  h = hashlib.sha256()
  with open(path, "rb") as f:
    for chunk in iter(lambda: f.read(1 << 20), b""):
      h.update(chunk)
  return h.hexdigest()


def git(*args):
  try:
    return subprocess.check_output(
      ["git"] + list(args), text=True, stderr=subprocess.DEVNULL
    ).strip()
  except Exception:
    return ""


def created_timestamp():
  # Deterministic: derived from SOURCE_DATE_EPOCH (pinned in the build)
  # rather than the wall clock, so the document is byte-stable across
  # rebuilds. The current time is not part of a build's identity.
  epoch = os.environ.get("SOURCE_DATE_EPOCH", "1")
  try:
    return datetime.fromtimestamp(int(epoch), tz=timezone.utc).strftime(
      "%Y-%m-%dT%H:%M:%SZ"
    )
  except Exception:
    return "1970-01-01T00:00:01Z"


def spdx_id(name):
  # SPDX IDs allow only letters, numbers, "." and "-" (no underscores).
  return "SPDXRef-" + re.sub(r"[^A-Za-z0-9.\-]", "-", name)


def parse_targets(path="out/targets.mk"):
  """Parse out/targets.mk.

  Returns (deps, sources):
    deps:    pkg -> [dep pkgs]        from the manifest.txt rules
    sources: pkg -> [source files]    from the metadata.json rules
  """
  deps = {}
  sources = {}
  with open(path) as f:
    lines = f.read().splitlines()
  i = 0
  n = len(lines)
  while i < n:
    line = lines[i]
    if line.startswith("out/rootfs/") and line.endswith(MANIFEST_SUFFIX + ": \\"):
      pkg = line[len("out/rootfs/"):-len(MANIFEST_SUFFIX + ": \\")]
      dep_list = []
      i += 1
      while (
        i < n
        and lines[i].startswith("\t")
        and not lines[i].startswith("\trm -rf")
      ):
        for tok in lines[i].split():
          if tok.startswith("out/rootfs/") and tok.endswith(MANIFEST_SUFFIX):
            dep_list.append(
              tok[len("out/rootfs/"):-len(MANIFEST_SUFFIX)]
            )
        i += 1
      deps[pkg] = dep_list
      continue
    if line.startswith("out/rootfs/") and line.endswith(METADATA_SUFFIX + ": \\"):
      pkg = line[len("out/rootfs/"):-len(METADATA_SUFFIX + ": \\")]
      src_list = []
      i += 1
      while (
        i < n
        and lines[i].startswith("\t")
        and not lines[i].startswith("\tmkdir")
      ):
        for tok in lines[i].split():
          tok = tok.rstrip("\\")
          if tok.startswith("packages/"):
            src_list.append(tok)
        i += 1
      sources[pkg] = src_list
      continue
    i += 1
  return deps, sources


def transitive_closure(target, deps):
  seen = set()
  stack = [target]
  while stack:
    pkg = stack.pop()
    if pkg in seen or pkg not in deps:
      continue
    seen.add(pkg)
    stack.extend(deps[pkg])
  return seen


def chained_sha(pairs):
  """sha256 over sorted (name, digest) pairs."""
  h = hashlib.sha256()
  for name, digest in sorted(pairs):
    h.update(name.encode())
    h.update(b" ")
    h.update(digest.encode())
    h.update(b"\n")
  return h.hexdigest()


def package_version(sources_map, pkg):
  """Version from the package's package.toml, if resolvable."""
  for path in sources_map.get(pkg, []):
    if path.endswith("package.toml"):
      try:
        with open(path, "rb") as f:
          data = tomllib.load(f)
        return data.get("package", {}).get("version", "") or ""
      except Exception:
        return ""
  return ""


def main():
  target = "distro-enclave-dev-img"
  raw = False
  embed = False
  for arg in sys.argv[1:]:
    if arg == "--raw":
      raw = True
    elif arg == "--embed":
      # Full document, embedded into the image at build time.
      raw = True
      embed = True
    else:
      target = arg
  deps, sources = parse_targets()

  closure = transitive_closure(target, deps)

  # Per-package digests.
  rootfs = {}
  src = {}
  oci = {}
  for pkg in closure:
    manifest = "out/rootfs/%s/manifest.txt" % pkg
    if os.path.isfile(manifest):
      rootfs[pkg] = sha256_file(manifest)
    index = "out/oci/%s/index.json" % pkg
    if os.path.isfile(index):
      oci[pkg] = sha256_file(index)
    srcs = []
    for path in sources.get(pkg, []):
      if os.path.isfile(path):
        srcs.append((path, sha256_file(path)))
    if srcs:
      src[pkg] = chained_sha(srcs)

  rootfsset = chained_sha([(p, d) for p, d in rootfs.items()])
  srcset = chained_sha([(p, d) for p, d in src.items()])
  ociset = chained_sha([(p, d) for p, d in oci.items()])

  origin = git("remote", "get-url", "origin")
  # Strip embedded credentials (user:token@host) from the origin URL.
  if "://" in origin and "@" in origin.split("://", 1)[1]:
    scheme, _, rest = origin.partition("://")
    origin = scheme + "://" + rest.split("@", 1)[1]
  branch = git("branch", "--show-current")
  commit = git("rev-parse", "HEAD")
  dirty = 1 if git("status", "--porcelain") else 0

  disk = "out/rootfs/%s/linux_amd64/disk.img" % target
  disk_sha = sha256_file(disk) if os.path.isfile(disk) else ""
  cf = "out/cache/containerfiles/%s.Containerfile" % target
  cf_sha = sha256_file(cf) if os.path.isfile(cf) else ""

  now = created_timestamp()
  img_id = spdx_id(target)

  header = [
    "# StageX build provenance - SPDX %s document" % SPDX_VERSION.replace("SPDX-", ""),
    "SPDXVersion: %s" % SPDX_VERSION,
    "DataLicense: CC0-1.0",
    "SPDXID: SPDXRef-DOCUMENT",
    "DocumentName: StageX build provenance (%s)" % target,
    "DocumentNamespace: https://codeberg.org/stagex/stagex/spdx/%s/%s"
    % (commit or "nogit", disk_sha or "nodisk"),
    "Creator: Tool: stagex-provenance-1",
    "Created: %s" % now,
    "LicenseListVersion: %s" % LICENSE_LIST_VERSION,
  ]

  source_pkg = [
    "PackageName: stagex",
    "SPDXID: %s" % spdx_id("stagex"),
    "PackageVersion: %s" % (commit or "NOASSERTION"),
    "PackageDownloadLocation: %s" % (origin or "NOASSERTION"),
    "FilesAnalyzed: false",
    "PackageLicenseConcluded: NOASSERTION",
    "PackageLicenseDeclared: NOASSERTION",
    "PackageComment: branch=%s dirty=%d" % (branch or "-", dirty),
  ]
  if origin:
    source_pkg.append("ExternalRef: OTHER git-of-origin %s" % origin)

  image_pkg = [
    "PackageName: %s" % target,
    "SPDXID: %s" % img_id,
    "PackageDownloadLocation: NOASSERTION",
    "FilesAnalyzed: false",
    "PackageLicenseConcluded: NOASSERTION",
    "PackageLicenseDeclared: NOASSERTION",
  ]
  if disk_sha:
    image_pkg.append("PackageChecksum: SHA256: %s" % disk_sha)
  if raw:
    image_pkg.append(
      "PackageComment: packages=%d containerfile=%s; complete per-package "
      "dependency graph (name, version, digest); %s"
      % (
        len(closure),
        cf_sha or "-",
        "embedded in image at build time" if embed else "SPDX record",
      )
    )
  else:
    image_pkg.append(
      "PackageComment: packages=%d containerfile=%s; rootfsset/srcset/ociset "
      "are chained sha256 Merkle roots over the make dependency closure"
      % (len(closure), cf_sha or "-")
    )

  set_pkgs = []
  for name, value, comment in [
    (
      "rootfsset",
      rootfsset,
      "chained sha256 over (package, sha256 of out/rootfs/<pkg>/manifest.txt) "
      "for all packages in the make dependency closure",
    ),
    (
      "srcset",
      srcset,
      "chained sha256 over (package, source-sentinel chain sha256 of "
      "Containerfile/package.toml/scripts/patches) for all packages in "
      "the make dependency closure",
    ),
    (
      "ociset",
      ociset,
      "chained sha256 over (package, sha256 of out/oci/<pkg>/index.json) "
      "for all built packages in the make dependency closure",
    ),
  ]:
    set_pkgs.append(
      [
        "PackageName: %s/%s" % (target, name),
        "SPDXID: %s" % spdx_id("%s-%s" % (target, name)),
        "PackageDownloadLocation: NOASSERTION",
        "FilesAnalyzed: false",
        "PackageLicenseConcluded: NOASSERTION",
        "PackageLicenseDeclared: NOASSERTION",
        "PackageChecksum: SHA256: %s" % value,
        "PackageComment: %s" % comment,
      ]
    )

  relationships = [
    "Relationship: SPDXRef-DOCUMENT DESCRIBES %s" % img_id,
    "Relationship: %s DEPENDS_ON %s" % (img_id, spdx_id("stagex")),
  ]

  sections = [header, source_pkg, image_pkg] + set_pkgs + [relationships]
  doc = "\n\n".join("\n".join(block) for block in sections) + "\n"

  if not raw:
    # EC2 user-data limit is 16 KB; leave headroom for the SSH key and
    # the marker lines.
    if len(doc) > 14 * 1024:
      sys.stderr.write(
        "provenance document too large for EC2 user-data: %d bytes\n"
        % len(doc)
      )
      sys.exit(1)
    sys.stdout.write(doc)
    return

  # --raw: the complete SPDX document, one Package per make package in
  # the closure, with the DEPENDS_ON relationships of the make graph.
  raw_sections = [header]
  raw_sections.append(source_pkg)
  raw_sections.append(image_pkg)
  for pkg in sorted(closure):
    if pkg == target:
      # Already emitted as image_pkg above (avoid a duplicate SPDXID).
      continue
    block = [
      "PackageName: %s" % pkg,
      "SPDXID: %s" % spdx_id(pkg),
      "PackageDownloadLocation: NOASSERTION",
      "FilesAnalyzed: false",
      "PackageLicenseConcluded: NOASSERTION",
      "PackageLicenseDeclared: NOASSERTION",
    ]
    version = package_version(sources, pkg)
    if version:
      block.append("PackageVersion: %s" % version)
    if pkg in rootfs:
      block.append("PackageChecksum: SHA256: %s" % rootfs[pkg])
    extras = []
    if pkg in src:
      extras.append("src=%s" % src[pkg])
    if pkg in oci:
      extras.append("oci=%s" % oci[pkg])
    if extras:
      block.append("PackageComment: %s" % " ".join(extras))
    raw_sections.append(block)
  raw_rels = [
    "Relationship: SPDXRef-DOCUMENT DESCRIBES %s" % img_id,
    "Relationship: %s DEPENDS_ON %s" % (img_id, spdx_id("stagex")),
  ]
  for pkg in sorted(closure):
    for dep in sorted(set(deps.get(pkg, [])) & closure):
      raw_rels.append(
        "Relationship: %s DEPENDS_ON %s" % (spdx_id(pkg), spdx_id(dep))
      )
  raw_sections.append(raw_rels)
  sys.stdout.write("\n\n".join("\n".join(block) for block in raw_sections) + "\n")


if __name__ == "__main__":
  main()
