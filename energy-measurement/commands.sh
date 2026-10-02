#!/usr/bin/env bash

set -euo pipefail
STAGE="${1:?stage required}"

case "$STAGE" in
  # vendor_build.yml:38-52,54 at the tag, cell ubuntu-22.04 / Release / gcc.
  build)
    mv build/_deps /tmp/vw_fetchcontent_deps
    rm -rf build
    mkdir -p build
    mv /tmp/vw_fetchcontent_deps build/_deps

    cmake -S . -B build -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DVW_FEAT_FLATBUFFERS=Off \
      -DVW_FEAT_CSV=On \
      -DVW_FEAT_CB_GRAPH_FEEDBACK=On \
      -DRAPIDJSON_SYS_DEP=Off \
      -DFMT_SYS_DEP=Off \
      -DSPDLOG_SYS_DEP=Off \
      -DVW_ZLIB_SYS_DEP=Off \
      -DVW_BOOST_MATH_SYS_DEP=Off \
      -DVW_INSTALL=Off \
      -DWARNINGS=On \
      -DWARNING_AS_ERROR=On \
      -DVW_CXX_STANDARD=17 \
      -DSTD_INV_SQRT=ON \
      -DFETCHCONTENT_UPDATES_DISCONNECTED=ON
    cmake --build build
    ;;

  # vendor_build.yml:56-57,59 at the tag.
  test)
    (cd /project/build && ctest --output-on-failure --no-tests=error --label-regex VWTestList --parallel 2)
    python3 test/run_tests.py -f --clean_dirty -E 0.001
    ;;

  # The CI of this tag has no training job. The big_tests suite of the tag is run through its own
  # Makefile, on the eight targets the train stage of the default branch covers (4a and 4b excluded there too).
  # The Makefile also diffs stdout against empty expected files, and vw at this tag prints an [info] line there;
  # the stdout pattern is set so that only "average loss" is compared, as on the default branch (the Makefile
  # expands the variable unquoted, hence the pattern without a space).
  train)
    cd /project/big_tests
    make EXEC=/project/build/vowpalwabbit/cli/vw DEFAULT_STDOUT_COMPARATOR_REGEXP="^average.loss" \
      1a.valid 1b.valid 2.valid 3.valid 5a.valid 5b.valid 6a.valid 6b.valid
    ;;

  *)
    echo "Unknown stage: $STAGE" >&2
    exit 1
    ;;
esac
