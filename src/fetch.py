#!/usr/bin/python3
import glob
import os
import sys
import time
import signal
from functools import partial
from common import CommonUtils
from pathlib import Path
from hashlib import file_digest
from urllib.parse import urlsplit
from urllib.request import build_opener, install_opener, urlopen, urlretrieve
from email.message import Message
from typing import List
from typing import Tuple

# fmt: off
class ResourceFetcher(object):
  START_TIME: 0
  def __init__(self, package_file_path: str):
    self.package_file: str = package_file_path

  def fetch_resource(self) -> List[Tuple[str, str, str, str]]:
    print(f"\nParsing: {self.package_file}")
    stage: str = self.package_file.split(os.path.sep)[1]
    toml_package = CommonUtils.toml_read(self.package_file)
    package_info = CommonUtils.parse_package_toml_no_deps(toml_package)
    failed_fetch: List[Tuple[str, str, str, str]] = list[Tuple[str, str, str, str]]()
    for source_name, source_info in package_info.sources.items():
      print(f"\nValidating: {source_name}")

      source_path = Path("fetch").joinpath(stage, package_info.name)
      source_path.mkdir(parents=True, exist_ok=True)

      error = None
      for mirror in source_info.mirrors:
        urlfile = urlsplit(mirror).path.split(os.path.sep)[-1]
        if not source_info.version:
          # This is meant for in-memory mapping association of the Package-level version for the source if there
          # wasn't an explicit one set in the toml file.  This won't be permanently written to disk, but is only
          # mant to act as the override state during execution (i.e., if a source-level one isn't defined, use the
          # package level one as default).
          source_info.version = package_info.version

        file = (source_info.file if source_info.file else urlfile).format(
          version=source_info.version,
          version_under=source_info.version_under,
          version_dash=source_info.version_dash,
          format=source_info.format,
        )

        url = mirror.format(
          version=source_info.version,
          version_under=source_info.version_under,
          version_dash=source_info.version_dash,
          format=source_info.format,
          file=file,
        )

        filepath = source_path.joinpath(file)
        if filepath.is_file():
          if not ResourceFetcher.verify(filepath, source_info.hash):
            print("Failed verifying stored file, removing")
            filepath.unlink()
          else:
            break

        print(f"\nDownloading: {file}")
        print(f"Mirror: {url}")
        try:
          ResourceFetcher.download(url, filepath)
        except:
          error = (file, source_info.hash, url, "download")
          print("Failed downloading from mirror")
          continue
        if not ResourceFetcher.verify(filepath, source_info.hash):
          error = (file, source_info.hash, url, "verify_download")
          print("Failed verifying downloaded file")
          continue
        error = None
        break
      if error:
        failed_fetch.append(error)

    return failed_fetch

  @staticmethod
  def download_status_hook(count: int, block_size: int, total_size: int):
    if count == 0:
      ResourceFetcher.START_TIME = time.time()
      return

    duration = time.time() - ResourceFetcher.START_TIME
    progress_size = int(count * block_size)
    speed = int(progress_size / (1024 * duration))
    percent = int((count * block_size * 100) / total_size)
    sys.stdout.write(
      f"\r...{percent}%, {progress_size / (1024 * 1024)} MB, "
      f"{speed} KB/s, {duration} seconds passed\033[K"
    )
    sys.stdout.flush()

  @staticmethod
  def download(url: str, filename: str = None):
      if not filename:
          remotefile = urlopen(url)
          filename_header = remotefile.info()["Content-Disposition"]
          if filename_header:
              msg = Message()
              msg["content-disposition"] = filename_header
              filename = msg.get_filename()
          if not filename:
              split = urlsplit(url)
              filename = split.path.split(os.path.sep)[-1]
      opener = build_opener()
      opener.addheaders = [("User-agent", "Wget/1.21.3 (linux-gnu)")]
      install_opener(opener)
      urlretrieve(url, filename, ResourceFetcher.download_status_hook)

  @staticmethod
  def verify(file_path: Path, expected_digest: str) -> bool:
      if not file_path.is_file():
          return False

      with open(file_path, "rb") as f:
          return expected_digest == file_digest(f, "sha256").hexdigest()

def interrupt_handler(signum, frame, ask=True):
    print(f"Handling signal {signum} ({signal.Signals(signum).name}).")
    if ask:
        signal.signal(signal.SIGINT, partial(interrupt_handler, ask=False))
        print("To confirm interrupt, press ctrl-c again.")
        return

    print("Cleaning/exiting...")
    time.sleep(1)
    sys.exit(0)

if __name__ == "__main__":
  signal.signal(signal.SIGINT, interrupt_handler)
  package_files: List[str] = list()
  if len(sys.argv) > 1:
      packages = sys.argv[1:]
      for package in packages:
          package_files = package_files + glob.glob(
              f"packages/**/{package}/package.toml", recursive=True
          )
  else:
    for base_dir, _, file_list in os.walk("packages"):
      for file_name in file_list:
        if file_name == "package.toml":
          package_files.append(os.path.join(base_dir, file_name))

  for package_file in package_files:
    rf = ResourceFetcher(package_file)
    failed = rf.fetch_resource()
    print()
    if len(failed):
      for fail in failed:
        print(f"\nFailed: {fail}")
      exit(1)
