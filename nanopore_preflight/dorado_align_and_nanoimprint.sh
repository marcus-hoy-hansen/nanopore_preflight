#!/bin/bash

#SBATCH --account nanopore_kga
#SBATCH -c 32
#SBATCH --mem 32g
#SBATCH --time 12:00:00

set -euo pipefail

# shellcheck source=lib.sh
: "${NP_SCRIPT_ROOT:=/faststorage/project/nanopore_kga/uploaded/nanopore_preflight}"
source "${NP_SCRIPT_ROOT}/lib.sh"

#Check if sample name was provided in command
if [ $# -lt 2 ]; then
    >&2 echo "Usage: bash dorado_align.sh </path/to/ubam> </path/to/bam> [<sample_name>]"
    >&2 echo "Exiting"
    exit 1
fi

#Read arguments
uBAM=$1
BAM=$2
SAMPLE=${3:-$(basename "$BAM" .bam)}
REF="$NP_REFERENCE"

DORADO="$NP_DORADO_ALIGNER"

# Align
${DORADO} aligner \
    ${REF} \
    ${uBAM} \
    --mm2-opts "-Y" \
    --threads 32 \
    > ${BAM}

# START NANO
NANODIR="/faststorage/project/nanopore_kga/analysis/${SAMPLE}/data/raw/"

mkdir -p "$NANODIR"

cp "${BAM}" "${NANODIR}" -u

sbatch "${NP_SNAKEMAKE_SCRIPT}" "${SAMPLE}"

#rmdir -p tmp
#rm -rf ${UNMAPPED_BAM_DIR}
