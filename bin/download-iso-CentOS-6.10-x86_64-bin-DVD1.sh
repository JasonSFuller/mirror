#!/bin/bash

self=$(readlink -f "$0")
selfdir=$(dirname "$self")
source "${selfdir}/inc/require_root.sh"
source "${selfdir}/inc/read_config.sh"
source "${selfdir}/inc/iso.sh"

################################################################################

# Checksums:  http://mirror.centos.org/centos/6.10/isos/x86_64/sha256sum.txt

download_iso \
  'http://isoredirect.centos.org/centos/6.10/isos/x86_64/CentOS-6.10-x86_64-bin-DVD1.iso' \
  'a68e46970678d4d297d46086ae2efdd3e994322d6d862ff51dcce25a0759e41c'
