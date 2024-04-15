#!/bin/python3
import glob
import re
import sys
import time
import json
from os.path import isfile, dirname
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

def json_read(filename: str):
    with open(filename) as f_in:
        return json.load(f_in)

def replace_all(text, rep_dict):
    for i, j in rep_dict.items():
        text = text.replace(i, j)
    return text

def download_status_hook(count, block_size, total_size):
    global start_time
    if count == 0:
        start_time = time.time()
        return
    duration = time.time() - start_time
    progress_size = int(count * block_size)
    speed = int(progress_size / (1024 * duration))
    percent = int(count * block_size * 100 / total_size)
    sys.stdout.write("\r...%d%%, %d MB, %d KB/s, %d seconds passed" %
                    (percent, progress_size / (1024 * 1024), speed, duration))
    sys.stdout.flush()

def download(url,filename=None):
    if not filename:
        remotefile = urlopen(url)
        filename_header = remotefile.info()['Content-Disposition']
        if filename_header:
            msg = Message()
            msg['content-disposition'] = filename_header
            filename = msg.get_filename()
        if not filename:
            split = urlsplit(url)
            filename = split.path.split("/")[-1]
    filepath = "fetch/" + filename
    urlretrieve(url, filepath, download_status_hook)

queue = {}
for container_filename in glob.glob('packages/**/Containerfile', recursive=True):
    env_dict = { "TARGET": "x86_64"}
    add_list = []
    sources_filename = "%s/sources.json" % dirname(container_filename)
    if not isfile(sources_filename):
        print("\nSkipping: %s" % container_filename)
        continue
    sources = json_read(sources_filename)
    container_file = open(container_filename)
    container_line_list = container_file.readlines(1)
    while container_line_list:
        line = container_line_list[0]
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
        container_line_list = container_file.readlines(1)
    for key,value in env_dict.items():
        try:
            env_dict[key] = value.format(**env_dict)
        except:
            print("Error: unable to format: %s -> %s" % (filename,line))
            sys.exit()
    for key,value_dict in sources.items():
        mirrors = []
        processed_key = key.format(**env_dict)
        queue.setdefault(processed_key, [])
        for item in value_dict['mirrors']:
            if item is not None:
                item_processed = item.format(**env_dict)
                queue[processed_key].append(item_processed)

failed = []
for filename in queue:
    filepath = "fetch/" + filename
    if isfile(filepath):
        print("\nSkipping Existing: %s" % filepath)
        continue;
    for mirror in queue[filename]:
        print("\nDownloading: %s -> %s" % (mirror,filename))
        if download(mirror,filename):
            break
        else:
            failed.append(mirror)

print(failed)
