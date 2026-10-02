# Base of the default-branch image, pinned by digest; the toolchain is the distribution's.
FROM ubuntu:22.04@sha256:2edbbc5dc405e9612ba3584ce95480277e3eb374407b5505fe26f17df77c7dbc

ENV DEBIAN_FRONTEND=noninteractive

# make drives big_tests at this tag; big_tests/testCode/ocr2vw.py is a Python 2 script with a `python` shebang.
RUN apt-get update && apt-get install -y \
    cmake \
    ninja-build \
    g++ \
    git \
    libboost-test-dev \
    make \
    netcat-openbsd \
    perl \
    python2 \
    python3 \
    python3-dev \
    python3-pip \
    unzip \
    wget \
    zlib1g-dev \
  && rm -rf /var/lib/apt/lists/* \
  && ln -s /usr/bin/python2 /usr/local/bin/python

COPY . /project
WORKDIR /project

RUN git config --global --add safe.directory /project && \
    git submodule update --init --recursive

# Configure flags of the tag; googletest is fetched here, so the measured build needs no network.
RUN cmake -S . -B build -G Ninja \
      -DCMAKE_BUILD_TYPE=Release \
      -DBUILD_FLATBUFFERS=Off \
      -DVW_BUILD_CSV=On \
      -DRAPIDJSON_SYS_DEP=Off \
      -DFMT_SYS_DEP=Off \
      -DSPDLOG_SYS_DEP=Off \
      -DVW_ZLIB_SYS_DEP=Off \
      -DVW_BOOST_MATH_SYS_DEP=Off \
      -DVW_INSTALL=Off \
      -DWARNINGS=On \
      -DWARNING_AS_ERROR=On \
      -DUSE_LATEST_STD=On \
      -DFETCHCONTENT_UPDATES_DISCONNECTED=ON \
    && cmake --build build

# Same nine dataset files as the default-branch image, each checked against its sha256.
RUN mkdir -p /project/big_tests/dataSets/mnist.dir && \
    cd /project/big_tests/dataSets/mnist.dir && \
    for f in train-labels-idx1-ubyte.gz train-images-idx3-ubyte.gz \
             t10k-labels-idx1-ubyte.gz t10k-images-idx3-ubyte.gz; do \
      wget -nv "https://storage.googleapis.com/cvdf-datasets/mnist/$f"; \
    done && \
    printf '%s\n' \
      "3552534a0a558bbed6aed32b30c495cca23d567ec52cac8be1a0730e8010255c  train-labels-idx1-ubyte.gz" \
      "440fcabf73cc546fa21475e81ea370265605f56be210a4024d2ca8f203523609  train-images-idx3-ubyte.gz" \
      "f7ae60f92e00ec6debd23a6088c31dbd2371eca3ffa0defaefb259924204aec6  t10k-labels-idx1-ubyte.gz" \
      "8d422c7b0a1c1c79245a5bcf07fe86e33eeafee792b84584aec276f5a2dbc4e6  t10k-images-idx3-ubyte.gz" \
    | sha256sum -c -

RUN mkdir -p /project/big_tests/dataSets/covtype.dir && \
    wget -nv -P /project/big_tests/dataSets/covtype.dir \
      https://archive.ics.uci.edu/ml/machine-learning-databases/covtype/covtype.data.gz && \
    echo "614360d0257557dd1792834a85a1cdebfadc3c4f30b011d56afee7ffb5b15771  /project/big_tests/dataSets/covtype.dir/covtype.data.gz" | sha256sum -c -

RUN mkdir -p /project/big_tests/dataSets/URLRep.dir && \
    wget -nv -P /project/big_tests/dataSets/URLRep.dir \
      https://archive.ics.uci.edu/ml/machine-learning-databases/url/url_svmlight.tar.gz && \
    echo "a05cbbcba7235221fd4229ea7e54476e75b9bc7d45ff43c2cebaf538640831eb  /project/big_tests/dataSets/URLRep.dir/url_svmlight.tar.gz" | sha256sum -c -

# Integrity comes from the sha256, not from the server certificate.
RUN mkdir -p /project/big_tests/dataSets/movielens.dir && \
    wget -nv --no-check-certificate -P /project/big_tests/dataSets/movielens.dir \
      http://files.grouplens.org/datasets/movielens/ml-1m.zip && \
    echo "a6898adb50b9ca05aa231689da44c217cb524e7ebd39d264c56e2832f2c54e20  /project/big_tests/dataSets/movielens.dir/ml-1m.zip" | sha256sum -c -

RUN mkdir -p /project/big_tests/dataSets/OCR.dir && \
    wget -nv -P /project/big_tests/dataSets/OCR.dir \
      http://ai.stanford.edu/~btaskar/ocr/letter.data.gz \
      http://ai.stanford.edu/~btaskar/ocr/letter.names && \
    printf '%s\n' \
      "4ef9522ffeaa68cad889ad8d02ad3fca411fe6a656546c236a183866157b3b34  /project/big_tests/dataSets/OCR.dir/letter.data.gz" \
      "21270007b5d73ce65fda788b3b8c3df6a09056d39e850275b6ee7d91903b66f4  /project/big_tests/dataSets/OCR.dir/letter.names" \
    | sha256sum -c -

# Build context: a clone of branch release-9.7.0 with its .git directory, not a git worktree.
#   docker build -t vowpal_wabbit-measurement-9.7.0 -f energy-measurement/Dockerfile .
