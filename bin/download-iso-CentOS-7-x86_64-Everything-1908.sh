#!/bin/bash

self=$(readlink -f "$0")
selfdir=$(dirname "$self")
source "${selfdir}/inc/require_root.sh"
source "${selfdir}/inc/read_config.sh"
source "${selfdir}/inc/iso.sh"

################################################################################

# Checksums:  http://mirror.centos.org/centos/7.7.1908/isos/x86_64/sha256sum.txt

download_iso \
  'http://isoredirect.centos.org/centos/7.7.1908/isos/x86_64/CentOS-7-x86_64-Everything-1908.iso' \
  'bd5e6ca18386e8a8e0b5a9e906297b5610095e375e4d02342f07f32022b13acf'

