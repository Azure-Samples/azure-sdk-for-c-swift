#! /bin/bash

# Copyright (c) Microsoft. All rights reserved.
# Licensed under the MIT license. See LICENSE file in the project root for full license information.

set -o errexit # Exit if command failed.
set -o nounset # Exit if variable not set.
set -o pipefail # Exit if pipe failed.

apt-get update
apt-get install \
          binutils \
          git \
          gnupg2 \
          libc6-dev \
          libcurl4-openssl-dev \
          libedit2 \
          libgcc-9-dev \
          libpython3.8 \
          libsqlite3-0 \
          libstdc++-9-dev \
          libxml2-dev \
          libz3-dev \
          pkg-config \
          tzdata \
          unzip \
          zlib1g-dev

mkdir ~/swift
cd ~/swift
wget https://download.swift.org/development/ubuntu2004/swift-DEVELOPMENT-SNAPSHOT-2022-02-03-a/swift-DEVELOPMENT-SNAPSHOT-2022-02-03-a-ubuntu20.04.tar.gz
tar -xvzf ./swift-DEVELOPMENT-SNAPSHOT-2022-02-03-a-ubuntu20.04.tar.gz -C ~/swift
echo 'export PATH="~/swift/swift-DEVELOPMENT-SNAPSHOT-2022-02-03-a-ubuntu20.04/usr/bin:$PATH"' >> ~/.profile
echo 'export PATH="~/swift/swift-DEVELOPMENT-SNAPSHOT-2022-02-03-a-ubuntu20.04/usr/bin:$PATH"' >> ~/.bashrc
export PATH="~/swift/swift-DEVELOPMENT-SNAPSHOT-2022-02-03-a-ubuntu20.04/usr/bin:$PATH"
