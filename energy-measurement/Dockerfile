FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    cmake \
    ninja-build \
    g++ \
    git \
    libboost-test-dev \
    netcat-openbsd \
    perl \
    python3 \
    python3-dev \
    python3-pip \
    unzip \
    wget \
    zlib1g-dev \
  && rm -rf /var/lib/apt/lists/*

RUN pip3 install --upgrade pip setuptools wheel pybind11

COPY . /project
WORKDIR /project

RUN git config --global --add safe.directory /project && \
    git submodule update --init --recursive

RUN cmake -S . -B build -G Ninja \
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
      -DFETCHCONTENT_UPDATES_DISCONNECTED=ON \
    && cmake --build build

RUN PYBIND11_DIR=$(python3 -m pybind11 --cmakedir) && \
    CMAKE_ARGS="-DCMAKE_BUILD_TYPE=Release -DVW_ZLIB_SYS_DEP=OFF -DVW_FEAT_CSV=ON -Dpybind11_DIR=${PYBIND11_DIR}" \
    pip3 install . --verbose

RUN mkdir -p /project/big_tests/dataSets/mnist.dir && \
    cd /project/big_tests/dataSets/mnist.dir && \
    for f in train-labels-idx1-ubyte.gz train-images-idx3-ubyte.gz \
             t10k-labels-idx1-ubyte.gz t10k-images-idx3-ubyte.gz; do \
      wget -nv "https://storage.googleapis.com/cvdf-datasets/mnist/$f"; \
    done

RUN mkdir -p /project/big_tests/dataSets/covtype.dir && \
    wget -nv -P /project/big_tests/dataSets/covtype.dir \
      https://archive.ics.uci.edu/ml/machine-learning-databases/covtype/covtype.data.gz

RUN mkdir -p /project/big_tests/dataSets/URLRep.dir && \
    wget -nv -P /project/big_tests/dataSets/URLRep.dir \
      https://archive.ics.uci.edu/ml/machine-learning-databases/url/url_svmlight.tar.gz

# Upstream certificate expired 2026-08-28; integrity enforced via sha256 instead.
RUN mkdir -p /project/big_tests/dataSets/movielens.dir && \
    wget -nv --no-check-certificate -P /project/big_tests/dataSets/movielens.dir \
      http://files.grouplens.org/datasets/movielens/ml-1m.zip && \
    echo "a6898adb50b9ca05aa231689da44c217cb524e7ebd39d264c56e2832f2c54e20  /project/big_tests/dataSets/movielens.dir/ml-1m.zip" | sha256sum -c -

RUN mkdir -p /project/big_tests/dataSets/OCR.dir && \
    wget -nv -P /project/big_tests/dataSets/OCR.dir \
      http://ai.stanford.edu/~btaskar/ocr/letter.data.gz \
      http://ai.stanford.edu/~btaskar/ocr/letter.names
