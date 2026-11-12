#!/bin/bash
# RTL simulation of the full sensor for every process corner.
# Usage: ./run_sim.sh            (all corners that have a ro_table_<c>.vh)
#        ./run_sim.sh tt ss      (selected corners)
set -e
cd "$(dirname "$0")"
RTL="../rtl/tsense_sync2.v ../rtl/tsense_ripple_cnt.v ../rtl/tsense_core.v ../rtl/tsense_top.v"
CORNERS=${@:-$(ls ro_table_*.vh | sed 's/ro_table_\(.*\)\.vh/\1/')}

for c in $CORNERS; do
    DEF=""; [ "$c" != "tt" ] && DEF="-DCORNER_$(echo $c | tr a-z A-Z)"
    iverilog -g2012 -Wall $DEF -o sim_$c tb_tsense.v ro_models.v $RTL
    vvp -n sim_$c | grep -E "^\[|ERROR"
done
echo
echo "CSV results: $(ls tb_results_*.csv | tr '\n' ' ')"
echo "Waveforms:   gtkwave tb_tsense_tt.vcd"
