#!/bin/bash
# Characterise both ring oscillators over temperature and process corners.
# Output: results/ro_freq.csv and ../tb/ro_table_<corner>.vh
set -e
cd "$(dirname "$0")"

# Prefer the PDK version LibreLane uses (same one the layout is built with)
PDK=$(ls -d ~/.ciel/ciel/sky130/versions/*/sky130A 2>/dev/null | head -1)
[ -z "$PDK" ] && PDK="$PDK_ROOT/sky130A"
echo "Using PDK: $PDK"

mkdir -p netlists results
CORNERS=${CORNERS:-"tt ss ff sf fs"}
JOBS=$(nproc)

for c in $CORNERS; do for k in ctat ptat; do
    python3 gen_ro.py $k $c "$PDK" > netlists/ro_${k}_${c}.spice
done; done

echo "Running $(ls netlists | wc -l) simulations on $JOBS cores (several minutes)..."
ls netlists/*.spice | xargs -P "$JOBS" -I{} sh -c 'ngspice -b {} > {}.log 2>&1; echo "  done: {}"'

echo "type,corner,vdd,T_C,f_MHz" > results/ro_freq.csv
grep -h "^RESULT" netlists/*.log | awk '{print $2","$3","$4","$5","$6}' >> results/ro_freq.csv
echo "Saved results/ro_freq.csv ($(($(wc -l < results/ro_freq.csv)-1)) points)"

python3 make_tables.py results/ro_freq.csv ../tb
