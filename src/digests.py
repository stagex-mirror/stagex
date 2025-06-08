#!/usr/bin/env python3
import json
import operator
from glob import glob
from os import mkdir
from shutil import rmtree
from typing import List
from typing import MutableMapping
from typing import Tuple

digests: MutableMapping[str, List[Tuple[str, str]]] = dict[str, List[Tuple[str, str]]]()

for filename in glob("out/**/index.json", recursive=True):
    fullname = filename.split("/")[1]
    stage = fullname.split("-")[0]
    name = "-".join(fullname.split("-")[1:])
    if stage not in digests:
        digests[stage] = list()
    # Get index digest from index file
    with open(filename) as file:
        data = json.load(file)
    digest = data["manifests"][0]["digest"].split(":")[1]

    # Get manifest digest from index 
    with open(f"out/{fullname}/blobs/sha256/{digest}") as file:
      data = json.load(file)
    for manifest in data["manifests"]:
      digest = manifest["digest"].split(":")[1]
      os = manifest["platform"]["os"]
      arch = manifest["platform"]["architecture"]
      digests[stage].append((name, digest, os, arch))

rmtree("digests")
mkdir("digests")
for stage, elements in digests.items():
    filename = f"digests/{stage}.txt"
    with open(filename, "a") as file:
        for element in sorted(elements, key=operator.itemgetter(0)):
            file.write(f"{element[1]} {stage}-{element[0]}-{element[2]}-{element[3]}\n")
    print(f"> {filename}"),
