#!/usr/bin/env bash
# FlyWire FAFB v783 — manual download instructions.
#
# This script deliberately does NOT download anything. The FlyWire download
# requires a Google sign-in and in-person acceptance of the CC BY-NC terms.
# Automating around that would violate the terms; scraping Codex or hammering
# the API is likewise out of bounds.
#
# Run it to see the steps and to check what you already have.
set -euo pipefail

RAW="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/data/raw"
mkdir -p "$RAW"

cat <<'INSTRUCTIONS'
FlyWire FAFB v783 — manual download
===================================

  1. Open  https://codex.flywire.ai/?dataset=fafb
  2. Sign in with Google and accept the CC BY-NC 4.0 terms
  3. Go to  Info -> Download Data
  4. Choose snapshot  v783
     ** NOT the live materialization — it drifts, and every number in this
        repo's acceptance tests is pinned to v783. **
  5. Download these files (keep the .csv.gz; they are read compressed).
     The names must match flydoom/sources.py:

       classification.csv.gz                    required  flow, super_class, class, side
       consolidated_cell_types.csv.gz           required  primary_type (cell types live here)
       visual_neuron_types.csv.gz               required  optic lobe typing (T4/T5/LC/LPLC)
       labels.csv.gz                            required  community labels (BPN, aIPg)
       connections_buhmann_no_threshold.csv.gz  required  pre, post, neuropil, syn_count, nt_type
       column_assignment.csv.gz                 required  for eye map / dendrite experiments
       connections_princeton_no_threshold.csv.gz optional alternative synapse pipeline

     ** NOT connections_princeton.csv: its nt_type column is 100% null. **

  6. Put them in  data/raw/

Expected v783 magnitudes (from Codex, 2026-08):

       neurons        139,255
       connections  3,732,460      <- rows in connections.csv
       synapses    ~54,500,000     <- sum of syn_count; NOT the row count

Then:  python experiments/m0_resolve.py
INSTRUCTIONS

echo
echo "Currently in $RAW:"
found=0
for f in classification.csv.gz consolidated_cell_types.csv.gz visual_neuron_types.csv.gz labels.csv.gz \
         connections_buhmann_no_threshold.csv.gz column_assignment.csv.gz \
         connections_princeton_no_threshold.csv.gz; do
  [[ -f "$RAW/$f" ]] || { [[ -f "$RAW/${f%.gz}" ]] && f="${f%.gz}"; }
  if [[ -f "$RAW/$f" ]]; then
    printf '  [x] %-44s %s\n' "$f" "$(du -h "$RAW/$f" | cut -f1)"
    found=$((found + 1))
  else
    printf '  [ ] %-44s missing\n' "$f"
  fi
done
echo
[[ $found -eq 0 ]] && echo "Nothing downloaded yet." || echo "$found file(s) present."
