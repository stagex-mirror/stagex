#!/usr/bin/env python3
import os
import json
from common import CommonUtils
from common import PackageInfo
from common import digests
from typing import Any
from typing import List
from typing import MutableMapping
from dataclasses import replace
from urllib.parse import urlsplit
from glob import glob
from os.path import isfile
from subprocess import check_output

class MatrixGenerator(object):
  def __init__(self):
    self.packages: MutableMapping[str, MutableMapping[str, PackageInfo]] = dict[str, MutableMapping[str, PackageInfo]]()
    self.digests = digests()
    self.init_packages("packages")
    self.resolve_versions()

    self.matrix = {}

    for stage, stage_packages in self.packages.items():
      for name, package in stage_packages.items():
        self.matrix[f"{stage}-{name}"] = {
          "name": package.name,
          "stage": stage,
          "digest": package.digest,
          "deps": package.deps,
          "version": package.version,
        }

  def dict(self):
    return self.matrix

  def json(self):
    print(json.dumps([
      value for key, value in self.matrix.items()
    ]))


  def init_packages(self, root_path: str = "packages"):
    for base_dir, sub_dirs, file_list in os.walk(root_path):
      for file_name in file_list:
        if file_name == "Containerfile":
          container_file_path = os.path.join(base_dir, file_name)
          _, stage, name, _ = container_file_path.split(os.path.sep)
          package_data: MutableMapping[str, Any] | None = None
          if stage not in self.packages:
            self.packages[stage] = dict[str, PackageInfo]()

          try:
            package_data = CommonUtils.toml_read(f"{root_path}/{stage}/{name}/package.toml")
          except FileNotFoundError:
            continue

          deps: List[str] = list()
          with open(container_file_path, "r") as file:
            for line in file:
              if line.startswith("COPY"):
                first_arg = line.split(" ")[1]
                if first_arg.startswith("--from"):
                  _, dep = first_arg.split("=")
                  if dep.startswith("stagex/"):
                    deps.append(dep.split("/")[1])
              if line.startswith("FROM stagex/"):
                deps.append(line.split(" ")[1].split("/")[1].strip())
              if line.startswith("FROM --platform=linux/386 stagex/"):
                deps.append(line.split(" ")[2].split("/")[1].strip())

          package_info = CommonUtils.parse_package_toml_no_deps(package_data)
          package_info.deps = list(set(deps))
          if len(package_info.subpackages):
            for subpackage in package_info.subpackages:
              self.packages[stage][subpackage] = replace(package_info)
              self.packages[stage][subpackage].origin = package_info.name
              self.packages[stage][subpackage].name = subpackage
              self.packages[stage][subpackage].subpackages = []
              self.packages[stage][subpackage].digest = self.digests.get("{stage}-{subpackage}", None)
          else:
            self.packages[stage][name] = package_info
            self.packages[stage][name].digest = self.digests.get(f"{stage}-{name}", None)
    self.resolve_versions()

  # Small util function to resolve "version_from" in package info
  def resolve_versions(self):
    for stage in self.packages:
      for package_name in self.packages[stage]:
        if self.packages[stage][package_name].version_from:
          # If we have a "version_from" in package info, grab the version from the target and set it
          target_stage, target_name = self.packages[stage][package_name].version_from.split("-")
          self.packages[stage][package_name].version = self.packages[target_stage][target_name].version


if __name__ == "__main__":
  mg = MatrixGenerator()
  mg.json()
