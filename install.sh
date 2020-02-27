#!/bin/bash

################################################################################

function init {
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

function install_web_server_packages {
  echo 'installing web server packages'
  yum -y install \
    @base @core vim policycoreutils-python \
    httpd mod_ssl openssl \
    createrepo pykickstart
}

function config_generate_ssl_certs {
  key="/etc/pki/tls/private/${MIRROR_HTTPD_SERVER_NAME}.key" # private key
  cfg="/etc/pki/tls/certs/${MIRROR_HTTPD_SERVER_NAME}.cfg"   # csr template
  csr="/etc/pki/tls/certs/${MIRROR_HTTPD_SERVER_NAME}.csr"   # cert signing req
  crt="/etc/pki/tls/certs/${MIRROR_HTTPD_SERVER_NAME}.crt"   # public cert

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

function config_web_server {
  echo 'configuring the web server'

  systemctl restart firewalld
  firewall-cmd --permanent --add-service=http
  firewall-cmd --permanent --add-service=https
  firewall-cmd --reload

  > /etc/httpd/conf.d/welcome.conf

  rm -f /etc/httpd/conf.d/autoindex.conf
  ln -s "${MIRROR_BASE_PATH}/etc/httpd/autoindex.conf"     /etc/httpd/conf.d/
  ln -s "${MIRROR_BASE_PATH}/etc/httpd/mirror.conf"        /etc/httpd/conf.d/
  ln -s "${MIRROR_BASE_PATH}/etc/httpd/mirror.conf-common" /etc/httpd/conf.d/

  for i in "${MIRROR_HTTPD_SERVER_ALIAS[@]}"
  do
    printf -v line '  %-26s "%s"\n' "ServerAlias" "$i"
    export MIRROR_HTTPD_SERVER_ALIAS_GENERATED+="$line"
  done

  envsubst \
    < "${MIRROR_BASE_PATH}/etc/httpd/mirror.conf.template" \
    > "${MIRROR_BASE_PATH}/etc/httpd/mirror.conf"
}

function config_selinux_paths {
  echo 'configuring selinux paths'
  semanage fcontext -a -t httpd_config_t          "${MIRROR_BASE_PATH}/etc/httpd(/.*)?"
  semanage fcontext -a -t httpd_sys_content_t     "${MIRROR_BASE_PATH}/www(/.*)?"
  semanage fcontext -a -t httpd_sys_content_t     "${MIRROR_BASE_PATH}/theme(/.*)?"
  semanage fcontext -a -t tftpdir_t               "${MIRROR_BASE_PATH}/tftp(/.*)?"
  # TODO maybe? allow the auto gen; not happy about it today
  # semanage fcontext -a -t httpd_sys_script_exec_t "${MIRROR_BASE_PATH}/www/ks/auto"
  restorecon -R -v "${MIRROR_BASE_PATH}"
}

function install_update_cronjob {
  echo 'installing mirror cronjob'
  ln -s "${MIRROR_BASE_PATH}/etc/cron.d/mirror" /etc/cron.d/mirror
}

function install_logrotate_config {
  echo 'installing mirror logrotate config'
  ln -s "${MIRROR_BASE_PATH}/etc/logrotate.d/mirror" /etc/logrotate.d/mirror
}

################################################################################

init

install_web_server_packages
config_generate_ssl_certs
config_web_server
config_selinux_paths

systemctl enable  httpd
systemctl restart httpd

install_update_cronjob
install_logrotate_config
