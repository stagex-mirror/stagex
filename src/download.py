#!/bin/python3
import glob
import re
import sys
import time
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
            filename = "fetch/" + split.path.split("/")[-1]
    print("\nDownloading: %s" % url)
    urlretrieve(url, filename, download_status_hook)

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
    for key,value in env_dict.items():
        try:
            env_dict[key] = value.format(**env_dict)
        except:
            print("Error: unable to format: %s -> %s" % (filename,line))
            sys.exit()
    for add_dict in add_list:
        for key,value in add_dict.items():
            if value is not None:
                add_dict[key] = value.format(**env_dict)
        queue.append(add_dict)

for item in queue:
    download(item['url'],item['filename'])
