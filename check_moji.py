import glob, os
bad_markers = ["Ã", "Â", "â€", "Ã¢"]
hits = []
for pat in ["src/**/*.py", "*.py"]:
    for f in glob.glob(pat, recursive=True):
        try:
            t = open(f, encoding="utf-8").read()
        except Exception:
            continue
        n = sum(t.count(m) for m in bad_markers)
        if n:
            hits.append((f, n))
for f, n in sorted(hits, key=lambda x: -x[1]):
    print(f"  {n:>5}  {f}")
print(f"\n{len(hits)} files affected")
