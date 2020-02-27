# Tested with:
#   RHEL 8.1
#   VirtualBox 6.1
#   Vagrant 2.2.7
# If you're having trouble building with vagrant, you should try:
#   vagrant plugin install vagrant-vbguest
# And (optional) I often use SCP for development:
#   vagrant plugin install vagrant-scp
# TODO Test on Windows
#   On a Windows host, /vagrant (a "sync'd" folder) will probably have
#   stupid permissions set and totally screw up the `cp` ...but, meh.
#   #WorksForMe #DearGodWhy #SucksToBeYou

Vagrant.configure("2") do |config|
	config.vm.provider "virtualbox" do |vb|
		vb.memory = 1024
		vb.cpus = 1
	end
	config.vm.box = "centos/7"
	config.vm.network "forwarded_port", guest: 80,  host: 8080
	config.vm.network "forwarded_port", guest: 443, host: 8443
	config.vm.provision "shell", privileged: true, inline: <<~'SHELL'
		cp -rf /vagrant /srv/mirror
		/srv/mirror/install.sh
	SHELL
end