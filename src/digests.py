#!/usr/bin/env python3
from glob import glob
import json
import operator
from os import mkdir
from shutil import rmtree

digests = {}
for filename in glob("out/**/index.json", recursive=True):
    fullname = filename.split("/")[1]
    stage = fullname.split("-")[0]
    name = "-".join(fullname.split("-")[1:])
    if stage not in digests:
        digests[stage] = []
    with open(filename) as file:
        data = json.load(file)
    digest = data["manifests"][0]["digest"].split(":")[1]
    digests[stage].append((name, digest))

rmtree("digests")
mkdir("digests")
for stage, elements in digests.items():
    filename = "digests/%s.txt" % stage
    with open(filename, "a") as file:
        for element in sorted(elements, key=operator.itemgetter(0)):
            file.write("%s %s-%s\n" % (element[1], stage, element[0]))
    print("> %s" % filename),
