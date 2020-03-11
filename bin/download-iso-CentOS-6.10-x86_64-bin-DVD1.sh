#!/bin/bash

self=$(readlink -f "$0")
selfdir=$(dirname "$self")
source "${selfdir}/inc/require_root.sh"
source "${selfdir}/inc/read_config.sh"
source "${selfdir}/inc/iso.sh"

################################################################################

# source:  http://mirror.centos.org/centos/6.10/isos/x86_64/sha256sum.txt
file='CentOS-6.10-x86_64-bin-DVD1.iso' # must end in lowercase .iso
url='http://isoredirect.centos.org/centos/6.10/isos/x86_64/CentOS-6.10-x86_64-bin-DVD1.iso'
sha256='a68e46970678d4d297d46086ae2efdd3e994322d6d862ff51dcce25a0759e41c'

filebase=$(basename "$file" .iso)

# download iso
download_iso "$file" "$url" "$sha256"

# write a sha256 checksum
echo "$sha256  $file" > "${MIRROR_BASE_PATH}/www/iso/${filebase}.sha256"

# write a yum repo file
cat <<- EOF > "${MIRROR_BASE_PATH}/www/iso/${filebase}.repo"
	[centos-6.10-iso]
	name     = CentOS 6.10 ISO
	baseurl  = https://${MIRROR_HTTPD_SERVER_NAME}/iso/${filebase}/
	gpgkey   = https://${MIRROR_HTTPD_SERVER_NAME}/iso/${filebase}/RPM-GPG-KEY-CentOS-6
	gpgcheck = 1
	EOF
