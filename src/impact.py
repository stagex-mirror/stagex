import re, sys
from pathlib import Path

db = {}
for p in Path('packages').glob('*/*'):
    if p.is_dir():
        pkg = f"{p.parent.name}-{p.name}"
        content = "".join(f.read_text(errors='ignore') for f in p.glob('*') if f.name in ['Containerfile', 'package.toml'])
        db[pkg] = set(re.findall(r'stagex/([a-zA-Z0-9/_-]+)', content))

def get_impact(target):
    target = target.replace('stagex/', '')
    affected, queue = set(), [target]

    while queue:
        curr = queue.pop(0)
        for pkg, deps in db.items():
            if any(curr in d for d in deps) and pkg not in affected:
                print(f"{curr} ({pkg})")
                affected.add(pkg)
                queue.append(pkg)
    return sorted(affected)

if __name__ == "__main__":
    res = get_impact(sys.argv[1])
    print(f"\n{len(res)}")
