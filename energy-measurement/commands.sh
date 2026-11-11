#!/usr/bin/env bash

set -euo pipefail
STAGE="${1:?stage required}"

case "$STAGE" in
  # vendor_build.yml:38-49,52 at the tag, cell ubuntu-20.04 / Release / gcc.
  build)
    mv build/_deps /tmp/vw_fetchcontent_deps
    rm -rf build
    mkdir -p build
    mv /tmp/vw_fetchcontent_deps build/_deps

    cmake -S . -B build -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_FLATBUFFERS=Off \
      -DRAPIDJSON_SYS_DEP=Off \
      -DFMT_SYS_DEP=Off \
      -DSPDLOG_SYS_DEP=Off \
      -DVW_ZLIB_SYS_DEP=Off \
      -DVW_BOOST_MATH_SYS_DEP=Off \
      -DVW_INSTALL=Off \
      -DWARNINGS=On \
      -DWARNING_AS_ERROR=On \
      -DUSE_LATEST_STD=On \
      -DFETCHCONTENT_UPDATES_DISCONNECTED=ON
    cmake --build build
    ;;

  # vendor_build.yml:55-57 at the tag.
  test)
    python3 test/run_tests.py -f --clean_dirty -E 0.001
    cd build
    ctest --verbose --output-on-failure --label-regex VWTestList
    ;;

  *)
    echo "Unknown stage: $STAGE" >&2
    exit 1
    ;;
esac
