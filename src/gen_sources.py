#!/bin/python3
import glob
import re
import sys
import time
import json
from urllib.parse import urlsplit
from urllib.request import urlopen, urlretrieve
from email.message import Message

replacements = {
    "\n":"",
    "ENV ":"",
    "ARG ":"",
    "ADD --checksum=sha256:":"",
    "${":"{",
}

def replace_all(text, rep_dict):
    for i, j in rep_dict.items():
        text = text.replace(i, j)
    return text

queue = []
for filename in glob.glob('packages/**/Containerfile', recursive=True):
    file = open(filename)
    line_list = file.readlines(1)
    env_dict = { "TARGET": "x86_64"}
    add_list = []
    while line_list:
        line = line_list[0]
        if line.startswith("ADD --checksum"):
            line_parts = replace_all(line, replacements).split(" ")
            if line_parts[2] == ".":
                line_parts[2] = None
            add_dict = {}
            add_dict["hash"] = line_parts[0]
            add_dict["url"] = line_parts[1]
            add_dict["filename"] = line_parts[2]
            add_list.append(add_dict)
        elif line.startswith("ENV ") or line.startswith("ARG "):
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
        line_list = file.readlines(1)
    env_dict_formatted = {}
    for key,value in env_dict.items():
        try:
            env_dict_formatted[key] = value.format(**env_dict)
        except:
            print("Error: unable to format: %s -> %s" % (filename,line))
            sys.exit()
    sources_dict = {}
    for add_dict in add_list:
        for key,value in add_dict.items():
            if value is not None:
                add_dict[key] = value.format(**env_dict)
        if not add_dict['filename']:
            url = add_dict['url'].format(**env_dict_formatted)
            print(url)
            remotefile = urlopen(url)
            filename_header = remotefile.info()['Content-Disposition']
            if filename_header:
                msg = Message()
                msg['content-disposition'] = filename_header
                add_dict['filename'] = msg.get_filename()
            if not add_dict['filename']:
                split = urlsplit(add_dict['url'])
                add_dict['filename'] = split.path.split("/")[-1]
        add_dict['filename'] = add_dict['filename'].format(**env_dict)
        sources_dict[add_dict['filename']] = {}
        sources_dict[add_dict['filename']]['mirrors'] = [add_dict['url']]
    with open(filename.replace("Containerfile","sources.json"),"w") as outfile:
        json.dump(sources_dict,outfile,indent=4)
        print(json.dumps(sources_dict, indent=4))
