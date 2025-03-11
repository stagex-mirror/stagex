import tomllib
from dataclasses import dataclass
from dataclasses import field
from typing import Any
from typing import List
from typing import Mapping
from typing import MutableMapping


@dataclass()
class WithVersion(object):
  version: str = field(default_factory=str)

  @property
  def version_under(self) -> str:
    return CommonUtils.version_to_under(self.version) if self.version else ""

  @property
  def version_dash(self) -> str:
    return CommonUtils.version_to_dash(self.version) if self.version else ""

  @property
  def version_major(self) -> str:
    return CommonUtils.version_to_major(self.version) if self.version else ""

  @property
  def version_major_minor(self) -> str:
    return CommonUtils.version_to_major_minor(self.version) if self.version else ""

  @property
  def version_strip_suffix(self) -> str:
    return CommonUtils.version_strip_suffix(self.version) if self.version else ""

@dataclass(kw_only=True)
class SourcesInfo(WithVersion):
  hash: str
  format: str
  file: str
  mirrors: List[str] = field(default_factory=list)


@dataclass(kw_only=True)
class PackageInfo(WithVersion):
  name: str
  origin: str = None
  platforms: List[str] = field(default_factory=list)
  subpackages: List[str] = field(default_factory=list)
  sources: MutableMapping[str, SourcesInfo] = field(default_factory=dict)
  deps: List[str] = field(default_factory=list)



class CommonUtils(object):
  @staticmethod
  def version_to_under(version: str) -> str:
    return version.replace(".", "_")

  @staticmethod
  def version_to_dash(version: str) -> str:
    return version.replace(".", "-")

  @staticmethod
  def version_to_major(version: str) -> str:
    parts = version.split(".")
    return parts[0]

  @staticmethod
  def version_to_major_minor(version: str) -> str:
    parts = version.split(".")
    if len(parts) >= 2:
        return ".".join(parts[:2])

  @staticmethod
  def version_strip_suffix(version: str) -> str:
    parts = s.rsplit("-", 1)
    return parts[0]

  @staticmethod
  def toml_read(filename: str) -> dict[str, Any]:
    with open(filename, "rb") as f_in:
      return tomllib.load(f_in)

  @staticmethod
  def parse_package_toml_no_deps(toml_dict: MutableMapping[str, Any]) -> PackageInfo:
    version: str = toml_dict["package"].get("version", None)
    name: str = toml_dict["package"]["name"]
    origin: str = None
    platforms: list = toml_dict["package"].get("platforms",[])
    subpackages: list = toml_dict["package"].get("subpackages",[])
    sources_toml: Mapping[str, Mapping[str, str | List[str]]] = toml_dict.get("sources", None)
    source_info: MutableMapping[str, SourcesInfo] = dict[str, SourcesInfo]()
    if sources_toml is not None:
      for source_name, source_description in sources_toml.items():
        source_info[source_name] = SourcesInfo(
          hash=source_description["hash"],
          format=source_description.get("format", ""),
          file=source_description.get("file", ""),
          mirrors=source_description["mirrors"],
          version=source_description.get("version", ""))
    return PackageInfo(name=name, origin=origin, subpackages=subpackages, version=version, platforms=platforms, sources=source_info, deps=list())

