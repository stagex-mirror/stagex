#!/usr/bin/env python3
import tomllib
from glob import glob
from urllib.parse import urlsplit


def toml_read(filename: str):
    with open(filename, "rb") as f_in:
        return tomllib.load(f_in)


def get_packages():
    packages = {}
    for filename in glob("packages/**/Containerfile", recursive=True):
        _, stage, name, _ = filename.split("/")
        if stage not in packages:
            packages[stage] = {}
        try:
            package_data = toml_read("packages/%s/%s/package.toml" % (stage, name))
        except FileNotFoundError:
            continue
        version = package_data["package"].get("version", None)
        deps = []
        with open(filename, "r") as file:
            for line in file:
                if line.startswith("COPY"):
                    first_arg = line.split(" ")[1]
                    if first_arg.startswith("--from"):
                        _, dep = first_arg.split("=")
                        if dep.startswith("stagex/"):
                            deps.append(dep.split("/")[1])
                if line.startswith("FROM stagex/"):
                    deps.append(line.split(" ")[1].split("/")[1])
        packages[stage][name] = {}
        packages[stage][name]["deps"] = deps
        packages[stage][name]["version"] = version
        packages[stage][name]["sources"] = package_data.get("sources", [])
    return packages


def get_build_args(package):
    sources = package["sources"]
    version = package["version"]
    version_under = None
    version_dash = None
    args = []
    if version:
        version_under = version.replace(".", "_")
        version_dash = version.replace(".", "-")
        args.append("--build-arg VERSION=%s" % (version))
        args.append("--build-arg VERSION_UNDER=%s" % (version_under))
        args.append("--build-arg VERSION_DASH=%s" % (version_dash))
    for source in sources:
        format = sources[source].get("format", "")
        mirrors = sources[source]["mirrors"]
        urlfile = urlsplit(mirrors[0]).path.split("/")[-1]
        version = sources[source].get("version", version)
        if version:
            args.append("--build-arg %s_VERSION=%s" % (source.upper(), version))
            file = (
                sources[source]
                .get("file", urlfile)
                .format(
                    version=version,
                    version_dash=version_dash,
                    version_under=version_under,
                    format=format,
                )
            )
            args.append("--build-arg %s_SOURCE=%s" % (source.upper(), file))
    return " \\\n\t  ".join(args)


def get_context_args(package, stage, name):
    args = []
    args.append("--build-context fetch=fetch/%s/%s" % (stage, name))
    for dep in package["deps"]:
        args.append("--build-context stagex/%s=oci-layout://./out/%s" % (dep, dep))
    return " \\\n\t  ".join(args)


template = """
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
packages = get_packages()
for stage, stage_packages in packages.items():
    print("\n\n.PHONY: %s\n%s:" % (stage, stage), end="")
    for name, _ in stage_packages.items():
        print(" \\\n\t %s" % name, end="")
print("\n\n.PHONY: all\nall:", end="")
for stage, stage_packages in packages.items():
    for name, _ in stage_packages.items():
        print(" \\\n\t %s" % name, end="")
for stage, stage_packages in packages.items():
    for name, package in stage_packages.items():
        print(
            template.format(
                **{
                    "stage": stage,
                    "name": name,
                    "version": package["version"] or "latest",
                    "deps": "".join(
                        " \\\n\tout/%s/index.json" % dep for dep in package["deps"]
                    ),
                    "build_args": get_build_args(package),
                    "context_args": get_context_args(package, stage, name),
                }
            )
        )
