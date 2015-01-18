# Post-Installation

Run immediately after the FreeBSD base install. Configure the system, install some packages, and
set up some jails to run our services within.


Since VirtualBox is not copy/paste friendly, you may need to ssh in as
root. In `/etc/ssh/sshd_config`, uncomment and set the option
`PermitRootLogin yes`. Restart the server with `service sshd restart`.

## Post-Post Installation

To allow the *wheel* group access to `sudo`, edit its config file
using `visudo`. (You may need change your default editor with
`setenv EDITOR ee` if you're still in the default *csh*.)
Uncomment the line: `%wheel ALL=(ALL) ALL`.

If you allowed remote root login via ssh for setup, you should
uncomment that line in `/etc/ssh/sshd_config`.

Log in to jail using: `jlogin myjail` (or `ezjail-admin console myjail`)
