#!/usr/bin/env python3
"""Generate an Ngspice netlist for one ring oscillator (sky130 standard cells).
usage: gen_ro.py <ctat|ptat> <corner> <pdk_dir> [vdd]
  ctat = NAND2 enable + 10 x NAND4 (inputs tied)  -> f falls with T
  ptat = NAND2 enable + 10 x NOR4  (inputs tied)  -> f rises with T
Prints lines 'RESULT <type> <corner> <vdd> <T> <f_MHz>' when simulated."""
import sys
kind, corner, pdk = sys.argv[1], sys.argv[2], sys.argv[3]
vdd = float(sys.argv[4]) if len(sys.argv) > 4 else 1.8
cell = {"ctat": "nand4_1", "ptat": "nor4_1"}[kind]
N = 10
temps = "-40 -20 0 20 40 60 85 105 125"
L = [f"* {kind} ring oscillator: nand2 + {N} x {cell}, corner {corner}, VDD={vdd}",
     f".lib {pdk}/libs.tech/ngspice/sky130.lib.spice {corner}",
     f".include {pdk}/libs.ref/sky130_fd_sc_hd/spice/sky130_fd_sc_hd.spice",
     f"VDD vdd 0 {vdd}",
     f"VEN en 0 PWL(0 0 0.5n 0 0.6n {vdd})",
     f"XEN en n{N} 0 0 vdd vdd n0 sky130_fd_sc_hd__nand2_1"]
for i in range(N):
    a = f"n{i}"
    L.append(f"XS{i} {a} {a} {a} {a} 0 0 vdd vdd n{i+1} sky130_fd_sc_hd__{cell}")
L.append("XOB n0 0 0 vdd vdd clk_out sky130_fd_sc_hd__clkbuf_2")   # output buffer load
L.append(f"""
.control
foreach t {temps}
  option temp=$t
  tran 10p 100n
  meas tran per TRIG v(n0) VAL={vdd/2} RISE=3 TARG v(n0) VAL={vdd/2} RISE=8
  let fmhz = 5e-6/per
  echo "RESULT {kind} {corner} {vdd} $t $&fmhz"
end
.endc
.end""")
print("\n".join(L))
