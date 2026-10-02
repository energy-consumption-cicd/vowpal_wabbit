# Energy measurement instrumentation (release 9.10.0)

## Purpose

This directory is not part of the upstream Vowpal Wabbit repository. It was
added to measure the energy consumption of CI/CD pipeline commands on
controlled hardware, using Intel RAPL counters. The measured construct is the
energy of the CI commands on a controlled bench, not the energy of
GitHub-hosted CI in production.

## Non-invasiveness

No original project file is created or modified. The only additions are this
directory and `.github/workflows/energy-measurement.yml`. This branch is the
upstream tag `9.10.0` (`c0f724bea23d68b5c5e48c2f3899c66a5fc57680`) plus one
instrumentation commit; verify with:

```bash
git diff --stat 9.10.0 release-9.10.0
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

The clamp at zero matters in this project: a single-threaded streaming
workload such as the `train` stage can keep DRAM less busy than the idle
baseline does, which makes the subtraction negative. The clamp contains the
artefact and the unclamped value is kept in the diagnostic column
`energy_ram_liquid_raw_j`.

`wall_time_s` covers the whole `docker run --rm` lifecycle, including container
setup and teardown, because the RAPL reading window covers the same interval.

Per-stage CPU time is captured inside the container: file descriptor 3
preserves the workload's stderr while `time` writes to `/timing`, so the CPU
time of child processes is attributed to the stage.

## How to run

From the root of a clone of branch `release-9.10.0` (the Dockerfile copies the tree
and initialises the submodules from its `.git` directory):

```bash
docker build -t vowpal_wabbit-measurement-9.10.0 -f energy-measurement/Dockerfile .
bash energy-measurement/run_pipeline.sh 1
```

The workflow runs the same script on a self-hosted runner, dispatched manually:

```bash
gh workflow run energy-measurement.yml --ref release-9.10.0 -f campaign=validation   # run 0 only
gh workflow run energy-measurement.yml --ref release-9.10.0 -f campaign=full         # 2 warm-ups + 10 runs + median
```

## Stages

Each stage runs in its own container, so build artifacts do not survive into
the later stages.

| stage | corresponds to | command |
|---|---|---|
| `build` | steps "Configure" and "Build" of job `build_vendor_linux`, `vendor_build.yml` at the tag (lines 38-52, 54) | `cmake -S . -B build -G Ninja` with the flags of that "Configure" step, then `cmake --build build` |
| `test` | steps "Unit tests" and "Test" of the same job (lines 56-57, 59) | `ctest --output-on-failure --no-tests=error --label-regex VWTestList --parallel 2` in `build/`, then `python3 test/run_tests.py -f --clean_dirty -E 0.001` |
| `train` | no job of the CI at this tag; `big_tests/Makefile` of the tag | `make EXEC=<vw> DEFAULT_STDOUT_COMPARATOR_REGEXP="^average.loss" 1a.valid 1b.valid 2.valid 3.valid 5a.valid 5b.valid 6a.valid 6b.valid` in `big_tests/`: preparation of the five datasets, the eight `vw` invocations and the comparison of `average loss` with the expected value |

Reference cell: `vendor_build.yml`, job `build_vendor_linux`, `ubuntu-22.04` /
Release / gcc, one of the eight cells of the job matrix at the tag.

The CI of this tag has no training job: the upstream job `big-tests`, which the
`train` stage of the default branch transcribes, was added to `vendor_build.yml`
after this tag. To keep the three stages of the default branch, `train` runs
the `big_tests` suite of the tag through its own Makefile, on the eight targets
that correspond to the `train` stage of the default branch (`4a` and `4b` are
not part of it there either).

## Deviations from the upstream pipeline

- **`train` comes from `big_tests/` of the tag, not from a CI job**, as
  explained above. `big_tests/testCode/ocr2vw.py` is a Python 2 script with a
  `python` shebang at this tag, so the image provides `python` as Python 2;
  the script is not modified. The Makefile also diffs the standard output of
  `vw` against empty expected files; `vw` at this tag prints an informational
  line there, so the stdout pattern is overridden on the `make` command line
  and only `average loss` is compared, as on the default branch.
- **Datasets pre-baked.** The nine raw dataset files that `big_tests/dataSets.mk`
  of the tag downloads are embedded in the image at build time, where the
  Makefile expects them, each checked against its sha256; the Makefile then
  only prepares them. The MNIST files come from a mirror, because the URL in
  `dataSets.mk` no longer serves them. RAPL has no network domain, so a live
  download would inflate wall time without proportional energy.
- **`-DFETCHCONTENT_UPDATES_DISCONNECTED=ON`** added to the `cmake` configure
  step. The upstream job fetches googletest through FetchContent at configure
  time; here the image holds the already-fetched `build/_deps`, which the
  measured `build` stage keeps while it deletes the rest of `build/`.
- **The `vw` binary of `test` and `train` comes from the image**, which holds a
  build made with the same flags; each stage starts a new container, so the
  output of the measured `build` stage does not reach the later stages.
- **`apt-get install ninja-build libboost-test-dev` and the submodule
  initialisation are outside the measured window**, pre-baked into the image.
  Upstream they count towards the job's time.
- **Base image and toolchain of the default branch.** `ubuntu:22.04` pinned by
  digest with the distribution's g++, CMake, Ninja and Python, not the
  toolchain of the hosted runner at the tag date. The Python binding is not
  built in the image; no measured stage uses it.
- **`--network none`.** Every measured container runs without network.
- **No memory limit.** The containers run without `--memory`, as on the
  default branch.
- **Only the `ubuntu-22.04` / Release / gcc cell** of the upstream matrix is
  measured.

## Output schema

One CSV per run, one row per stage plus a `total` row:

```
run, stage, energy_pkg_j, energy_cores_j, energy_gpu_j, energy_ram_j,
wall_time_s, user_time_s, sys_time_s, energy_ram_liquid_raw_j,
wall_time_container_s, baseline_rate_pkg_w, baseline_rate_cores_w,
baseline_rate_ram_w
```

The first nine columns are the schema shared by every project in the study;
`energy_ram_liquid_raw_j`, `wall_time_container_s` and the baseline rates of
the run are diagnostic.

Host swap counters and the package temperature are read immediately before and
after the RAPL window of each stage, never inside it, and written as
`swap_run_NN_<stage>.txt` and `temp_run_NN_<stage>.txt` next to the CSV.

## Reproducibility notes

Bench: Intel Core i7-9700 (8 cores, no SMT), 16 GB RAM, Crucial BX500 SATA SSD,
Ubuntu 24.04 LTS, kernel 6.8.0, Docker 29.x.

Container flags: `--rm --privileged --network none`.

`ctest --parallel 2` is inherited verbatim from the upstream job;
`test/run_tests.py` derives its own parallelism from the core count, which is 8
on this bench, more than on a GitHub-hosted runner, and is not overridden.
