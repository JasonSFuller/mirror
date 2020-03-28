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
# DEBUG # download_iso "$file" "$url" "$sha256"

# By this point, the ISO should be downloaded, verified, AND mounted,
# so you can do things, like copy syslinux files for TFTP.

install -m 755 -o root -g root -d "${MIRROR_BASE_PATH}/tftp/images/${filebase}"
install -m 644 -o root -g root \
  "${MIRROR_BASE_PATH}/www/iso/${filebase}/images/pxeboot/vmlinuz" \
  "${MIRROR_BASE_PATH}/tftp/images/${filebase}/"
install -m 644 -o root -g root \
  "${MIRROR_BASE_PATH}/www/iso/${filebase}/images/pxeboot/initrd.img" \
  "${MIRROR_BASE_PATH}/tftp/images/${filebase}/"

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

write_iso_file "$file" menu-vanilla <<- EOF
	LABEL $filebase
	  MENU LABEL Install CentOS 6.10
	  KERNEL images/$filebase/vmlinuz
	  # TODO # APPEND initrd=images/$filebase/initrd.img inst.noverifyssl inst.ks=https://${MIRROR_HTTPD_SERVER_NAME}/ks/vanilla.${filebase}.repo
	  APPEND initrd=images/$filebase/initrd.img
	EOF

write_iso_file "$file" menu-troubleshooting <<- EOF
	LABEL $filebase
	  MENU LABEL Rescue mode using CentOS 6.10
	  KERNEL images/$filebase/vmlinuz
	  APPEND initrd=images/$filebase/initrd.img inst.noverifyssl inst.ks=https://${MIRROR_HTTPD_SERVER_NAME}/ks/troubleshooting.${filebase}.repo
	EOF

# TODO # write_iso_file "$file" kickstart-vanilla <<- EOF

# TODO # install mirror cert
# TODO # disable all default repos
# TODO # enable mirror repos (base, updates, extras???)
# TODO # resize disk
# TODO # add packages i like

write_iso_file "$file" kickstart-troubleshooting <<- EOF
	rescue
	url --noverifyssl --url='https://${MIRROR_HTTPD_SERVER_NAME}/iso/$filebase'
	network --bootproto=dhcp
	lang en_US
	keyboard us
	timezone --utc America/New_York
	firewall --enabled --service=ssh
	EOF

source "${selfdir}/tftp-rebuild-menu"
