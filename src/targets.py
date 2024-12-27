#!/usr/bin/env python3
import os
import tomllib
from dataclasses import dataclass
from dataclasses import field
from typing import Any
from typing import List
from typing import Mapping
from typing import MutableMapping
from urllib.parse import urlsplit


@dataclass
class SourcesInfo(object):
  hash: str
  format: str
  file: str
  mirrors: List[str] = field(default_factory=list)
  version: str = field(default_factory=str)


@dataclass
class PackageInfo(object):
  version: str
  sources: MutableMapping[str, SourcesInfo] = field(default_factory=dict)
  deps: List[str] = field(default_factory=list)


class TargetGenerator(object):
  TARGET_TEMPLATE = """
        .PHONY: {name} {stage}-{name}
        {name}: out/{stage}-{name}/index.json
        {stage}-{name}: out/{stage}-{name}/index.json
        out/{stage}-{name}/index.json: {deps}
        \trm -rf out/{stage}-{name} && \\
        \tmkdir -p out/{stage}-{name} && \\
        \tmkdir -p fetch/{stage}/{name} && \\
        \tpython3 src/fetch.py {name} && \\
        \t$(BUILDER) \\
        \t  build \\
        \t  --ulimit nofile=2048:16384 \\
        \t  --tag stagex/{stage}-{name}:{version} \\
        \t  --output \\
        \t    name={name},type=oci,rewrite-timestamp=true,force-compression=true,annotation.org.opencontainers.image.revision=$(shell git rev-list HEAD -1 packages/{stage}/{name}),annotation.org.opencontainers.image.version={version},tar=true,dest=- \\
        \t  {context_args} \\
        \t  {build_args} \\
        \t  $(EXTRA_ARGS) \\
        \t  $(NOCACHE_FLAG) \\
        \t  $(CHECK_FLAG) \\
        \t  --platform=$(PLATFORM) \\
        \t  --progress=$(PROGRESS) \\
        \t  -f packages/{stage}/{name}/Containerfile \\
        \t  packages/{stage}/{name} \\
        \t| tar -C out/{stage}-{name} -mx
        """

  def __init__(self):
    self.packages: MutableMapping[str, MutableMapping[str, PackageInfo]] = dict[str, MutableMapping[str, PackageInfo]]()
    self.init_packages("packages")

    for stage, stage_packages in self.packages.items():
      print(f"\n\n.PHONY: {stage}\n{stage}:", end="")
      for name, _ in stage_packages.items():
        print(f" \\\n\t {name}", end="")

    print("\n\n.PHONY: all\nall:", end="")

    for stage, stage_packages in self.packages.items():
      for name, _ in stage_packages.items():
        print(f" \\\n\t {name}", end="")

    for stage, stage_packages in self.packages.items():
      for name, package in stage_packages.items():
        print(
          TargetGenerator.TARGET_TEMPLATE.format(
            **{
              "stage": stage,
              "name": name,
              "version": package.version or "latest",
              "deps": "".join(
                f" \\\n\tout/{dep}/index.json" for dep in package.deps
              ),
              "build_args": TargetGenerator.get_build_args(package),
              "context_args": TargetGenerator.get_context_args(package, stage, name),
            }
          )
        )


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
            package_data = TargetGenerator.toml_read(f"{root_path}/{stage}/{name}/package.toml")
          except FileNotFoundError:
            continue

          version: str = package_data["package"].get("version", None)
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
                deps.append(line.split(" ")[1].split("/")[1])
          sources_toml: Mapping[str, Mapping[str, str | List[str]]] = package_data.get("sources", None)
          source_info: MutableMapping[str, SourcesInfo] = dict[str, SourcesInfo]()
          if sources_toml is not None:
            for source_name, source_description in sources_toml.items():
              source_info[source_name] = SourcesInfo(
                hash=source_description["hash"],
                format=source_description.get("format", ""),
                file=source_description.get("file", ""),
                mirrors=source_description["mirrors"],
                version=source_description.get("version", ""))
          self.packages[stage][name] = PackageInfo(version, source_info, deps)

  @staticmethod
  def get_context_args(package: PackageInfo, stage: str, name: str) -> str:
    args: List[str] = list()
    args.append(f"--build-context fetch=fetch/{stage}/{name}")
    for dep in package.deps:
      args.append(f"--build-context stagex/{dep}=oci-layout://./out/{dep}")
    return " \\\n\t  ".join(args)

  @staticmethod
  def get_build_args(package: PackageInfo) -> str:
    sources = package.sources
    package_version = package.version
    version_under = None
    version_dash = None
    args: List[str] = list()
    if package_version:
        version_under = package_version.replace(".", "_")
        version_dash = package_version.replace(".", "-")
        args.append(f"--build-arg VERSION={package_version}")
        args.append(f"--build-arg VERSION_UNDER={version_under}")
        args.append(f"--build-arg VERSION_DASH={version_dash}")

    for source_name, source_info in sources.items():
        source_format = source_info.format
        mirrors = source_info.mirrors
        urlfile = urlsplit(mirrors[0]).path.split("/")[-1]
        sources_version = source_info.version
        # We assume that version == "" means no version was provided in toml
        if sources_version != "":
            args.append(f"--build-arg {source_name.upper()}_VERSION={sources_version}")
            file = source_info.file if source_info.file != "" else urlfile
            file = file.format(
                    version=sources_version,
                    version_dash=version_dash,
                    version_under=version_under,
                    format=source_format,
                )
            args.append(f"--build-arg {source_name.upper()}_SOURCE={file}")
    return " \\\n\t  ".join(args)

  @staticmethod
  def toml_read(filename: str) -> dict[str, Any]:
    with open(filename, "rb") as f_in:
      return tomllib.load(f_in)


if __name__ == "__main__":
  tg = TargetGenerator()


