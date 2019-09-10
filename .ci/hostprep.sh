#!/bin/bash

set -e

home="${1}"
url="${2}"

sudo apt-get update
sudo apt-get install -y asciidoc bsdtar qemu-user-static xsltproc
sudo mkdir -p /run/shm/
git clone ${url}.git --branch gh-pages --single-branch ${home}/repo || true
rm -fR ${home}/repo/.git

exit
