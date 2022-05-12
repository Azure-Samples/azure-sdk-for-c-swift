#! /bin/bash

# Copyright (c) Microsoft. All rights reserved.
# Licensed under the MIT license. See LICENSE file in the project root for full license information.

set -o errexit # Exit if command failed.
set -o nounset # Exit if variable not set.
set -o pipefail # Exit if pipe failed.

apt-get update
apt-get install curl clang libicu-dev git libatomic1 libicu66 libxml2 libcurl4 zlib1g-dev libbsd0 tzdata libssl-dev libsqlite3-dev libblocksruntime-dev libncurses5-dev libdi

mkdir ~/swift
cd ~swift
wget https://download.swift.org/development/ubuntu2004/swift-DEVELOPMENT-SNAPSHOT-2022-02-03-a/swift-DEVELOPMENT-SNAPSHOT-2022-02-03-a-ubuntu20.04.tar.gz
tar -xvzf ./swift-DEVELOPMENT-SNAPSHOT-2022-02-03-a-ubuntu20.04.tar.gz -C ~/swift
echo 'export PATH="~/swift/swift-DEVELOPMENT-SNAPSHOT-2022-02-03-a-ubuntu20.04/usr/bin:$PATH"' >> ~/.profile
echo 'export PATH="~/swift/swift-DEVELOPMENT-SNAPSHOT-2022-02-03-a-ubuntu20.04/usr/bin:$PATH"' >> ~/.bashrc
export PATH="~/swift/swift-DEVELOPMENT-SNAPSHOT-2022-02-03-a-ubuntu20.04/usr/bin:$PATH"
