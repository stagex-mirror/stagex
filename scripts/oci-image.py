#!/usr/bin/env python3
"""
oci-image — pack a rootfs directory into a single-layer OCI image.

Produces an OCI Image Format 1.0.1 layout with one uncompressed layer blob,
matching the output structure of sloci-image but portable across macOS and
Linux using only the Python standard library.

Usage:
    oci-image [OPTIONS] ROOTFS NAME[:TAG]

Examples:
    oci-image /path/to/rootfs myimage:latest
    oci-image -a "Author <author@example.com>" -c /bin/sh rootfs/ myapp
"""

import argparse
import datetime
import gzip
import hashlib
import json
import os
import platform
import subprocess
import sys
import tarfile
import tempfile
from pathlib import Path


# ---------------------------------------------------------------------------
# OCI constants
# ---------------------------------------------------------------------------

OCI_LAYOUT_VERSION = "1.0.1"
MEDIA_TYPE_LAYER = "application/vnd.oci.image.layer.v1.tar+gzip"
MEDIA_TYPE_CONFIG = "application/vnd.oci.image.config.v1+json"
MEDIA_TYPE_MANIFEST = "application/vnd.oci.image.manifest.v1+json"
MEDIA_TYPE_INDEX = "application/vnd.oci.image.index.v1+json"


# ---------------------------------------------------------------------------
# Architecture mapping
# ---------------------------------------------------------------------------

ARCH_MAP = {
    "x86_64": "amd64",
    "amd64": "amd64",
    "aarch64": "arm64",
    "arm64": "arm64",
    "armv7l": "arm/v7",
    "armv6l": "arm/v6",
    "riscv64": "riscv64",
    "s390x": "s390x",
    "ppc64le": "ppc64le",
    "mips64": "mips64",
}


def detect_arch(override: str | None) -> str:
    """Return OCI-compatible architecture string."""
    if override:
        return override
    raw = platform.machine().lower()
    return ARCH_MAP.get(raw, raw)


# ---------------------------------------------------------------------------
# SHA256 helpers
# ---------------------------------------------------------------------------


def sha256_bytes(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def sha256_file(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


# ---------------------------------------------------------------------------
# Layer creation
# ---------------------------------------------------------------------------


def create_layer(rootfs: Path, layer_path: Path) -> tuple[str, int]:
    """
    Create a gzipped tar layer from *rootfs* and write it to *layer_path*.

    Returns (digest, size).
    """
    with gzip.GzipFile(
        layer_path, "wb", mtime=0
    ) as gz, tarfile.open(fileobj=gz, mode="w") as tar:
        for entry in sorted(rootfs.iterdir()):
            tar.add(str(entry), arcname=entry.name, recursive=True)

    digest = "sha256:" + sha256_file(layer_path)
    size = layer_path.stat().st_size
    return digest, size


# ---------------------------------------------------------------------------
# Config creation
# ---------------------------------------------------------------------------


def create_config(
    arch: str,
    os_: str,
    author: str | None,
    entrypoint: list[str] | None,
    cmd: list[str] | None,
    env: list[str] | None,
    user: str | None,
    working_dir: str | None,
    volumes: list[str] | None,
    ports: list[str] | None,
    labels: dict[str, str] | None,
    layer_diff_id: str,
    layer_digest: str,
    layer_size: int,
) -> tuple[str, bytes]:
    """
    Build an OCI image config JSON.

    Returns (digest, json_bytes).
    """
    now = datetime.datetime.now(datetime.timezone.utc).isoformat(
        timespec="microseconds"
    )

    config = {
        "User": user or "",
        "WorkingDir": working_dir or "",
        "Entrypoint": entrypoint,
        "Cmd": cmd,
        "Env": env or ["PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"],
        "Labels": labels,
    }

    if volumes:
        config["Volumes"] = {v: {} for v in volumes}

    if ports:
        exposed = {}
        for p in ports:
            if "/" in p:
                port, proto = p.rsplit("/", 1)
            else:
                port, proto = p, "tcp"
            exposed[f"{port}/{proto}"] = {}
        config["ExposedPorts"] = exposed

    history = []
    if author:
        history.append(
            {
                "created": now,
                "created_by": "oci-image",
                "author": author,
            }
        )
    else:
        history.append({"created": now, "created_by": "oci-image"})

    img = {
        "created": now,
        "architecture": arch,
        "os": os_,
        "config": config,
        "rootfs": {
            "type": "layers",
            "diff_ids": [layer_diff_id],
        },
        "history": history,
    }

    payload = json.dumps(img, indent=2) + "\n"
    digest = "sha256:" + sha256_bytes(payload.encode())
    return digest, payload.encode()


# ---------------------------------------------------------------------------
# Manifest + index
# ---------------------------------------------------------------------------


def build_manifest(
    config_digest: str,
    config_size: int,
    layer_digest: str,
    layer_size: int,
    arch: str,
    os_: str,
) -> bytes:
    manifest = {
        "schemaVersion": 2,
        "mediaType": MEDIA_TYPE_MANIFEST,
        "config": {
            "mediaType": MEDIA_TYPE_CONFIG,
            "digest": config_digest,
            "size": config_size,
        },
        "layers": [
            {
                "mediaType": MEDIA_TYPE_LAYER,
                "digest": layer_digest,
                "size": layer_size,
            }
        ],
        "platform": {
            "architecture": arch,
            "os": os_,
        },
    }
    return (json.dumps(manifest, indent=2) + "\n").encode()


def build_index(manifest_digest: str, manifest_size: int) -> bytes:
    index = {
        "schemaVersion": 2,
        "mediaType": MEDIA_TYPE_INDEX,
        "manifests": [
            {
                "mediaType": MEDIA_TYPE_MANIFEST,
                "digest": manifest_digest,
                "size": manifest_size,
            }
        ],
    }
    return (json.dumps(index, indent=2) + "\n").encode()


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Pack a rootfs into a single-layer OCI image.",
    )
    parser.add_argument("rootfs", help="Root filesystem directory or tar.gz archive")
    parser.add_argument(
        "name",
        help='Image name (optionally with :TAG, defaults to "latest")',
    )
    parser.add_argument("-a", "--author", default=None, help="Author name/email")
    parser.add_argument(
        "-C", "--entrypoint", nargs="+", default=None, help="Entrypoint arguments",
    )
    parser.add_argument(
        "-c", "--cmd", nargs="+", default=None, help="Default command arguments",
    )
    parser.add_argument(
        "-e", "--env", action="append", default=None, help="Environment VAR=VAL",
    )
    parser.add_argument("-u", "--user", default=None, help="Username or UID")
    parser.add_argument(
        "-w", "--working-dir", default=None, help="Working directory",
    )
    parser.add_argument(
        "-v", "--volume", action="append", default=None, help="Volume mount path",
    )
    parser.add_argument(
        "-p", "--port", action="append", default=None, help='Exposed port (e.g. 8080/tcp)',
    )
    parser.add_argument(
        "-l", "--label", action="append", default=None, help='Label KEY=VALUE',
    )
    parser.add_argument(
        "-m", "--arch", default=None, help="CPU architecture (default: auto-detect)",
    )
    parser.add_argument("--os", default="linux", help="OS (default: linux)")
    parser.add_argument(
        "-d", "--output", default=None, help="Output directory (default: <name>)",
    )
    parser.add_argument(
        "-t", "--tar", action="store_true", help="Pack output as tar archive",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)

    # Parse name:tag
    if ":" in args.name:
        image_name, tag = args.name.rsplit(":", 1)
    else:
        image_name = args.name
        tag = "latest"

    rootfs = Path(args.rootfs)
    if not rootfs.is_dir():
        print(f"error: {rootfs} is not a directory", file=sys.stderr)
        return 1

    arch = detect_arch(args.arch)
    output_dir = Path(args.output) if args.output else Path(image_name)
    blobs_dir = output_dir / "blobs" / "sha256"
    blobs_dir.mkdir(parents=True, exist_ok=True)

    # 1. Create layer
    layer_file = blobs_dir / "layer.tar.gz"
    layer_diff_id, layer_size = create_layer(rootfs, layer_file)
    layer_digest = "sha256:" + sha256_file(layer_file)

    # Rename layer to its digest
    layer_file.rename(blobs_dir / layer_digest.split(":")[1])

    # 2. Create config
    labels = {}
    if args.label:
        for lv in args.label:
            k, v = lv.split("=", 1)
            if k.startswith("."):
                k = f"org.opencontainers.image{k}"
            labels[k] = v

    config_digest, config_bytes = create_config(
        arch=arch,
        os_=args.os,
        author=args.author,
        entrypoint=args.entrypoint,
        cmd=args.cmd,
        env=args.env,
        user=args.user,
        working_dir=args.working_dir,
        volumes=args.volume,
        ports=args.port,
        labels=labels if labels else None,
        layer_diff_id=layer_diff_id,
        layer_digest=layer_digest,
        layer_size=layer_size,
    )
    config_file = blobs_dir / config_digest.split(":")[1]
    config_file.write_bytes(config_bytes)

    # 3. Build manifest
    manifest_bytes = build_manifest(
        config_digest=config_digest,
        config_size=len(config_bytes),
        layer_digest=layer_digest,
        layer_size=layer_size,
        arch=arch,
        os_=args.os,
    )
    manifest_digest = "sha256:" + sha256_bytes(manifest_bytes)
    manifest_size = len(manifest_bytes)
    manifest_file = blobs_dir / manifest_digest.split(":")[1]
    manifest_file.write_bytes(manifest_bytes)

    # 4. Build index
    index_bytes = build_index(
        manifest_digest=manifest_digest,
        manifest_size=manifest_size,
    )
    (output_dir / "index.json").write_bytes(index_bytes)

    # 5. Write oci-layout
    layout = {"imageLayoutVersion": OCI_LAYOUT_VERSION}
    (output_dir / "oci-layout").write_text(json.dumps(layout) + "\n")

    # 6. Optional: tar the whole layout
    if args.tar:
        tar_path = output_dir.with_suffix(".tar")
        with tarfile.open(tar_path, "w") as tar:
            for p in sorted(output_dir.rglob("*")):
                if p.is_file():
                    tar.add(str(p), arcname=str(p.relative_to(output_dir)))
        print(f"OCI image written to {tar_path}")
    else:
        print(f"OCI image written to {output_dir}")

    # Summary
    print(f"  name:     {image_name}:{tag}")
    print(f"  arch:     {arch}")
    print(f"  layer:    {layer_digest} ({layer_size} bytes)")
    print(f"  config:   {config_digest}")
    print(f"  manifest: {manifest_digest}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
