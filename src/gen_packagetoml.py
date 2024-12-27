#!/bin/python3
import glob
import sys
import toml
from pathlib import Path
from urllib.parse import urlsplit

replacements = {
    "\n":"",
    "ENV ":"",
    "ARG ":"",
    "ADD --checksum=sha256:":"",
    "${":"{",
}

skip_list = [
        'pallet',
        'bootstrap',
        'ca-certificates',
        'filesystem',
        'cross-x86_64',
        'glib'
]

def replace_all(text, rep_dict):
    for i, j in rep_dict.items():
        text = text.replace(i, j)
    return text

queue = []
for filename in glob.glob('packages/**/Containerfile', recursive=True):
    if any(name in filename for name in skip_list):
        continue
    line_list = []
    add_list = []
    env_dict = {}
    file = open(filename)
    file_read = file.readlines(1)
    while file_read:
        line_list.append(file_read[0])
        file_read = file.readlines(1)
    for line in line_list:
        if line.startswith("ENV ") or line.startswith("ARG "):
            line = replace_all(line, replacements)
            try:
                key,value = line.split("=",1)
            except:
                try:
                    key,value = line.split(" ",1)
                except:
                    print("Error: unable to split: %s" % (line))
                    sys.exit()
            env_dict[key] = value
    name = filename.split('/')[2]
    package = { "package": { "name": name, "version": "", "description": "TODO" },"sources": {} }
    package['package']['version'] = env_dict['VERSION']
    source_index = 0
    for line in line_list:
        if line.startswith("ADD --checksum"):
            line_parts = replace_all(line, replacements).split(" ")
            digest = line_parts[0].format(**env_dict)
            url = line_parts[1].format(**env_dict).format(**env_dict).format(**env_dict)
            if source_index == 0 and 'SRC_FILE' in env_dict:
                source_ext = env_dict['SRC_FILE'].split(".",1)[1]
                source_name = package['package']['name']
            else:
                source_name = line_parts[2].format(**env_dict).format(**env_dict)
                if source_name == '.':
                    source_filename = urlsplit(url).path.split("/")[-1]
                    try:
                        source_ext_list = Path(source_filename).suffixes[-2:]
                        if source_ext_list[0] == '.tar':
                            source_ext = "".join(source_ext_list)[1:]
                        else:
                            source_ext = source_ext_list[-1][1:]
                    except:
                        source_ext = ""
                    if source_ext:
                        source_name = source_filename.split("/")[-1].split("-",1)[0]
                    else:
                        source_name = source_filename
            source_file = source_name + "-{version}.{format}"
            source_ext = source_ext.replace("src.","")
            package['sources'][source_name] = {
                "hash":digest,
                "format": source_ext,
                "file": source_file,
                "mirrors":[
                    url.replace(package['package']['version'],"{version}").replace(source_ext,"{format}").replace(source_file,"{file}")
                ]
            }
            if source_ext:
                package['sources'][source_name]["format"] = source_ext
            source_index += 1
    with open(filename.replace("Containerfile","package.toml"),"w") as outfile:
         toml.dump(package,outfile)
