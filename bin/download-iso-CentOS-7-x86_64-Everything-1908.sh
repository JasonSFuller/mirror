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
if ! download_iso "$file" "$url" "$sha256"; then
  echo "ERROR: download failed" >&2
  exit 1
fi

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
	name     = CentOS 7.7 ISO
	baseurl  = https://${MIRROR_HTTPD_SERVER_NAME}/iso/${filebase}/
	gpgkey   = https://${MIRROR_HTTPD_SERVER_NAME}/iso/${filebase}/RPM-GPG-KEY-CentOS-7
	gpgcheck = 1
	EOF

write_iso_file "$file" sha256 "$sha256  $file"

write_iso_file "$file" menu-vanilla <<- EOF
	LABEL $filebase
	  MENU LABEL Install CentOS 7.7
	  KERNEL images/$filebase/vmlinuz
	  APPEND initrd=images/$filebase/initrd.img inst.noverifyssl inst.ks=https://${MIRROR_HTTPD_SERVER_NAME}/ks/vanilla.${filebase}.repo
	EOF

write_iso_file "$file" menu-troubleshooting <<- EOF
	LABEL $filebase
	  MENU LABEL Rescue mode using CentOS 7.7
	  KERNEL images/$filebase/vmlinuz
	  APPEND initrd=images/$filebase/initrd.img inst.noverifyssl inst.ks=https://${MIRROR_HTTPD_SERVER_NAME}/ks/troubleshooting.${filebase}.repo
	EOF

write_iso_file "$file" kickstart-vanilla <<- EOF
	url  --noverifyssl --url='https://${MIRROR_HTTPD_SERVER_NAME}/iso/$filebase'
	network --bootproto=dhcp
	rootpw --iscrypted ${MIRROR_CRYPTED_ROOTPW}
	lang en_US
	keyboard us
	timezone --utc America/New_York
	auth --passalgo=sha512 --useshadow
	selinux --enforcing
	firewall --enabled --service=ssh
	firstboot --disable
	skipx
	text
	reboot
	# --------------------------------------------------------------------
	zerombr
	bootloader --location=mbr
	clearpart --all --initlabel
	part      /boot       --fstype=ext4  --size=512
	part      pv.01       --fstype=lvmpv --size=1 --ondisk=sda --grow
	volgroup  vg0  pv.01  --pesize=4096
	logvol    /           --fstype=ext4  --name=root  --vgname=vg0 --size=4096
	logvol    swap        --fstype=swap  --name=swap  --vgname=vg0 --size=2048
	logvol    /tmp        --fstype=ext4  --name=tmp   --vgname=vg0 --size=2048
	logvol    /var/log    --fstype=ext4  --name=var   --vgname=vg0 --size=2048
	# --------------------------------------------------------------------
	%packages
	@base
	@core
	ca-certificates
	openssl
	vim-enhanced
	wget
	rsync
	screen
	dstat
	git
	bind-utils
	nfs-utils
	yum-utils
	rpm-build
	rpmdevtools
	redhat-lsb
	bash-completion
	policycoreutils-python
	setroubleshoot-server
	uuid
	nmap
	nmap-ncat
	telnet
	%end

	%post
	# grow the root volume to whatever size is available on the disk
	lvextend -r -l +100%FREE /dev/vg0/root
	%end
	EOF

# TODO # install mirror cert
# TODO # disable all default repos
# TODO # enable mirror repos (base, updates, extras???)

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
