# Post-Installation

Run immediately after the FreeBSD base install. Configure the system, install some packages, and
set up some jails to run our services within.

Download the post-install script to the system that needs configuration:

~~~
~# fetch --no-verify-peer --user-agent "Wget/1.16" "https://$USER:$PASS@bitbucket.org/hazelnut/kola/raw/master/init/post-install.sh"
~~~

Changing the user-agent is a workaround for a BitBucket bug. The flag
`--no-verify-peer` ignores the SSL certificate, to use it:

~~~
~# pkg install ca_root_nss
~# ln -s /usr/local/share/certs/ca-root-nss.crt /etc/ssl/cert.pem
~~~

Run the post-install script:

~~~
~# sh ./post-install.sh
~~~

Since VirtualBox is not copy/paste friendly, you may need to ssh in as
root. In `/etc/ssh/sshd_config`, uncomment and set the option
`PermitRootLogin yes`. Restart the server with `service sshd restart`.


User scripts that run within jails can be added to the flavor, in
`$flavorDir/usr/local/bin` (may need to create the *bin* directory).


## Post-Post Installation

To allow the *wheel* group access to `sudo`, edit its config file
using `visudo`. (You may need change your default editor with
`setenv EDITOR ee` if you're still in the default *csh*.)
Uncomment the line: `%wheel ALL=(ALL) ALL`.

If you allowed remote root login via ssh for setup, you should
uncomment that line in `/etc/ssh/sshd_config`.

Log in to jail using: `jlogin myjail` (or `ezjail-admin console myjail`)
