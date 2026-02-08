#!/usr/bin/env python3
import os
import tomlkit
from common import CommonUtils
from typing import MutableMapping
from github_matrix import MatrixGenerator


def add_dep(doc: tomlkit.TOMLDocument, dep: str):
  section = doc['package']
  deps_field = section.setdefault('deps', tomlkit.array())
  deps_field.append(dep)

def add_makedep(doc: tomlkit.TOMLDocument, dep: str):
  section = doc['package']
  deps_field = section.setdefault('makedeps', tomlkit.array())
  deps_field.append(dep)


# Load the dependency data
mg =  MatrixGenerator()
deps = mg.dict()

# Iterate over all package.tomls
for base_dir, sub_dirs, file_list in os.walk("packages"):
  for file_name in file_list:
    # We only care about Contaienrfile and package.toml, specifically in that order
    if file_name != "Containerfile":
      continue

    container_file_path = os.path.join(base_dir, file_name)
    _, stage, name, _ = container_file_path.split(os.path.sep)
    doc = None
    try:
      with open(f"packages/{stage}/{name}/package.toml", 'r', encoding='utf-8') as f:
        content = f.read()
      doc = tomlkit.parse(content)

      # Get current package data
    except FileNotFoundError:
      continue

    package_details = deps.get(f"{stage}-{name}")

    subpackages = doc.get('package', {}).get('subpackages', None)

    if not package_details and not subpackages:
      print(f"No package details for {stage}-{name}?")
      continue

    if not package_details and subpackages:
      package_deps = set()
      for subpackage in subpackages:
        package_deps.update(deps[f"{stage}-{subpackage}"].get('deps', []))
    else:
      # Now that we have the data we need to write the deps, make_deps and run_deps lists
      package_deps = deps[f"{stage}-{name}"].get('deps', [])

    for dep in package_deps:
      if dep == "core-filesystem":
        add_makedep(doc, dep)
      elif dep == "core-profile":
        add_makedep(doc, dep)
      elif dep.startswith("pallet-"):
        add_makedep(doc, dep)
      else:
        add_dep(doc, dep)

    package_string = tomlkit.dumps(doc)

    with open(f"packages/{stage}/{name}/package.toml", 'w', encoding='utf-8') as f:
        f.write(package_string)

