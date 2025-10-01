#!/usr/bin/env python3
import json
import os
import sys

def extract_digests(filepath: str) -> set[str]:
  digests: set[string] = set()
  with open(filepath) as file:
    data = json.load(file)
  for manifest in data["manifests"]:
    if manifest["mediaType"] == "application/vnd.oci.image.index.v1+json":
      digest = manifest.get('digest').split('sha256:')[1]
      digests = digests.union(extract_digests(f"{os.path.dirname(filepath)}/blobs/sha256/{digest}"))
    if manifest["mediaType"] == "application/vnd.oci.image.manifest.v1+json":
      digest = manifest.get('digest').split('sha256:')[1]
      platform = manifest.get('platform')
      digests.add(f"{digest} {platform.get('os')}/{platform.get('architecture')}")
  return digests

def main():
  if len(sys.argv) != 2:
    script_name = os.path.basename(sys.argv[0])
    print(f"Usage: {script_name} <image-name>")
    print(f"Example: {script_name} core-go")
    print("Error: Please provide exactly one argument.")
    sys.exit(1)

  image_name = sys.argv[1]
  filepath = f"out/{image_name}/index.json"
  digests = extract_digests(filepath)
  for digest in digests:
    print(digest)

if __name__ == "__main__":
  main()
