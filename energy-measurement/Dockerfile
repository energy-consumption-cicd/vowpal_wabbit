# Base of the default-branch image, pinned by digest; the toolchain is the distribution's.
FROM ubuntu:22.04@sha256:2edbbc5dc405e9612ba3584ce95480277e3eb374407b5505fe26f17df77c7dbc

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

# Build context: a clone of branch release-9.6.0 with its .git directory, not a git worktree.
#   docker build -t vowpal_wabbit-measurement-9.6.0 -f energy-measurement/Dockerfile .
