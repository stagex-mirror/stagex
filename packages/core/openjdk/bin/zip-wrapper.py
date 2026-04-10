#!/usr/bin/python3
import sys, os, zipfile, fnmatch
args = sys.argv[1:]
quiet = False; recurse = False; update = False; exclude = []
out = None; paths = []
i = 0
while i < len(args):
    a = args[i]
    if a == '-q': quiet = True
    elif a == '-r': recurse = True
    elif a == '-u': update = True
    elif a == '-x':
        i += 1
        if i < len(args): exclude.append(args[i])
    elif a.startswith('-') and len(a) == 2 and a[1].isdigit(): pass
    elif a.startswith('-'): pass
    elif out is None: out = a
    else: paths.append(a)
    i += 1
if not out or not paths: sys.exit(0)
mode = 'a' if (update and os.path.exists(out)) else 'w'
existing = set()
if mode == 'a':
    try:
        with zipfile.ZipFile(out, 'r') as z:
            existing = set(z.namelist())
    except: mode = 'w'
with zipfile.ZipFile(out, mode, zipfile.ZIP_STORED) as z:
    for p in paths:
        if os.path.isdir(p) and recurse:
            for root, dirs, files in os.walk(p):
                for f in files:
                    fp = os.path.join(root, f)
                    arc = os.path.relpath(fp, '.')
                    skip = any(fnmatch.fnmatch(arc, ex) for ex in exclude)
                    if not skip and (not update or arc not in existing):
                        z.write(fp, arc)
        elif os.path.isfile(p):
            arc = p
            skip = any(fnmatch.fnmatch(arc, ex) for ex in exclude)
            if not skip:
                z.write(p, arc)
