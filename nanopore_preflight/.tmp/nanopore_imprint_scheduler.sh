#!/bin/bash
#SBATCH --job-name=imprint
#SBATCH --account=nanopore_KGA
#SBATCH --cpus-per-task=1
#SBATCH --mem=500M
#SBATCH --time=24:00:00
#SBATCH --partition=normal
#SBATCH --output=logs/imprint-watch-%j.out
##SBATCH --mail-user=you@example.com
##SBATCH --mail-type=BEGIN,END,FAIL

set -euo pipefail
umask 002

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "${SCRIPT_DIR}/nanopore_preflight/nanopore_imprint_scheduler.sh" "$@"
