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
{name}: out/rootfs/{stage}-{name}/manifest.txt
{stage}-{name}: out/rootfs/{stage}-{name}/manifest.txt
out/rootfs/{stage}-{name}/manifest.txt: \\
\t{files} {deps}
\trm -rf out/rootfs/{stage}-{name} && \\
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
\t  --build-arg BUILDKIT_MULTI_PLATFORM=1 \\
\t  --build-arg "BUILDKIT_DOCKERFILE_CHECK=skip=FromPlatformFlagConstDisallowed;error=true" \\
\t  --output \\
\t    type=local,dest=out/rootfs/{stage}-{name} \\
\t  {context_args} \\
\t  {dep_env_args} \\
\t  {build_args} \\
\t  $(EXTRA_ARGS) \\
\t  $(NOCACHE_FLAG) \\
\t  $(CHECK_FLAG) \\
\t  --platform={platform_arg} \\
\t  --progress=$(PROGRESS) \\
\t  -f packages/{stage}/{origin}/Containerfile \\
\t  packages/{stage}/{origin} && \\
\tfor plat in out/rootfs/{stage}-{name}/linux_*; do \\
\t  [ -d "$$plat" ] && bash src/fixrootfs.sh "$$plat"; \\
\tdone && \\
\t(cd out/rootfs/{stage}-{name} && find . -type f ! -name manifest.txt -exec sha256sum {{}} + | sort -k2) > out/rootfs/{stage}-{name}/manifest.txt
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

.PHONY: oci-{stage}-{name}
oci-{stage}-{name}: out/oci/{stage}-{name}/index.json

out/oci/{stage}-{name}/index.json: out/rootfs/{stage}-{name}/manifest.txt
\trm -rf out/oci/{stage}-{name} && \\
\tbash src/mkoci.sh \\
\t  out/rootfs/{stage}-{name} \\
\t  out/oci/{stage}-{name} \\
\t  stagex/{stage}-{name} \\
\t  {version}

.PHONY: publish-{stage}-{name}
publish-{stage}-{name}: oci-{stage}-{name}
\t [ "$(RELEASE)" != "0" ] || {{ echo "Error: RELEASE is not set"; exit 1; }}
\t index_digest="$$(jq -r '.manifests[0].digest | split(":")[1]' out/oci/{stage}-{name}/index.json)"; \\
\t digest="$$(jq -r '.manifests[0].digest | split(":")[1]' out/oci/{stage}-{name}/blobs/sha256/$${{index_digest}})"; \\
\t signum="$$(ls -1 signatures/stagex/{stage}-{name}@sha256=$${{digest}} | wc -l )"; \\
\t [ $${{signum}} -ge 2 ] || {{ echo "Error: Minimum signatures not met for {stage}-{name}"; exit 1; }}; \\
\t env -C out/oci/{stage}-{name} tar -cf - . | docker load
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
    self.init_packages("packages")
    self.resolve_versions()

    for stage, stage_packages in self.packages.items():
      print(f"\n\n.PHONY: oci-{stage}\noci-{stage}:", end="")
      for name, _ in stage_packages.items():
        print(f" \\\n\t oci-{name}", end="")

    print("\n\n.PHONY: oci-all\noci-all:", end="")

    for stage, stage_packages in self.packages.items():
      for name, _ in stage_packages.items():
        print(f" \\\n\t oci-{name}", end="")

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

        # Generate import.env for this package (parsed from its Containerfile)
        # Skip bootstrap packages - their ENV vars are build-specific
        if stage != "bootstrap":
          origin = package.origin or package.name
          self.generate_import_env(stage, name, origin)

        print(
          TargetGenerator.TARGET_TEMPLATE.format(
            **{
              "stage": stage,
              "name": name,
              "origin": package.origin or package.name,
              "version": package.version or "latest",
              "deps": "".join(
                f" \\\n\tout/rootfs/{dep}/manifest.txt" for dep in package.deps
              ),
              "files": "\\\n\t".join(check_output(["find","packages/{}/{}".format(stage,package.origin or package.name),"-type","f","-not","-path","*/fetch/*"],text=True).splitlines()),
              "build_args": TargetGenerator.get_build_args(package),
              "dep_env_args": self.get_dep_env_args(package),
              "context_args": self.get_context_args(package, stage, package.origin or package.name, False),
              "context_args_registry": self.get_context_args(package, stage, package.origin or package.name, True),
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
          has_package_stage = False
          with open(container_file_path, "r") as file:
            for line in file:
              if line.startswith("COPY"):
                first_arg = line.split(" ")[1]
                if first_arg.startswith("--from"):
                  _, dep = first_arg.split("=")
                  if dep.startswith("stagex/"):
                    deps.append(dep.split("/")[1].strip())
              if line.startswith("FROM stagex/"):
                deps.append(line.split(" ")[1].split("/")[1].strip())
              if line.startswith("FROM --platform=linux/386 stagex/"):
                deps.append(line.split(" ")[2].split("/")[1].strip())
              # Check for a bare "package" stage (not package-*)
              if " AS package" in line and " AS package-" not in line:
                has_package_stage = True

          package_info = CommonUtils.parse_package_toml_no_deps(package_data)
          package_info.deps = deps
          package_info.has_package_stage = has_package_stage
          if len(package_info.subpackages):
            # Only create main package target if Containerfile has a "package" stage
            if has_package_stage:
              self.packages[stage][name] = package_info
            # Always create subpackage targets
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


  def get_context_args(self, package: PackageInfo, stage: str, name: str, use_registry: bool) -> str:
    args: List[str] = list()
    args.append(f"--build-context fetch=fetch/{stage}/{name}")
    for dep in package.deps:
      if use_registry:
        args.append(f"--build-context stagex/{dep}=docker-image://$(REGISTRY_USERNAME)/{dep}")
      else:
        # Find the dependency's platform to construct correct subdirectory path
        dep_stage, dep_platform = self.get_dep_platform(dep)
        if dep_platform == "$(PLATFORM)":
          # Use Make substitution for Make-variable platforms
          args.append(f"--build-context stagex/{dep}=out/rootfs/{dep}/$(subst /,_,$(PLATFORM))")
        elif dep_platform:
          dep_dir = dep_platform.replace("/", "_")
          args.append(f"--build-context stagex/{dep}=out/rootfs/{dep}/{dep_dir}")
        else:
          args.append(f"--build-context stagex/{dep}=out/rootfs/{dep}")
    return " \\\n\t  ".join(args)

  def get_dep_platform(self, dep_name: str) -> tuple[str, str]:
    """Find a dependency's stage and platform. Returns (stage, platform) or (None, None)."""
    # dep_name is like "bootstrap-stage0", split into stage="bootstrap", name="stage0"
    dep_stage, dep_pkg_name = dep_name.split("-", 1)
    for stage, stage_packages in self.packages.items():
      for pkg_name, pkg in stage_packages.items():
        if pkg_name == dep_pkg_name and stage == dep_stage:
          platform = "$(PLATFORM)"
          if len(pkg.platforms) > 0:
            platform = pkg.platforms[0]  # Use first platform for single-platform builds
          return stage, platform
    return None, None

  def parse_containerfile_env(self, containerfile_path: str) -> dict[str, str]:
    """Parse ENV directives from a Containerfile's package stage chain.
    
    Returns ENV vars that would be active in the 'package' stage (the rootfs we provide).
    Tracks FROM...AS stage names and inherits ENV through the stage chain.
    """
    env_vars: dict[str, str] = {}
    current_stage: str = ""
    stage_envs: dict[str, dict[str, str]] = {}
    stage_parents: dict[str, str] = {}
    package_stage: str | None = None
    
    try:
      with open(containerfile_path, "r") as f:
        for line in f:
          stripped = line.strip()
          
          # Track FROM...AS stage definitions
          if stripped.startswith("FROM "):
            parts = stripped.split()
            current_stage = ""
            for i, part in enumerate(parts):
              if part == "AS" and i + 1 < len(parts):
                current_stage = parts[i + 1]
                break
            # Store parent of previous stage
            if stage_envs and not current_stage:
              prev_stage = list(stage_envs.keys())[-1]
              stage_parents[prev_stage] = ""
            elif current_stage and stage_envs:
              prev_stage = list(stage_envs.keys())[-1]
              stage_parents[current_stage] = prev_stage
            
            # Check if this is the package stage
            if current_stage == "package" or (current_stage and current_stage.startswith("package-")):
              package_stage = current_stage
            
            # Initialize env for this stage (inherits from parent)
            if current_stage and current_stage in stage_parents:
              parent = stage_parents[current_stage]
              stage_envs[current_stage] = dict(stage_envs.get(parent, {}))
            else:
              stage_envs[current_stage] = {}
          
          # Parse ENV directives
          elif stripped.startswith("ENV ") and current_stage in stage_envs:
            env_part = stripped[4:].strip()
            if "=" not in env_part:
              continue
            key, _, value = env_part.partition("=")
            key = key.strip()
            value = value.strip().strip('"').strip("'")
            stage_envs[current_stage][key] = env_vars[key] = value
    
    except FileNotFoundError:
      pass
    
    # Return ENV from the package stage (or last stage if no explicit package stage)
    if package_stage and package_stage in stage_envs:
      return stage_envs[package_stage]
    if stage_envs:
      return stage_envs[list(stage_envs.keys())[-1]]
    return env_vars

  def filter_env_vars(self, env_vars: dict[str, str]) -> dict[str, str]:
    """Filter out Docker build-time variables and build-local vars from ENV."""
    # Docker's special build-time args - they resolve differently per build
    docker_vars = {
      "TARGETARCH", "TARGETPLATFORM", "TARGETVARIANT",
      "HOSTARCH", "HOSTPLATFORM", "BUILDPLATFORM",
      "BUILDARG", "BUILDKIT_CONTEXT", "BUILDKIT_DOCKERFILE",
    }
    # Build-local vars that should NOT be inherited by dependents
    build_local_vars = {
      "CC", "CXX", "CPP", "FC", "LD", "AR", "RANLIB",
      "CFLAGS", "CXXFLAGS", "CPPFLAGS", "LDFLAGS", "FFLAGS",
      "PKG_CONFIG_PATH", "CONFIGURE_FLAGS", "MAKEFLAGS",
      "DESTDIR", "PREFIX", "BINDIR", "LIBDIR", "INCDIR",
    }
    filtered: dict[str, str] = {}
    for var, value in env_vars.items():
      # Skip Docker special vars and build-local vars
      if var in docker_vars or var in build_local_vars:
        continue
      # Skip vars that reference Docker special args
      for dv in docker_vars:
        if "${" + dv + "}" in value or "$" + dv in value:
          # Value depends on Docker build-time arg, skip it
          break
      else:
        filtered[var] = value
    return filtered

  def generate_import_env(self, stage: str, name: str, origin: str):
    """Generate import.env file for a package from its Containerfile."""
    containerfile = f"packages/{stage}/{origin}/Containerfile"
    env_vars = self.parse_containerfile_env(containerfile)
    env_vars = self.filter_env_vars(env_vars)
    if not env_vars:
      return
    # Expand variable references (${VAR} or $VAR) in values
    expanded: dict[str, str] = {}
    for var, value in env_vars.items():
      # Iteratively expand references to already-known vars
      for _ in range(3):
        new_value = value
        for ref_var, ref_val in expanded.items():
          new_value = new_value.replace("${" + ref_var + "}", ref_val)
          new_value = new_value.replace("$" + ref_var, ref_val)
        value = new_value
      expanded[var] = value
    import_env_path = f"out/rootfs/{stage}-{name}/import.env"
    os.makedirs(os.path.dirname(import_env_path), exist_ok=True)
    with open(import_env_path, "w") as f:
      for var, value in expanded.items():
        f.write(f"{var}={value}\n")

  def get_dep_env_args(self, package: PackageInfo) -> str:
    """Generate --build-arg flags from dependencies' import.env files."""
    args: List[str] = []
    seen_vars: set[str] = set()
    
    for dep in package.deps:
      env_file = f"out/rootfs/{dep}/import.env"
      try:
        with open(env_file, "r") as f:
          for line in f:
            line = line.strip()
            if not line or "=" not in line:
              continue
            var, _, value = line.partition("=")
            var = var.strip()
            value = value.strip()
            # First dep wins for duplicate vars
            if var in seen_vars:
              continue
            seen_vars.add(var)
            # Escape $ for Make, then double-quote for shell
            value = value.replace("$", "$$")
            args.append(f"--build-arg {var}=\"{value}\"")
      except FileNotFoundError:
        pass
    
    return " \\\n\t  ".join(args)

  @staticmethod
  def get_build_args(package: PackageInfo) -> str:
    sources = package.sources
    args: List[str] = list()
    if package.origin:
        args.append(f"--target package-{package.name}")
    elif package.subpackages and package.has_package_stage:
        args.append("--target package")

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
