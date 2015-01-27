Run immediately after a fresh FreeBSD install. This script configures
the system, installs some packages, and sets up jails to run our app
services within.

# Usage

~~~
[workstation]~$ ./bin/serverconf -h
~~~

To configure the host FreeBSD system, simply pass the remote account
to log in with. This account needs to run the script with superuser
privledges, so make sure it's a member of the *wheel* group. The
script will prompt you for various user/passwords at the beginning but
can then be run unattended:

~~~
[workstation]~$ ./bin/serverconf user@host
~~~

You'll be prompted for a ssh public key to configure your server for
password-less logins. If you need to generate a new key pair run:

~~~
[workstation]~$ ssh-keygen -b 4096 -C "billy@example.com"
...
[workstation]~$ ./bin/serverconf -k ~/.ssh/id_rsa.pub user@host
~~~

This key will also be used for the additional admin user you create.
If you configure the server using the root account, that account won't
save the key.

If you've logged into the remote host already, you can download the
install script directly and then run it on localhost:

~~~
[host]~$ fetch --no-verify-peer --user-agent 'Wget/1.16' https://bitbucket.org/hazelnut/serverconf/raw/master/bin/serverconf
...
[host]~$ sh -e ./serverconf localhost
~~~

On a fresh FreeBSD system use the `fetch` command to download files.
The `--no-verify-peer` argument skips over SSL verification since
those libraries haven't been installed yet. We need to spoof our
user-agent because of a bug in BitBucket.

# Config Files

Host system configuration files are located in the `./host` directory,
and jail config files are located in their `./jails/{type}` directory.

Files in these directories are copied to their respective systems and
*overwrite* an existing file unless the file name ends with `_append`.
In that case, the file is concatenated to the end of the existing
file, so, for example, entries in the file `./host/etc/hosts_append`
are added to the `/etc/hosts` file.

# Additional Commands

See `./host/usr/local/bin` and `./host/usr/local/sbin` for some useful commands.

~~~
[host]~$ jls
[host]~$ jailconf -n myjail -i 192.168.0.2
[host]~$ jlogin myjail
[myjail]~$ exit
[host]~$ jaildelete myjail
~~~

# Remote SSH Access

If your VM doesn't have any user accounts, you may need to permit
remote ssh access for `root`. In `/etc/ssh/sshd_config`, uncomment and
set the option `PermitRootLogin yes`, then restart the server with
`service sshd restart`.
