#!/bin/sh -e

REPO_URL="https://bitbucket.org/hazelnut/serverconf.git"
REPO_ROOT="/usr/local/opt/$(basename $REPO_URL '.git')"

print_help () {
    echo "Initialize a new FreeBSD app server." >&2
    echo "Usage: $(basename $0) [options]" >&2
    echo "Options:" >&2
    echo " -h           Print this help message" >&2;
    echo " -d=dir       Location to install app [$REPO_ROOT]" >&2;
    echo " -u=username  User on host system to manage app (sudo privledges)" >&2
    echo " -p=password  App user password" >&2
    echo " -R=url       Repo url for server setup [$REPO_URL]" >&2
    echo " -U=username  Repo user" >&2
    echo " -P=password  Repo password" >&2
}

##
## SETUP
##

while getopts "d:u:p:R:U:P:h" opt; do
    case $opt in
        d) repo_root_arg="$OPTARG";;
        u) APP_USER="$OPTARG";;
        p) APP_PASS="$OPTARG";;
        R) repo_url_arg="$OPTARG";;
        U) REPO_USER="$OPTARG";;
        P) REPO_PASS="$OPTARG";;
        h) print_help; exit 0;;
        \?) print_help; exit 1;;
    esac
done

if [ $(uname -s) != "FreeBSD" ]; then
    echo "This script must be run on FreeBSD." 1>&2
    exit 1
fi

if [ $(id -u) != 0 ]; then
    echo "This script must be run as root." 1>&2
    echo "If a member of the 'wheel' group, try: su - root -c \"./$(basename $0) -h\"" 1>&2
    exit 1
fi

if [ -z "$APP_USER" ]; then
    read -p "Enter the app user: " APP_USER
    if [ -z "$APP_USER" ]; then
        echo "Requires a user, aborting." 1>&2
        exit 1
    fi
fi
if [ -z "$APP_PASS" ]; then
    stty -echo
    read -p "Password for app user '$APP_USER': " APP_PASS; echo
    stty echo
    if [ -z "$APP_PASS" ]; then
        echo "Invalid password, aborting." 1>&2
        exit 1
    fi
fi

if [ -n "$repo_root_arg" ]; then
    REPO_ROOT="$repo_root_arg"
fi

if [ -n "$repo_url_arg" ]; then
    REPO_URL="$repo_url_arg"
    #if passed a new url and not a new root path, recalc root path
    if [ -z "$repo_root_arg" ]; then
        REPO_ROOT="/usr/local/opt/$(basename $REPO_URL '.git')"
    fi
fi

repo_host=$(echo "$REPO_URL" | awk -F/ '{print $3}')

if [ -z "$REPO_USER" ]; then
    read -p "'$repo_host' username: " REPO_USER
fi
if [ -z "$REPO_PASS" ]; then
    stty -echo
    read -p "'$repo_host' password: " REPO_PASS; echo
    stty echo
fi

REPO_AUTH="https://$REPO_USER:$REPO_PASS@${REPO_URL#*//}"

##
## BASE PACKAGES
##

env PAGER=cat freebsd-update fetch install

## Update package system (binaries)
if ! pkg -N >/dev/null 2>&1; then
    env ASSUME_ALWAYS_YES=YES pkg bootstrap
fi
pkg update

#installs bloated versions, but quick to fetch. should use portmaster
pkg install --yes sudo bash bash-completion git emacs-nox11 ezjail
# pkg install en-freebsd-doc

#install ports tree (source)
# portsnap fetch extract

#show build options: make showconfig
# cd /usr/ports/shells/bash && env BATCH=1 make install clean
# cd /usr/ports/shells/bash-completion && env BATCH=1 make install clean
# cd /usr/ports/security/sudo && env BATCH=1 make install clean
# cd /usr/ports/ports-mgmt/portmaster && env WITH="BASH" BATCH=1 make install clean
# cd /usr/ports/devel/git
# env WITHOUT="CONTRIB CVS ETCSHELLS P4 PERL" BATCH=1 make install clean
# cd /usr/ports/editors/emacs-nox11
# env WITHOUT="GNUTLS SOURCES XML" BATCH=1 make install clean
# cd /usr/ports/sysutils/ezjail && env BATCH=1 make install clean

##
## SYSTEM CONFIG
##

mkdir -p "$REPO_ROOT"
if ! git clone "$REPO_AUTH" "$REPO_ROOT"; then
    echo "Unable to download repo, aborting." 1>&2
    exit 1
fi

cp_conf_dir () {
  local srcdir="$1" destdir=$(readlink -f "$2")
  env HOST_CONF_DIR="$REPO_ROOT/host" \
      sh -e "$REPO_ROOT/src/copy-conf-dir.sh" "$srcdir" "$destdir"
}

cp_conf_dir "$REPO_ROOT/host/etc" /etc
cp_conf_dir "$REPO_ROOT/host/usr/local/etc" /usr/local/etc
cp_conf_dir "$REPO_ROOT/host/usr/share/skel" /usr/share/skel

#create 1g swap file, referenced in /etc/fstab
dd if=/dev/zero of=/usr/swap0 bs=1m count=1024

#reload /etc/fstab
mount -a
#load swap file. verify with: swapinfo -g
swapon -aqL

#git doesn't keep permissions
chmod 700 /usr/share/skel/dot.ssh
chmod 600 /usr/share/skel/dot.ssh/authorized_keys

ln -s "$REPO_ROOT"/host/usr/local/bin/* /usr/local/bin/
ln -s "$REPO_ROOT"/host/usr/local/sbin/* /usr/local/sbin/

service netif start lo1
service syslogd restart
service pf start
#pfctl -F all -f /etc/pf.conf
#service ntpd start

##
## USERS
##

#root environment
chsh -s /bin/sh
cp /usr/share/skel/dot.profile "$HOME/.profile" #use updated version

pw groupadd jailed #access to jexec

if [ -n "$APP_PASS" ]; then
    echo "$APP_PASS" | pw useradd -n "$APP_USER" -m -G wheel,jailed -s /usr/local/bin/bash -h 0
else
    pw useradd -n "$APP_USER" -m -G wheel,jailed -s /usr/local/bin/bash
    passwd "$APP_USER"
fi

#make owner of repo
chown -R "$APP_USER" "$REPO_ROOT"

##
## APP JAILS
##

#installs the basejail (use -sp for sources and ports)
ezjail-admin install

# jail-create -j www -i 192.168.0.1 -u "$APP_USER" -t www
# jail-create -j db -i 192.168.0.2 -t postgresql -u "$APP_USER"
# jail-create -j redis -i 192.168.0.3 -t redis
# jail-create -j rabbitmq -i 192.168.0.3 -t rabbitmq

##
## CLEANUP
##

cd "$HOME"
echo "Done. Should probably reboot."

exec /usr/bin/env ENV="$HOME/.profile" /bin/sh
