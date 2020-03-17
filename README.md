# mirror WIP (not yet complete)
Local mirror for building Linux systems - serves TFTP for PXEboot and HTTP/S
for everything else.  This is useful for imaging physical machines and local
development environments.  Or if you haven't upgraded to orchestration tools
like `terraform` (and `packer` for image builds), this might help in a pinch.



# Installation




### Vagrant stuff

vagrant plugin install vagrant-scp
vagrant plugin install vagrant-vbguest

### Features

install from vagrant
install from netinstall iso
	pick iso version to start from
	add kickstart on command line
install from packer
	attach storage
	snapshot?

add disk snapshot support
add pxe menu for convenience
add disk for mirror vg1



### Design decisions
