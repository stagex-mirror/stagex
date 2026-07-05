#!/usr/bin/env python3
import os
from common import CommonUtils
from common import PackageInfo
from typing import Any
from typing import List
from typing import MutableMapping
from dataclasses import replace
from urllib.parse import urlsplit
from glob import glob
from os.path import isfile
from subprocess import check_output

class TargetGenerator(object):
  TARGET_TEMPLATE = """
.PHONY: {name} {stage}-{name}
{name}: out/{stage}-{name}/index.json
{stage}-{name}: out/{stage}-{name}/index.json
{mode_deps_block}
out/{stage}-{name}/index.json: \\
\t{files} {deps}
\trm -rf out/{stage}-{name} && \\
\tmkdir -p out/{stage}-{name} && \\
\tmkdir -p fetch/{stage}/{origin} && \\
\tpython3 src/fetch.py {origin} && \\
\t rm -rf packages/{stage}/{origin}/fetch && \\
\t mkdir -p packages/{stage}/{origin}/fetch && \\
\t ( [ -z "$$(ls -A fetch/{stage}/{origin})" ] || \\
\t   cp -lR fetch/{stage}/{origin}/* packages/{stage}/{origin}/fetch ) && \\
\t$(BUILDER) \\
\t  build \\
\t  --ulimit nofile=2048:16384 \\
\t  --tag stagex/{stage}-{name}:{version} \\
\t  --provenance=false \\
\t  --build-arg SOURCE_DATE_EPOCH=1 \\
\t  --build-arg BUILD_MODE=$(MODE) \\
\t  --build-arg BUILDKIT_MULTI_PLATFORM=1 \\
\t  --build-arg "BUILDKIT_DOCKERFILE_CHECK=skip=FromPlatformFlagConstDisallowed;error=true" \\
\t  --output \\
\t    name={stage}-{name},type=oci,rewrite-timestamp=true,force-compression=true,annotation.containerd.io/distribution.source.docker.io=stagex/{stage}-{name},annotation.org.opencontainers.image.version={version},annotation.org.opencontainers.image.created=1970-01-01T00:00:01Z,tar=true,dest=- \\
\t  {context_args} \\
\t  {build_args} \\
\t  $(EXTRA_ARGS) \\
\t  $(NOCACHE_FLAG) \\
\t  $(CHECK_FLAG) \\
\t  --platform={platform_arg} \\
\t  --progress=$(PROGRESS) \\
\t  -f packages/{stage}/{origin}/Containerfile \\
\t  packages/{stage}/{origin} \\
\t| tar -C out/{stage}-{name} -mx
\t
\t$(if $(filter $(IMPORT),1),$(call import,{stage},{name},{version}),)

.PHONY: import-{stage}-{name}
import-{stage}-{name}:
\t$(call import,{stage},{name},{version})

# use: make registry-{stage}-{name} BUILDER="docker buildx" REGISTRY_USERNAME=127.0.0.1:5005/stagex
# doesn't work well with docker build
.PHONY: registry-{stage}-{name}
registry-{stage}-{name}:
\tmkdir -p fetch/{stage}/{origin} && \\
\tpython3 src/fetch.py {origin} && \\
\t rm -rf packages/{stage}/{origin}/fetch && \\
\t mkdir -p packages/{stage}/{origin}/fetch && \\
\t ( [ -z "$$(ls -A fetch/{stage}/{origin})" ] || \\
\t   cp -lR fetch/{stage}/{origin}/* packages/{stage}/{origin}/fetch ) && \\
\t$(BUILDER) \\
\t  build \\
\t  --ulimit nofile=2048:16384 \\
\t  --tag $(REGISTRY_USERNAME)/{stage}-{name}:{version} \\
\t  --tag $(REGISTRY_USERNAME)/{stage}-{name}:latest \\
\t  --provenance=false \\
\t  --build-arg SOURCE_DATE_EPOCH=1 \\
\t  --build-arg BUILD_MODE=$(MODE) \\
\t  --build-arg BUILDKIT_MULTI_PLATFORM=1 \\
\t  --build-arg "BUILDKIT_DOCKERFILE_CHECK=skip=FromPlatformFlagConstDisallowed;error=true" \\
\t  --output \\
\t    name={name},type=image,rewrite-timestamp=true,annotation.org.opencontainers.image.version={version},push=true \\
\t  {context_args_registry} \\
\t  {build_args} \\
\t  $(EXTRA_ARGS) \\
\t  $(NOCACHE_FLAG) \\
\t  $(CHECK_FLAG) \\
\t  --platform={platform_arg} \\
\t  --progress=$(PROGRESS) \\
\t  -f packages/{stage}/{origin}/Containerfile \\
\t  packages/{stage}/{origin}

.PHONY: publish-{stage}-{name}
publish-{stage}-{name}: out/{stage}-{name}/index.json
\t [ "$(RELEASE)" != "0" ] || {{ echo "Error: RELEASE is not set"; exit 1; }}
\t index_digest="$$(jq -r '.manifests[0].digest | split(":")[1]' out/{stage}-{name}/index.json)"; \\
\t digest="$$(jq -r '.manifests[0].digest | split(":")[1]' out/{stage}-{name}/blobs/sha256/$${{index_digest}})"; \\
\t signum="$$(ls -1 signatures/stagex/{stage}-{name}@sha256=$${{digest}} | wc -l )"; \\
\t [ $${{signum}} -ge 2 ] || {{ echo "Error: Minimum signatures not met for {stage}-{name}"; exit 1; }}; \\
\t env -C out/{stage}-{name} tar -cf - . | docker load
\t docker tag stagex/{stage}-{name}:{version} stagex/{stage}-{name}:latest
\t docker tag stagex/{stage}-{name}:latest stagex/{stage}-{name}:sx$(RELEASE)
\t docker tag stagex/{stage}-{name}:{version} quay.io/stagex/{stage}-{name}:latest
\t docker tag stagex/{stage}-{name}:{version} quay.io/stagex/{stage}-{name}:{version}
\t docker tag stagex/{stage}-{name}:latest quay.io/stagex/{stage}-{name}:sx$(RELEASE)
\t$(call push-image,stagex/{stage}-{name}:{version})
\t$(call push-image,stagex/{stage}-{name}:sx$(RELEASE))
\t$(call push-image,stagex/{stage}-{name}:latest)
\t$(call push-image,quay.io/stagex/{stage}-{name}:{version})
\t$(call push-image,quay.io/stagex/{stage}-{name}:sx$(RELEASE))
\t$(call push-image,quay.io/stagex/{stage}-{name}:latest)

"""

  def __init__(self):
    self.packages: MutableMapping[str, MutableMapping[str, PackageInfo]] = dict[str, MutableMapping[str, PackageInfo]]()
    # Populated during init_packages: any package that ever appears as
    # `FROM --platform=$BUILDPLATFORM stagex/<pkg>` somewhere in the tree.
    # Under MODE=cross these packages build at the build host's arch so
    # the consuming stage can pull them via BUILDPLATFORM without qemu.
    self.host_referenced_deps: set[str] = set()
    self.init_packages("packages")
    self.resolve_versions()

    for stage, stage_packages in self.packages.items():
      print(f"\n\n.PHONY: {stage}\n{stage}:", end="")
      for name, _ in stage_packages.items():
        print(f" \\\n\t {name}", end="")

    print("\n\n.PHONY: all\nall:", end="")

    for stage, stage_packages in self.packages.items():
      for name, _ in stage_packages.items():
        print(f" \\\n\t {name}", end="")

    print("\n\n.PHONY: publish\npublish:", end="")

    for stage, stage_packages in self.packages.items():
      for name, _ in stage_packages.items():
        print(f" \\\n\t publish-{stage}-{name}", end="")

    for stage, stage_packages in self.packages.items():
      for name, package in stage_packages.items():
        platform = "$(PLATFORM)"
        # Force platform(s) for bootstrap packages which are only available for certain architectures
        # and later cross-compile subsequent stages for the user's desired platform
        if len(package.platforms) > 0:
          platform = ",".join(package.platforms)

        # If any Containerfile references this package as
        # `FROM --platform=$BUILDPLATFORM stagex/<pkg>`, it's a build tool
        # that expects to run at the host's arch. Under MODE=cross we
        # honor that and pin its build to $(BUILD_PLATFORM); MODE=native
        # keeps the requested target arch. Deps in the scan set are
        # stored under the full `<stage>-<name>` form used in
        # Containerfile FROMs (e.g. `bootstrap-stage3`).
        if f"{stage}-{name}" in self.host_referenced_deps or name in self.host_referenced_deps:
          platform = f"$(if $(filter cross,$(MODE)),$(BUILD_PLATFORM),{platform})"

        # All deps stay tracked in make regardless of mode. Buildkit
        # gets --build-context for every dep so it can resolve either
        # mode's FROM chain. The host_referenced scan above already
        # pins bootstrap tools to $(BUILD_PLATFORM) under MODE=cross,
        # so mode-cross builds never cascade to target-arch bootstrap
        # rebuilds.
        merged_extra_deps = list(package.deps_native_only) + list(package.deps_cross_only)
        deps_block_extra = "".join(
          f" \\\n\tout/{dep}/index.json" for dep in merged_extra_deps
        )
        target = f"out/{stage}-{name}/index.json"
        mode_deps_block = (
          f"{target}: {deps_block_extra}" if deps_block_extra else ""
        )

        print(
          TargetGenerator.TARGET_TEMPLATE.format(
            **{
              "stage": stage,
              "name": name,
              "origin": package.origin or package.name,
              "version": package.version or "latest",
              "deps": "".join(
                f" \\\n\tout/{dep}/index.json" for dep in package.deps
              ),
              "mode_deps_block": mode_deps_block,
              "files": "\\\n\t".join(check_output(["git","ls-files","packages/{}/{}".format(stage,package.origin or package.name)],text=True).splitlines()),
              "build_args": TargetGenerator.get_build_args(package),
              "context_args": TargetGenerator.get_context_args(package, stage, package.origin or package.name, False),
              "context_args_registry": TargetGenerator.get_context_args(package, stage, package.origin or package.name, True),
              "platform_arg": platform
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
            package_data = CommonUtils.toml_read(f"{root_path}/{stage}/{name}/package.toml")
          except FileNotFoundError:
            continue

          deps: List[str] = list()
          deps_native_only: List[str] = list()
          deps_cross_only: List[str] = list()
          mode_aware: bool = False
          current_stage: str = ""

          def _classify(dep: str):
            # `base-native` and `base-cross` are the mode-aware entry stages;
            # anything referenced there only appears when that mode is
            # selected, so it isn't a required dep in the other mode.
            if current_stage == "base-native":
              deps_native_only.append(dep)
            elif current_stage == "base-cross":
              deps_cross_only.append(dep)
            else:
              deps.append(dep)

          with open(container_file_path, "r") as file:
            for line in file:
              stripped = line.strip()
              if stripped.startswith("ARG BUILD_MODE"):
                mode_aware = True
              if line.startswith("FROM"):
                if " AS " in line:
                  current_stage = line.split(" AS ")[1].strip()
                else:
                  current_stage = ""
              if line.startswith("COPY"):
                first_arg = line.split(" ")[1]
                copy_platform = None
                # `COPY --platform=X --from=stagex/...`
                if first_arg.startswith("--platform="):
                  copy_platform = first_arg.split("=", 1)[1]
                  first_arg = line.split(" ")[2]
                if first_arg.startswith("--from"):
                  _, dep = first_arg.split("=")
                  if dep.startswith("stagex/"):
                    dep_name = dep.split("/")[1]
                    _classify(dep_name)
                    # Only an explicit `--platform=$BUILDPLATFORM` marks
                    # the dep as host-referenced. Without an explicit
                    # tag, COPY inherits the current stage's platform,
                    # but the semantic intent is ambiguous - the dep
                    # could be host-arch tools or target-arch content.
                    # Force consumers to be explicit.
                    if copy_platform == "$BUILDPLATFORM":
                      self.host_referenced_deps.add(dep_name)
              if line.startswith("FROM stagex/"):
                _classify(line.split(" ")[1].split("/")[1].strip())
              # Any `FROM --platform=<X> stagex/<pkg>` — the platform value
              # can be `linux/386` (stage2 xbuild), `$BUILDPLATFORM` (cross
              # mode), or any other buildkit-legal string.
              if line.startswith("FROM --platform="):
                platform_val = line.split(" ")[1].split("=", 1)[1]
                dep = line.split(" ")[2]
                if dep.startswith("stagex/"):
                  dep_name = dep.split("/")[1].strip()
                  _classify(dep_name)
                  # A ref via `$BUILDPLATFORM` says: whoever consumes this
                  # needs it at the build host's arch. Mark it so its own
                  # build rule can honor that under MODE=cross.
                  if platform_val == "$BUILDPLATFORM":
                    self.host_referenced_deps.add(dep_name)

          package_info = CommonUtils.parse_package_toml_no_deps(package_data)
          package_info.deps = deps
          package_info.mode_aware = mode_aware
          package_info.deps_native_only = deps_native_only
          package_info.deps_cross_only = deps_cross_only
          if len(package_info.subpackages):
            for subpackage in package_info.subpackages:
              self.packages[stage][subpackage] = replace(package_info)
              self.packages[stage][subpackage].origin = package_info.name
              self.packages[stage][subpackage].name = subpackage
              self.packages[stage][subpackage].subpackages = []
          else:
            self.packages[stage][name] = package_info
    self.resolve_versions()


  # Small util function to resolve "version_from" in package info
  def resolve_versions(self):
    for stage in self.packages:
      for package_name in self.packages[stage]:
        if self.packages[stage][package_name].version_from:
          # If we have a "version_from" in package info, grab the version from the target and set it
          target_stage, target_name = self.packages[stage][package_name].version_from.split("-")
          self.packages[stage][package_name].version = self.packages[target_stage][target_name].version


  @staticmethod
  def get_context_args(package: PackageInfo, stage: str, name: str, use_registry: bool) -> str:
    args: List[str] = list()
    args.append(f"--build-context fetch=fetch/{stage}/{name}")
    # Emit build contexts for every potentially-referenced dep. Buildkit
    # only wires the ones the selected mode actually references, so the
    # extras from the unused mode-branch are harmless.
    all_deps = list(package.deps) + list(package.deps_native_only) + list(package.deps_cross_only)
    for dep in all_deps:
      if use_registry:
        args.append(f"--build-context stagex/{dep}=docker-image://$(REGISTRY_USERNAME)/{dep}")
      else:
        args.append(f"--build-context stagex/{dep}=oci-layout://./out/{dep}")
    return " \\\n\t  ".join(args)

  @staticmethod
  def get_build_args(package: PackageInfo) -> str:
    sources = package.sources
    args: List[str] = list()
    if package.origin:
        args.append(f"--target package-{package.name}")

    if package.version:
        args.append(f"--build-arg VERSION={package.version}")
        args.append(f"--build-arg VERSION_UNDER={package.version_under}")
        args.append(f"--build-arg VERSION_DASH={package.version_dash}")
        args.append(f"--build-arg VERSION_MAJOR={package.version_major}")
        args.append(f"--build-arg VERSION_MAJOR_MINOR={package.version_major_minor}")
        args.append(f"--build-arg VERSION_STRIP_SUFFIX={package.version_strip_suffix}")

    for source_name, source_info in sources.items():
        source_format = source_info.format
        mirrors = source_info.mirrors
        urlfile = urlsplit(mirrors[0]).path.split("/")[-1]
        # We assume that version == "" means no version was provided in toml
        if source_info.version != "":
            args.append(f"--build-arg {source_name.upper()}_VERSION={source_info.version}")
            file = source_info.file if source_info.file != "" else urlfile
            file = file.format(
                    version=source_info.version,
                    version_dash=package.version_dash,
                    version_under=package.version_under,
                    format=source_format,
                )
            args.append(f"--build-arg {source_name.upper()}_SOURCE={file}")
        if source_info.git_sha:
            args.append(f"--build-arg {source_name.upper()}_GIT_SHA={source_info.git_sha}")

    return " \\\n\t  ".join(args)


if __name__ == "__main__":
  tg = TargetGenerator()
