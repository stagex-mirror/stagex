#!/usr/bin/python3
import sys, os, zipfile
args = sys.argv[1:]
if not args: sys.exit(0)
mode_str = args[0]; args = args[1:]
has_c = 'c' in mode_str; has_u = 'u' in mode_str
has_f = 'f' in mode_str; has_m = 'm' in mode_str
jar_file = manifest = None; entries = []; cdirs = []
i = 0
if has_m and has_f:
    mpos = mode_str.index('m'); fpos = mode_str.index('f')
    if mpos < fpos:
        manifest = args[0] if len(args) > 0 else None
        jar_file = args[1] if len(args) > 1 else None; i = 2
    else:
        jar_file = args[0] if len(args) > 0 else None
        manifest = args[1] if len(args) > 1 else None; i = 2
elif has_f:
    jar_file = args[0] if args else None; i = 1
elif has_m:
    manifest = args[0] if args else None; i = 1
while i < len(args):
    a = args[i]
    if a.startswith('-J'): pass
    elif a == '-C':
        if i+2 < len(args): cdirs.append((args[i+1], args[i+2])); i += 2
    elif a.startswith('@'):
        with open(a[1:]) as f:
            for line in f:
                line = line.strip()
                if line: entries.append(line)
    else: entries.append(a)
    i += 1
if not jar_file: sys.exit(0)
if not os.path.isabs(jar_file): jar_file = os.path.join(os.getcwd(), jar_file)
zmode = 'w' if has_c else 'a'
with zipfile.ZipFile(jar_file, zmode, zipfile.ZIP_STORED) as z:
    if manifest and has_c: z.write(manifest, 'META-INF/MANIFEST.MF')
    elif has_c: z.writestr('META-INF/MANIFEST.MF', 'Manifest-Version: 1.0\n\n')
    for e in entries:
        if os.path.isdir(e):
            for root, dirs, files in os.walk(e):
                for f in files:
                    fp = os.path.join(root, f)
                    z.write(fp, os.path.relpath(fp, '.'))
        elif os.path.isfile(e): z.write(e, e)
    for cdir, cpath in cdirs:
        old = os.getcwd(); os.chdir(cdir)
        if os.path.isdir(cpath):
            for root, dirs, files in os.walk(cpath):
                for f in files:
                    fp = os.path.join(root, f)
                    z.write(fp, os.path.relpath(fp, '.'))
        elif os.path.isfile(cpath): z.write(cpath, cpath)
        os.chdir(old)
