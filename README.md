# Nanopore Preflight Pipeline

  A helper bundle to vet uploaded Nanopore runs, move them to storage, basecall with Dorado, align, and launch downstream nanoimprint analysis.

  ## Layout

  - `config.sh` — central settings (project root, storage, reference, snakemake entrypoint, dorado binaries, default basecaller submit script, test mode knobs).
  - `lib.sh` — shared helpers and config loader.
  - `preflight.sh` — validates uploads (bam presence + samtools quickcheck), moves good samples to STORAGE, and submits basecalling.
  - `dorado_basecaller2_20260121.sh` — GPU basecalling job (default). Submits alignment/imprint when done.
  - `dorado_align_and_nanoimprint.sh` — Dorado aligner job; copies BAM into analysis tree and submits snakemake.
  - `dorado_basecaller_cpu_test.sh` — CPU-only, limited-read test job that reuses the main basecaller logic (for fast checks without GPU).
  - `nanopore_imprint_scheduler.sh` — optional Slurm scheduler/watch wrapper to rerun preflight periodically.
  - `.tmp/` — legacy backups (not used in the pipeline).

  ## Key Defaults (see `config.sh`)

  - `NP_PROJECT_ROOT=/faststorage/project/<project>`
  - `NP_BASE=${NP_PROJECT_ROOT}/uploaded`
  - `NP_STORAGE_BASE=${NP_PROJECT_ROOT}/STORAGE`
  - `NP_REFERENCE=${NP_PROJECT_ROOT}/workflow/references/hg38_noAlt.fasta`
  - `NP_SNAKEMAKE_SCRIPT=${NP_PROJECT_ROOT}/workflow/scripts/runSnakemake.sh`
  - `NP_BASECALLER_SBATCH=${NP_SCRIPT_ROOT}/dorado_basecaller2_20260121.sh`
  - Dorado:
    - `NP_DORADO_BASECALLER=<path>/dorado-1.1.1-linux-x64/bin/dorado`
    - `NP_DORADO_ALIGNER=<path>/dorado-1.2.0-linux-x64/bin/dorado`
    - `NP_DORADO_MODEL=sup,5mCG_5hmCG,6mA`
    - `NP_DORADO_TEST_MODEL=fast`
    - `NP_DORADO_DEVICE=cuda:all`
    - `NP_DORADO_TEST_LIMIT=1000`
    - `NP_DORADO_TEST_MODE=0` (set to `1` to force CPU + max-reads cap)

  Override any setting by exporting the corresponding `NP_*` variable before running.

  ## Usage

  ### One-off preflight + full GPU basecall/align
  ```bash
  sbatch nanopore_preflight/preflight.sh

  ### Quick CPU test (limited reads, fast model)

  export NP_DORADO_TEST_MODE=1           # forces CPU and max-reads
  export NP_DORADO_TEST_MODEL=fast       # lighter model
  export NP_DORADO_TEST_LIMIT=1000        # optional small cap
  sbatch nanopore_preflight/preflight.sh
  # or directly:
  sbatch nanopore_preflight/dorado_basecaller_cpu_test.sh <RUN_ROOT> [OUT_BAM] [ALIGNED_BAM]

  ### Scheduler/watch mode

  sbatch nanopore_preflight/nanopore_imprint_scheduler.sh --watch

  ## Notes

  - GPU is the default; CPU test mode is opt-in via NP_DORADO_TEST_MODE=1 or by using the CPU SBATCH wrapper.
  - The basecaller script logs the device and model it uses; check the Slurm output to confirm.
  - .tmp/ contains older backup scripts and is not used by the current pipeline.
