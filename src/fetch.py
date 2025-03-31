#!/usr/bin/env python3
import glob
import os
import sys
import threading
import time
import signal
from functools import partial
from common import CommonUtils
from pathlib import Path
from hashlib import file_digest
from urllib.parse import urlsplit
from urllib.request import build_opener, install_opener, urlopen, urlretrieve
from email.message import Message
from typing import List, Tuple
from concurrent.futures import ThreadPoolExecutor, as_completed


# fmt: off
class ResourceFetcher(object):
  def __init__(self, package_file_path: str):
    self.start_time = {}
    self.last_update = {}
    self.package_file: str = package_file_path

  def fetch_resource(self) -> List[Tuple[str, str, str, str]]:
    print(f"\nParsing: {self.package_file}")
    stage: str = self.package_file.split(os.path.sep)[1]
    toml_package = CommonUtils.toml_read(self.package_file)
    package_info = CommonUtils.parse_package_toml_no_deps(toml_package)

    with ThreadPoolExecutor(thread_name_prefix="fetcher") as executor:
      futures = []
      for source_name, source_info in package_info.sources.items():
        source_path = Path("fetch").joinpath(stage, package_info.name)
        source_path.mkdir(parents=True, exist_ok=True)

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
          futures.append(executor.submit(self.fetch_and_verify, source_name, url, filepath, source_info.hash, file))

      for future in as_completed(futures):
        err = future.result()
        if err:
          executor.shutdown(cancel_futures=True)
          return [err]
        
    return []

  def fetch_and_verify(self, source_name: str, url: str, filepath: Path, expected_hash: str, file: str) -> Tuple[str, str, str, str]:
    print(f"{time.strftime('%H:%M:%S')} Validating: {source_name}")

    if filepath.is_file():
      if self.verify(filepath, expected_hash):
        return None

      print("Hash mismatch, removing file and retrying:", filepath)
      os.remove(filepath)

    print(f"Downloading: {file}")
    print(f"Mirror: {url}")
    try:
      self.download(url, filepath)
    except:
      print(f"Failed downloading from mirror: {url}")
      return (file, expected_hash, url, "download_failed")

    if not self.verify(filepath, expected_hash):
      return (file, expected_hash, url, "verify_download")

    return None

  def download_status_hook(self, file: str):
    def hook (count: int, block_size: int, total_size: int):
      if count == 0:
        self.start_time[file] = time.time() - 0.001 # avoid division by zero
        return

      duration = time.time() - self.start_time[file]
      progress_size = int(count * block_size)
      speed = int(progress_size / (1024 * duration))

      percentage = ""
      if total_size > 0:
        percent = min(int((count * block_size * 100) / total_size), 100)
        percentage = f"{percent}%, "

      if file in self.last_update and time.time() - self.last_update[file] < 1 and (total_size < 0 or percent < 100):
        return

      print(
        f"{time.strftime('%H:%M:%S')} {file}: {percentage}{progress_size / (1024 * 1024)} MB, "
        f"{speed} KB/s, {duration:.3f} seconds passed"
      )

      self.last_update[file] = time.time()

    return hook

  def download(self, url: str, filename: str = None):
    if not filename:
      remotefile = urlopen(url)
      filename_header = remotefile.info()["Content-Disposition"]
      if filename_header:
        msg = Message()
        msg["content-disposition"] = filename_header
        filename = msg.get_filename()
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
      opener.addheaders = [("Accept", "*/*"), ("User-agent", "Wget/1.21.3 (linux-gnu)")]
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
        print(f"{time.strftime('%H:%M:%S')} Failed: {fail}")
      exit(1)
