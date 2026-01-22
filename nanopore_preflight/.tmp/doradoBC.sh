#!/bin/bash
set -euo pipefail

dir="$1"
base=$(basename "$dir")

dorado basecaller \
 -x cuda:all \
 --min-qscore 10 \
 sup,5mCG_5hmCG,6mA "$dir"/*/pod5/ \
 > "${base}_sup.bam"

