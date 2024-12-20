#!/bin/python3
import glob
import re
import sys
import time
import tomllib
from pathlib import Path
from hashlib import file_digest
from os.path import isfile, dirname
from urllib.parse import urlsplit
from urllib.request import build_opener, install_opener, urlopen, urlretrieve
from email.message import Message

def toml_read(filename: str):
    with open(filename,'rb') as f_in:
        return tomllib.load(f_in)

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
    opener = build_opener()
    opener.addheaders = [('User-agent', 'Wget/1.21.3 (linux-gnu)')]
    install_opener(opener)
    urlretrieve(url, filename, download_status_hook)

def verify(filename,compare):
    with open(filename, 'rb', buffering=0) as f:
        digest = file_digest(f, 'sha256').hexdigest()
    if digest == compare:
        return True
    return False

if len(sys.argv) > 1:
    packages = sys.argv[1:]
    package_files = []
    for package in packages:
        package_files = package_files + glob.glob('packages/**/%s/package.toml' % package,recursive=True)
else:
    package_files = glob.glob('packages/**/package.toml', recursive=True)

failed = []
for package_file in package_files:
    print("\nParsing: %s" % package_file)
    package = toml_read(package_file)
    stage = package_file.split('/')[1]
    version = package['package'].get('version',None)
    name = package['package']['name']
    sources = package.get('sources',[])
    for source in sources:
        print("\nValidating: %s" % source)
        digest = package['sources'][source]['hash']
        format = package['sources'][source].get('format','')
        mirrors = package['sources'][source]['mirrors']
        version = package['sources'][source].get('version',version)
        version_under = version.replace('.','_')
        version_dash = version.replace('.','-')
        path = "fetch/%s/%s/" % (stage,name)
        Path(path).mkdir(parents=True, exist_ok=True)
        for mirror in mirrors:
            urlfile = urlsplit(mirror).path.split("/")[-1]
            file = package['sources'][source].get('file',urlfile).format(version=version,version_under=version_under,version_dash=version_dash,format=format)
            url = mirror.format(version=version,version_under=version_under,version_dash=version_dash,format=format,file=file)
            filepath = path + file
            if isfile(filepath):
                if not verify(filepath,digest):
                    failed.append([file,digest,url,'verify_existing'])
                continue
            print("\nDownloading: %s" % file)
            print("Mirror: %s" % url)
            download(url,filepath)
            if not verify(filepath,digest):
                failed.append([file,digest,url,'verify_download'])

if len(failed):
    for fail in failed:
        print("\nFailed: %s" % fail)
    exit(1)
