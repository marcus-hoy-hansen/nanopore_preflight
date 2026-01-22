#!/usr/bin/env bash
set -euo pipefail

BASE=${1:-/home/marcushh/nanopore_kga/uploaded}
STORAGE_BASE=/home/marcushh/nanopore_kga/STORAGE

if ! command -v samtools >/dev/null 2>&1; then
  # Try to source the requested conda environment if samtools is missing
  if [[ -f "/home/$USER/miniforge3/etc/profile.d/conda.sh" ]]; then
    # shellcheck source=/dev/null
    source "/home/$USER/miniforge3/etc/profile.d/conda.sh"
    conda activate bwa >/dev/null 2>&1 || true
  fi
fi

if ! command -v samtools >/dev/null 2>&1; then
  echo "samtools is required but not found in PATH" >&2
  exit 1
fi

status=0

declare -a exp_dirs=()
while IFS= read -r -d '' dir; do
  exp_dirs+=("$dir")
done < <(find "$BASE" -maxdepth 1 -mindepth 1 -type d -iregex '.*/[^/]*\(adaptive\|adaptiv\|wgs\)$' -print0 | sort -z)

if (( ${#exp_dirs[@]} == 0 )); then
  echo "No experiment folders ending with *daptive or *WGS found under $BASE" >&2
  exit 1
fi

for exp_dir in "${exp_dirs[@]}"; do
  exp_name=$(basename "$exp_dir")
  echo "Experiment: $exp_name"

  declare -a samples=()
  while IFS= read -r -d '' sample; do
    samples+=("$sample")
  done < <(find "$exp_dir" -maxdepth 1 -mindepth 1 -type d -print0 | sort -z)

  if (( ${#samples[@]} == 0 )); then
    echo "  No sample folders found"
    status=1
    continue
  fi

  for sample_dir in "${samples[@]}"; do
    sample_name=$(basename "$sample_dir")
    sample_error=0

    declare -a run_dirs=()
    while IFS= read -r -d '' run_dir; do
      run_dirs+=("$run_dir")
    done < <(find "$sample_dir" -maxdepth 1 -mindepth 1 -type d -print0 | sort -z)

    if (( ${#run_dirs[@]} == 0 )); then
      echo "  [$sample_name] ERROR: no run folders found"
      status=1
      continue
    fi

    for run_dir in "${run_dirs[@]}"; do
      run_name=$(basename "$run_dir")
      bam_pass="$run_dir/bam_pass"
      csv_file=$(find "$run_dir" -maxdepth 1 -type f -name 'output_hash_*.csv' | head -n 1)

      if [[ ! -d "$bam_pass" ]]; then
        echo "  [$sample_name/$run_name] ERROR: bam_pass directory missing"
        sample_error=1
        continue
      fi

      if [[ -z "$csv_file" ]]; then
        echo "  [$sample_name/$run_name] ERROR: output_hash_*.csv missing"
        sample_error=1
        continue
      fi

      mapfile -t bam_files < <(find "$bam_pass" -maxdepth 1 -type f -name '*.bam' | sort)

      if (( ${#bam_files[@]} == 0 )); then
        echo "  [$sample_name/$run_name] ERROR: no BAM files in bam_pass"
        sample_error=1
        continue
      fi

      missing_in_csv=()
      quickcheck_fail=()

      for bam in "${bam_files[@]}"; do
        bam_base=$(basename "$bam")

        if ! grep -Fq "$bam_base" "$csv_file"; then
          missing_in_csv+=("$bam_base")
        fi

        if ! samtools quickcheck "$bam" >/dev/null 2>&1; then
          quickcheck_fail+=("$bam_base")
        fi
      done

      if (( ${#missing_in_csv[@]} )); then
        echo "  [$sample_name/$run_name] ERROR: BAMs missing in CSV: ${missing_in_csv[*]}"
        sample_error=1
      fi

      if (( ${#quickcheck_fail[@]} )); then
        echo "  [$sample_name/$run_name] ERROR: samtools quickcheck failed: ${quickcheck_fail[*]}"
        sample_error=1
      fi
    done

    if (( sample_error == 0 )); then
      dest="$STORAGE_BASE/$exp_name"
      echo "  [$sample_name] Preflight OK -> moving to $dest/$sample_name/"
      mkdir -p "$dest"
      sleep 30
      mv "$sample_dir" "$dest/"

      # After a successful move, run alignment with doradoAligner
      sleep 10
      align_input=$(find "$dest/$sample_name" -type f -path '*/bam_pass/*.bam' | sort | head -n 1)
      if [[ -z "$align_input" ]]; then
        echo "  [$sample_name] WARNING: No BAM found under bam_pass for alignment; skipped"
      else
        ref="/home/marcushh/nanopore_kga/workflow/references/hg38_noAlt.fasta"
        suffix=$([[ "$exp_name" =~ [Ww][Gg][Ss] ]] && echo "hg38_WGS" || echo "hg38_ASv2")
        prefix="$dest/$sample_name/${sample_name}_${suffix}"
        echo "  [$sample_name] Submitting doradoAligner via sbatch -> $prefix.bam"
        sbatch /home/marcushh/nanopore_kga/development/scripts/doradoalign_and_nanoimprint.sh "$align_input" "$ref" "$prefix"
      fi
    else
      status=1
    fi
  done

done

exit $status
