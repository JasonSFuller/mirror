#!/bin/bash

self=$(readlink -f "$0")
selfdir=$(dirname "$self")
source "${selfdir}/inc/require_root.sh"
source "${selfdir}/inc/read_config.sh"
source "${selfdir}/inc/iso.sh"

################################################################################

# source:  http://mirror.centos.org/centos/7.7.1908/isos/x86_64/sha256sum.txt
file='CentOS-7-x86_64-Everything-1908.iso'
url='http://isoredirect.centos.org/centos/7.7.1908/isos/x86_64/CentOS-7-x86_64-Everything-1908.iso'
sha256='bd5e6ca18386e8a8e0b5a9e906297b5610095e375e4d02342f07f32022b13acf'

filebase=$(basename "$file" .iso)

# download iso
download_iso "$file" "$url" "$sha256"

# write a sha256 checksum
echo "$sha256  $file" > "${MIRROR_BASE_PATH}/www/iso/${filebase}.sha256"

# write a yum repo file
cat <<- EOF > "${MIRROR_BASE_PATH}/www/iso/${filebase}.repo"
	[centos-7.7-iso]
	name     = CentOS 7.7 ISO
	baseurl  = https://${MIRROR_HTTPD_SERVER_NAME}/iso/${filebase}/
	gpgkey   = https://${MIRROR_HTTPD_SERVER_NAME}/iso/${filebase}/RPM-GPG-KEY-CentOS-7
	gpgcheck = 1
	EOF
