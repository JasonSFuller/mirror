# git server

I typically create new servers locally (or on an intranet), where _requiring_
Internet access might be painful, so I'm creating [a simple, read-only git repo
over HTTP/S](https://git-scm.com/book/en/v2/Git-on-the-Server-The-Protocols).

> SIDE NOTE: If you want read-write, you should look at setting git up over SSH:
>
>   * https://git-scm.com/book/en/v2/Git-on-the-Server-Setting-Up-the-Server
>   * https://linuxize.com/post/how-to-setup-a-git-server/

Like [DNS and DHCP](dhcp-dns.md), setting up git is too complicated due to all
the possible variables, and so it is outside of the scope of this project and,
therefore, not included by default.

	yum -y install git

	mkdir -p /srv/mirror/www/git  && cd $_
	git init --bare myExampleRepo && cd $_
	cp -a hooks/post-update{.sample,}
	chmod a+x hooks/post-update

Example [post-update.sample](https://github.com/git/git/blob/master/templates/hooks--post-update.sample)
if your `git init` doesn't have one.  (If not, _how_ **old** is your `git`?)

# For quick and dirty local development

	mkdir ~/src && cd $_
	git clone file:///srv/mirror/www/git/myExampleRepo

	# then you can work as normal; example:
	git pull
	echo "# Readme" > README.md
	git add README.md
	git commit -m 'add readme'
	git push
