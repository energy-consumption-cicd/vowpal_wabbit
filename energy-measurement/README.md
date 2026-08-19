# Energy measurement instrumentation

## Purpose

This directory is not part of the upstream Vowpal Wabbit repository. It was
added to measure the energy consumption of CI/CD pipeline commands on
controlled hardware, using Intel RAPL counters. The measured construct is the
energy of the CI commands on a controlled bench, not the energy of
GitHub-hosted CI in production.

## Non-invasiveness

No original project file is created or modified. The only additions are this
directory and `.github/workflows/energy-measurement.yml`. Verify with:

```bash
git remote add upstream https://github.com/VowpalWabbit/vowpal_wabbit.git
git fetch upstream
git diff --name-only upstream/master...HEAD
```

## What is measured

Energy is read from the Intel RAPL counters under
`/sys/class/powercap/intel-rapl`, for four domains: package (`pkg`), cores,
uncore (reported as `gpu`, structurally zero on this bench) and DRAM (`ram`).
Counter deltas are overflow-corrected against `max_energy_range_uj`, read from
sysfs at run time rather than hardcoded.

Each run measures a 120 s idle baseline first and derives a per-second rate per
domain. Reported energy per stage is

```
net = max(raw_delta - baseline_rate * wall_time_s, 0)
```

The clamp at zero matters in this project: in the `train` stage the DRAM
subtraction is systematically negative, because a single-threaded streaming
workload keeps DRAM less busy than the idle baseline does. The clamp contains
the artefact and the unclamped value is kept in the diagnostic column
`energy_ram_liquid_raw_j`, which is negative there by design.

`wall_time_s` covers the whole `docker run --rm` lifecycle, including container
setup and teardown, because the RAPL reading window covers the same interval.

Per-stage CPU time is captured inside the container: file descriptor 3
preserves the workload's stderr while `time` writes to `/timing`, so the CPU
time of child processes is attributed to the stage.

## How to run

```bash
docker build -t vowpal-wabbit-medicao -f energy-measurement/Dockerfile .
bash energy-measurement/run_pipeline.sh 1
```

The workflow runs the same script on a self-hosted runner, dispatched manually:

```bash
gh workflow run energy-measurement.yml -f campaign=validation   # run 0 only
gh workflow run energy-measurement.yml -f campaign=full         # 10 runs + median
```

## Stages

Each stage runs in its own container, so build artifacts do not survive into
the later stages.

| stage | corresponds to | command |
|---|---|---|
| `build` | upstream steps "Configure" and "Build" of `build_vendor_linux` | `cmake -S . -B build -G Ninja` with the thirteen upstream flags, then `cmake --build build` |
| `test` | upstream steps "Unit tests" and "Test" of the same job | `ctest --output-on-failure --no-tests=error --label-regex VWTestList --parallel 2`, then `python3 test/run_tests.py -f --clean_dirty -E 0.001` |
| `train` | upstream job `big-tests`, segments 1 and 2 | the eight `vw` invocations with the upstream flags, against the pre-baked datasets |

Reference cell: `vendor_build.yml`, job `build_vendor_linux`, `ubuntu-22.04` /
Release / gcc — cell 1 of 4. `python_checks.yml` contributes no command to the
measured stages.

## Deviations from the upstream pipeline

- **Datasets pre-baked.** The upstream `big-tests` job downloads MNIST and
  Covertype with `wget` inside the job; here they are embedded in the image at
  build time. RAPL has no network domain, so a live download would inflate wall
  time without proportional energy.
- **`-DFETCHCONTENT_UPDATES_DISCONNECTED=ON`** added to the `cmake` configure
  step, serving the same purpose as the upstream `actions/cache` of
  `build/_deps`: reusing the already-fetched googletest without network.
- **The `vw` binary comes from the image** rather than from
  `download-artifact` + `chmod +x`; in both cases it is a pre-built binary, not
  one compiled inside the measured stage.
- **`apt-get install ninja-build libboost-test-dev` and the submodule
  initialisation are outside the measured window**, pre-baked into the image.
  Upstream they count towards the job's time.
- **`--network none` is absent in this campaign.** Hermeticity came from
  pre-baking, not from enforcement: all three measured stages use only local
  paths, so no command exercises the network, but the guarantee is weaker than
  in the projects measured later. The limitation is declared in the project's
  fidelity note.
- **No memory limit.** This campaign predates the `--memory` convention adopted
  later; the flag is absent by generation, not by choice.
- **Only the Release/gcc cell** of the four-way upstream matrix is measured.

## Output schema

One CSV per run, one row per stage plus a `total` row:

```
run, stage, energy_pkg_j, energy_cores_j, energy_gpu_j, energy_ram_j,
wall_time_s, user_time_s, sys_time_s, energy_ram_liquid_raw_j
```

The first nine columns are the official schema shared by every project in the
study; `energy_ram_liquid_raw_j` is diagnostic and is negative in the `train`
stage for the reason explained above.

**Schema note.** The script in this directory writes an eleventh column,
`wall_time_container_s`, which the closed campaign's CSVs do not have: the
column was introduced on 2026-07-12, one day after that campaign. The ten
columns common to both coincide in name and order. A byte-exact recovery of the
script version that produced the closed results is not possible from any
surviving artifact; the gap is documented in the project's fidelity note in the
study's private infrastructure repository.

## Reproducibility notes

Bench: Intel Core i7-9700 (8 cores, no SMT), 16 GB RAM, Crucial BX500 SATA SSD,
Ubuntu 24.04 LTS, kernel 6.8.0, Docker 29.x.

Container flags: `--rm --privileged`.

`ctest --parallel 2` is inherited verbatim from the upstream job;
`test/run_tests.py` derives its own parallelism from the core count, which is 8
on this bench against 4 on a GitHub-hosted runner, and is not overridden.
