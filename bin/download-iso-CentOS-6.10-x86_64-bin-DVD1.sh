#!/bin/bash

self=$(readlink -f "$0")
selfdir=$(dirname "$self")
source "${selfdir}/inc/require_root.sh"
source "${selfdir}/inc/read_config.sh"
source "${selfdir}/inc/iso.sh"

################################################################################

# source:  http://mirror.centos.org/centos/6.10/isos/x86_64/sha256sum.txt
file='CentOS-6.10-x86_64-bin-DVD1.iso'
url='http://isoredirect.centos.org/centos/6.10/isos/x86_64/CentOS-6.10-x86_64-bin-DVD1.iso'
sha256='a68e46970678d4d297d46086ae2efdd3e994322d6d862ff51dcce25a0759e41c'

filebase=$(basename "$file" .iso)

# download iso
download_iso "$file" "$url" "$sha256"

# By this point, the ISO should be downloaded, verified, AND mounted,
# so you can do things, like copy syslinux files for TFTP.

# TODO copy vmlinuz and initrd.img to tftp dir

# NOTE: I'm using heredocs for the multiline config files, so if modifying
# these, MAKE SURE your editor does not replace the leading tabs with spaces.

write_iso_file "$file" repo <<- EOF
	[$filebase]
	name     = CentOS 6.10 ISO
	baseurl  = https://${MIRROR_HTTPD_SERVER_NAME}/iso/${filebase}/
	gpgkey   = https://${MIRROR_HTTPD_SERVER_NAME}/iso/${filebase}/RPM-GPG-KEY-CentOS-6
	gpgcheck = 1
	EOF

write_iso_file "$file" sha256 "$sha256  $file"

# TODO # write_iso_file "$file" menu-vanilla <<- EOF
# TODO # write_iso_file "$file" menu-troubleshooting <<- EOF
# TODO # write_iso_file "$file" kickstart-vanilla <<- EOF
# TODO # write_iso_file "$file" kickstart-troubleshooting <<- EOF
# TODO source "${selfdir}/tftp-rebuild-menu"
