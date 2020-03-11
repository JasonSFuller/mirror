#!/bin/bash

################################################################################

function init
{
  if [[ "$(id -u)" -ne 0 ]]; then
    echo "ERROR: you must be root" 2>&1
    exit 1
  fi

  local self=$(readlink -f "$0")
  local selfdir=$(dirname "$self")
  MIRROR_CONFIG="${selfdir}/etc/mirror.conf"
  now=$(date +%Y%m%d%H%M%S)

  if [[ -r "${MIRROR_CONFIG}" ]]; then
    source "${MIRROR_CONFIG}"
  else
    echo "ERROR: could not read config (${MIRROR_CONFIG})" 2>&1
    exit 1
  fi
}

function install_packages
{
  echo 'installing required packages'

  yum -y install \
    @base @core vim policycoreutils-python \
    httpd mod_ssl openssl \
    createrepo pykickstart \
    tftp-server xinetd syslinux-tftpboot memtest86+ \
    tftp telnet nmap # troubleshooting
}



function config_generate_ssl_certs
{
  echo 'generating self-signed certs'

  key="/etc/pki/tls/private/${MIRROR_HTTPD_SERVER_NAME}.key"
  cfg="/etc/pki/tls/certs/${MIRROR_HTTPD_SERVER_NAME}.cfg"
  csr="/etc/pki/tls/certs/${MIRROR_HTTPD_SERVER_NAME}.csr"
  crt="/etc/pki/tls/certs/${MIRROR_HTTPD_SERVER_NAME}.crt"

  echo "  private key      = $key"
  echo "  csr template     = $cfg"
  echo "  cert signing req = $csr"
  echo "  public cert      = $crt"

  if [[ ! -f "$key" ]]; then
    openssl genrsa -out "$key" 4096
    chmod 600 "$key"
  fi

  if [[ ! -f "$cfg" ]]; then
    cat <<- EOF > "$cfg"
			default_bits       = 2048
			default_md         = sha256
			prompt             = no
			distinguished_name = dn
			extensions         = ext
			req_extensions     = ext
			x509_extensions    = ext

			[ dn ]
			#C                  = My Country Code
			#ST                 = My State
			#L                  = My Location
			#O                  = My Organization
			#OU                 = My Organizational Unit
			#emailAddress       = My Email Address
			CN                 = ${MIRROR_HTTPD_SERVER_NAME}

			[ ext ]
			subjectAltName     = @san

			[ san ]
			DNS.0 = ${MIRROR_HTTPD_SERVER_NAME}
			EOF

    # Add the alternate DNS hostnames to the template.
    for ((i=0; i<${#MIRROR_HTTPD_SERVER_ALIAS[*]}; i++))
    do
      echo "DNS.$((i+1)) = ${MIRROR_HTTPD_SERVER_ALIAS[i]}" >> "$cfg"
    done
  fi

  if [[ -f "$csr" ]]; then
    echo "Found existing CSR; creating backup '${csr}.${now}.backup' and generating a new one."
    mv "$csr" "${csr}.${now}.backup"
  fi
  openssl req -new -config "$cfg" -key "$key" -out "$csr"

  if [[ ! -f "$crt" ]]; then
    openssl req -x509 -days 3650 -key "$key" -in "$csr" -out "$crt"
  fi
}



function config_web_server
{
  echo 'configuring the web server'

  firewall-offline-cmd --add-service=http
  firewall-offline-cmd --add-service=https

  > /etc/httpd/conf.d/welcome.conf

  rm -f /etc/httpd/conf.d/autoindex.conf
  ln -s "${MIRROR_BASE_PATH}/etc/httpd/autoindex.conf"  /etc/httpd/conf.d/
  ln -s "${MIRROR_BASE_PATH}/etc/httpd/mirror-www.conf" /etc/httpd/conf.d/

  for i in "${MIRROR_HTTPD_SERVER_ALIAS[@]}"
  do
    printf -v line '  %-26s "%s"\n' "ServerAlias" "$i"
    export MIRROR_HTTPD_SERVER_ALIAS_GENERATED+="$line"
  done

  envsubst \
    < "${MIRROR_BASE_PATH}/etc/httpd/mirror-www.conf.template" \
    > "${MIRROR_BASE_PATH}/etc/httpd/mirror-www.conf"
}



function config_tftp_server
{
  echo "configuring the tftp server"

  firewall-offline-cmd --add-service=tftp

  cp -a /etc/xinetd.d/tftp{,.${now}.backup}
  sed -i -r 's/^(\s*disable\s*=).*/\1 no/' /etc/xinetd.d/tftp
  sed -i -r "s#^(\\s*server_args\\s*=).*#\\1 -v -s ${MIRROR_BASE_PATH}/tftp#" /etc/xinetd.d/tftp

  # TODO copy syslinux c32 files
  # TODO copy memtest86+ kernel
}



function config_selinux_paths
{
  echo 'configuring selinux paths'

  semanage fcontext -a -t httpd_config_t          "${MIRROR_BASE_PATH}/etc/httpd(/.*)?"
  semanage fcontext -a -t httpd_sys_content_t     "${MIRROR_BASE_PATH}/www(/.*)?"
  semanage fcontext -a -t httpd_sys_content_t     "${MIRROR_BASE_PATH}/theme(/.*)?"
  semanage fcontext -a -t tftpdir_t               "${MIRROR_BASE_PATH}/tftp(/.*)?"
  # TODO maybe? allow the auto gen; not happy about it today
  # semanage fcontext -a -t httpd_sys_script_exec_t "${MIRROR_BASE_PATH}/www/ks/auto"

  restorecon -R -v "${MIRROR_BASE_PATH}"
}



function install_update_cronjob
{
  echo 'installing mirror cronjob'
  ln -s "${MIRROR_BASE_PATH}/etc/cron.d/mirror" /etc/cron.d/mirror
}



function install_logrotate_config
{
  echo 'installing mirror logrotate config'
  ln -s "${MIRROR_BASE_PATH}/etc/logrotate.d/mirror" /etc/logrotate.d/mirror
}



################################################################################

init

install_packages
config_generate_ssl_certs
config_web_server
config_tftp_server
config_selinux_paths

systemctl enable  httpd
systemctl restart httpd
systemctl enable  xinetd # tftp
systemctl restart xinetd # tftp
systemctl enable  firewalld
systemctl restart firewalld

install_update_cronjob
install_logrotate_config
