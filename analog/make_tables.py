#!/usr/bin/env python3
"""Turn results/ro_freq.csv into Verilog interpolation tables for the testbench
and print the frequency ratio table. usage: make_tables.py <csv> <tb_dir>"""
import csv, sys, collections
src, outdir = sys.argv[1], sys.argv[2]
data = collections.defaultdict(list)
for r in csv.DictReader(open(src)):
    if r["f_MHz"].strip() in ("", "nan"):
        continue
    data[(r["corner"], r["type"])].append((float(r["T_C"]), float(r["f_MHz"])))

def func(name, pts):
    pts = sorted(pts)
    s = [f"    function real {name}(input real t);", "        begin"]
    for i in range(len(pts) - 1):
        (t0, f0), (t1, f1) = pts[i], pts[i + 1]
        kw = "if" if i == 0 else "else if"
        cond = f"t <= {t1}" if i < len(pts) - 2 else "1"
        s.append(f"            {kw} ({cond}) {name} = {f0} + (t - ({t0})) * ({f1} - {f0}) / ({t1} - ({t0}));")
    s += ["        end", "    endfunction"]
    return "\n".join(s)

corners = sorted({c for c, _ in data})
for c in corners:
    if (c, "ctat") not in data or (c, "ptat") not in data:
        continue
    with open(f"{outdir}/ro_table_{c}.vh", "w") as f:
        f.write(f"// Auto-generated from {src} (corner {c}) by make_tables.py\n")
        f.write(func("f_ctat", data[(c, "ctat")]) + "\n" + func("f_ptat", data[(c, "ptat")]) + "\n")
    print(f"wrote {outdir}/ro_table_{c}.vh")

print("\ncorner   T(C)   f_ctat(MHz)  f_ptat(MHz)  ratio=fp/fc")
for c in corners:
    n = dict(data[(c, "ctat")]); p = dict(data[(c, "ptat")])
    for t in sorted(set(n) & set(p)):
        print(f"{c:6s} {t:6.0f}   {n[t]:10.2f}  {p[t]:10.2f}   {p[t]/n[t]:.4f}")
