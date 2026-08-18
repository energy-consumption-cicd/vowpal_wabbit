#!/usr/bin/env bash

set -euo pipefail
STAGE="${1:?stage required}"

case "$STAGE" in
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
      -DVW_SIMD_INV_SQRT=OFF \
      -DCMAKE_POLICY_VERSION_MINIMUM=3.5 \
      -DFETCHCONTENT_UPDATES_DISCONNECTED=ON
    cmake --build build
    ;;

  test)
    (cd /project/build && ctest --output-on-failure --no-tests=error --label-regex VWTestList --parallel 2)
    python3 test/run_tests.py -f --clean_dirty -E 0.001
    ;;

  train)
    VW=/project/build/vowpalwabbit/cli/vw
    DIFF="perl testCode/floatingTolerance.pl"
    TOL=0.001
    BIG_TESTS=/project/big_tests

    run_test() {
      local name="$1"
      shift
      echo "=== Running test $name ==="
      mkdir -p runs/$name.dir
      $VW "$@" > runs/$name.dir/raw_out 2> runs/$name.dir/raw_err
      grep "average loss" runs/$name.dir/raw_err > runs/$name.dir/err
      echo "Result: $(cat runs/$name.dir/err)"
      $DIFF $TOL $TOL runs/$name.dir/err expected/$name/err
      echo "=== Test $name PASSED ==="
    }

    exigir() { [ -f "$1" ] || { echo "pre-baked dataset missing from image: $1" >&2; exit 1; }; }

    cd "$BIG_TESTS"
    cd dataSets/mnist.dir
    for f in train-labels-idx1-ubyte.gz train-images-idx3-ubyte.gz \
              t10k-labels-idx1-ubyte.gz t10k-images-idx3-ubyte.gz; do
      exigir "$f"
    done
    cd ../../testCode
    g++ -O3 -Wall mnist.extractfeatures.cpp -o mnist.extractfeatures
    cd ../dataSets/mnist.dir
    export testCodeDir=$(pwd)/../../testCode
    $testCodeDir/mnist.munge.sh train-labels-idx1-ubyte.gz train-images-idx3-ubyte.gz \
      | $testCodeDir/shuffle.pl > train.prep
    $testCodeDir/mnist.munge.sh t10k-labels-idx1-ubyte.gz t10k-images-idx3-ubyte.gz \
      > test.prep

    cd "$BIG_TESTS"
    exigir dataSets/covtype.dir/covtype.data.gz
    export testCodeDir=$(pwd)/testCode
    cd dataSets/covtype.dir
    $testCodeDir/covtype.munge.sh covtype.data.gz > prep

    cd "$BIG_TESTS"
    exigir dataSets/URLRep.dir/url_svmlight.tar.gz
    export testCodeDir=$(pwd)/testCode
    cd dataSets/URLRep.dir
    $testCodeDir/URLRep.munge.sh url_svmlight.tar.gz > prep

    cd "$BIG_TESTS"

    run_test 1a --oaa 10 -d dataSets/mnist.dir/train.prep \
      -f runs/1a.dir/mnist.model -b 24 --adaptive --invariant --holdout_off \
      -l 0.1 --nn 40 --passes 24 -k --compressed --cache_file runs/1a.dir/mnist.cache

    run_test 1b -t -d dataSets/mnist.dir/test.prep -i runs/1a.dir/mnist.model

    run_test 2 --oaa 7 -d dataSets/covtype.dir/prep

    run_test 3 -d dataSets/URLRep.dir/prep

    cd "$BIG_TESTS"
    exigir dataSets/movielens.dir/ml-1m.zip
    cd dataSets/movielens.dir
    unzip -ou ml-1m.zip
    ../../testCode/movielensRatings2vw.pl pre.train.vw test.prep ml-1m/ratings.dat
    perl -ne 'BEGIN { srand 8675309; }; 1; print join "\t", rand (), $_;' \
      pre.train.vw | sort -k1 | cut -f2- > train.prep

    cd "$BIG_TESTS"
    exigir dataSets/OCR.dir/letter.data.gz
    exigir dataSets/OCR.dir/letter.names
    python3 testCode/ocr2vw.py \
      dataSets/OCR.dir/letter.data.gz dataSets/OCR.dir/letter.names \
      dataSets/OCR.dir/train.prep dataSets/OCR.dir/test.prep

    cd "$BIG_TESTS"

    run_test 5a --loss_function quantile -l 0.45 -b 24 --passes 100 -k \
      --cache_file runs/5a.dir/movielens.cache -d dataSets/movielens.dir/train.prep \
      --holdout_off --lrq um14 --lrqdropout --adaptive --invariant \
      -f runs/5a.dir/movielens.model

    run_test 5b --loss_function quantile -t \
      -i runs/5a.dir/movielens.model -d dataSets/movielens.dir/test.prep

    run_test 6a -d dataSets/OCR.dir/train.prep \
      -f runs/6a.dir/OCR.model --cache_file runs/6a.dir/OCR.cache -k \
      --oaa 26 --adaptive --invariant --holdout_off --loss_function logistic --passes 14

    run_test 6b -i runs/6a.dir/OCR.model -d dataSets/OCR.dir/test.prep --testonly
    ;;

  *)
    echo "Stage desconhecido: $STAGE" >&2
    exit 1
    ;;
esac
