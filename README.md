Run immediately after a fresh FreeBSD install. This script configures
the system, installs some packages, and sets up jails to run our app
services within.

# Usage

Configure the host system. You'll be prompted for various
user/passwords at the beginning, but then it can run unattended:

~~~
[workstation]~$ ./bin/serverconf user@host
~~~

Upload your public key for app user login:

~~~
[workstation]~$ ./bin/serverconf -k ~/.ssh/id_rsa.pub user@host
~~~

Help:

~~~
[workstation]~$ ./bin/serverconf -h
~~~

If all fails, upload the init script to the host system and run manually:

~~~
[workstation]~$ scp ./src/host-init.sh user@host:~/
[workstation]~$ ssh user@host
[host]~$ su - root -c "./host-init.sh"
~~~

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
[host]~$ jailcreate -j myjail -i 192.168.0.2
[host]~$ jlogin myjail
[myjail]~$ exit
[host]~$ jaildelete myjail
~~~

# Remote SSH Access

If your VM doesn't have any user accounts, you may need to permit
remote ssh access for `root`. In `/etc/ssh/sshd_config`, uncomment and
set the option `PermitRootLogin yes`, then restart the server with
`service sshd restart`.
