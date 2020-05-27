# DNS and DHCP daemon installation

If you need DNS and DHCP (_e.g._ for testing in Vagrant or on a local LAN),
this might be helpful.  However, configuring DNS and DHCP for **your**
network is too complicated due to all the possible variables, and so it is
outside of the scope of this project and, therefore, not included by default.



## Install git

This is for colored output.  It isn't strictly necessary, but I use it below
when spot checking configs, since `diff` does not include the `--color` flag
in the current RHEL/CentOS 7 (and earlier) releases.

	yum -y install git
	git config --global color.ui auto

Then you can do things like this, even for files **not** in a git repo
(`--no-index`):

	git diff --no-index old.txt new.txt



## Install named (bind9)

	yum -y install bind bind-utils

	cp -a /etc/named.conf{,.$(date +%Y%m%d%H%M%S).orig}



### Edit the named config

	cat <<- 'EOF' > /etc/named.conf
		//
		// named.conf
		//
		// Provided by Red Hat bind package to configure the ISC BIND named(8) DNS
		// server as a caching only nameserver (as a localhost DNS resolver only).
		//
		// See /usr/share/doc/bind*/sample/ for example named configuration files.
		//
		// See the BIND Administrator's Reference Manual (ARM) for details about the
		// configuration located in /usr/share/doc/bind-{version}/Bv9ARM.html

		options {
		  listen-on port 53 { 127.0.0.1; 192.168.56.10; };
		  listen-on-v6 port 53 { ::1; };
		  directory 	"/var/named";
		  dump-file 	"/var/named/data/cache_dump.db";
		  statistics-file "/var/named/data/named_stats.txt";
		  memstatistics-file "/var/named/data/named_mem_stats.txt";
		  recursing-file  "/var/named/data/named.recursing";
		  secroots-file   "/var/named/data/named.secroots";
		  allow-query     { localhost; trusted; };
		  allow-transfer  { none; };

		  recursion yes;
		  allow-recursion { localhost; trusted; };

		  dnssec-enable yes;
		  dnssec-validation yes;

		  /* Path to ISC DLV key */
		  bindkeys-file "/etc/named.root.key";

		  managed-keys-directory "/var/named/dynamic";

		  pid-file "/run/named/named.pid";
		  session-keyfile "/run/named/session.key";
		};

		acl "trusted" {
		  192.168.0.0/16;
		};

		logging {
		  channel default_debug {
		    file "data/named.run";
		    severity dynamic;
		  };
		};

		zone "." IN {
		  type hint;
		  file "named.ca";
		};

		include "/etc/named.rfc1912.zones";
		include "/etc/named.root.key";

		zone "example.com" {
		  type master;
		  file "/etc/named/example.com.zone"; # example.com
		};

		zone "56.168.192.in-addr.arpa" {
		  type master;
		  file "/etc/named/56.168.192.in-addr.arpa.zone"; # 192.168.56.0/24
		};
		EOF

Verify the changes.

	git --no-pager diff --no-index /etc/named.conf.*.orig /etc/named.conf



### Add the example.com zone

	cat <<- 'EOF' > /etc/named/example.com.zone
		$TTL 1d
		@ IN SOA example.com. mirror.example.com. (
		; yyyymmddnn = serial number format
		  2020032000 ; serial <-- you MUST increase for ANY changes to take effect
		  1d         ; refresh
		  1h         ; retry
		  1w         ; expire
		  3h         ; minimum
		)
		;-- regular records ------------------------------------------------------------
		                    NS   mirror.example.com. ; name server
		                    A    192.168.56.10       ; default record (e.g. example.com)
		www                 A    192.168.56.10       ; www.example.com
		mirror              A    192.168.56.10       ; mirror.example.com
		;-- dhcp address range ---------------------------------------------------------
		EOF

	for i in {200..250}
	do
	  printf "%-19s %-4s %s\n" "dhcp-192-168-56-$i" "A" "192.168.56.$i" \
	    >> /etc/named/example.com.zone
	done



### Add reverse DNS (PTRs) for 192.168.56.0/24

	cat <<- 'EOF' > /etc/named/56.168.192.in-addr.arpa.zone
		$TTL 1d
		@ IN SOA localhost. root.localhost. (
		; yyyymmddnn = serial number format
		  2020032000 ; serial <-- you MUST increase for ANY changes to take effect
		  1d         ; refresh
		  1h         ; retry
		  1w         ; expire
		  3h         ; minimum
		)
		;-- regular records ------------------------------------------------------------
		                    NS   mirror.example.com.
		;-- dhcp address range ---------------------------------------------------------
		EOF

	for i in {200..250}
	do
	  printf "%-19s %-4s %s\n" "$i" "PTR" "dhcp-192-168-56-$i.example.com." \
	    >> /etc/named/56.168.192.in-addr.arpa.zone
	done



### Verify configs and enable services

	named-checkconf
	named-checkzone example.com /etc/named/example.com.zone
	named-checkzone 56.168.192.in-addr.arpa /etc/named/56.168.192.in-addr.arpa.zone

	systemctl enable  named
	systemctl restart named
	systemctl status  named

	firewall-offline-cmd --add-service dns
	systemctl restart firewalld



## Install ISC's dhcpd

	yum -y install dhcp

	cp -a /etc/dhcp/dhcpd6.conf{,.$(date +%Y%m%d%H%M%S).orig}
	cp -a /etc/dhcp/dhcpd.conf{,.$(date +%Y%m%d%H%M%S).orig}

	> /etc/dhcp/dhcpd6.conf

	cat <<- 'EOF' > /etc/dhcp/dhcpd.conf
		option domain-name "example.com";
		option domain-name-servers 192.168.56.10;
		default-lease-time 600;
		max-lease-time 7200;
		authoritative;
		allow booting;
		allow bootp;
		option option-128 code 128 = string;
		option option-129 code 129 = text;

		next-server 192.168.56.10;
		filename "/pxelinux.0";

		subnet 192.168.56.0 netmask 255.255.255.0 {
		  range 192.168.56.200 192.168.56.250;
		  option broadcast-address 192.168.56.255;
		  option routers 192.168.56.10;
		}
		EOF

	systemctl enable  dhcpd
	systemctl restart dhcpd
	systemctl status  dhcpd

	firewall-offline-cmd --add-service dhcp
	systemctl restart firewalld


