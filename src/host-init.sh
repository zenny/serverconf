#!/bin/sh -e

REPO_URL="https://bitbucket.org/hazelnut/serverconf.git"
APP_ROOT="/usr/local/opt/$(basename $REPO_URL '.git')"
SWAP_FILE_SIZE=1024 #1gig
MAIL_SERVER="smtp.gmail.com:587"
MAIL_USER="serverconfstatus@gmail.com"
MAIL_PASSWORD=''

print_help () {
  echo "Configure the FreeBSD app server. Run on the host system." >&2;
  echo "Usage: $(basename $0) [options]" >&2;
  echo "Options:" >&2;
  echo " -h           Print this help message" >&2;
  echo " -j=jail(s)   List of jail types to install on the host" >&2;
  echo "              e.g. 'default:192.168.0.1,postgresql:192.168.0.2'" >&2;
  echo " -u=username  User on host system to manage app (sudo privledges)" >&2;
  echo " -p=password  App user password" >&2;
  echo " -U=username  Repo user" >&2;
  echo " -P=password  Repo password" >&2;
}

##
## SETUP
##

while getopts "j:u:p:U:P:h" opt; do
  case $opt in
    j) JAILLIST="$OPTARG";;
    u) APP_USER="$OPTARG";;
    p) APP_PASS="$OPTARG";;
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

repo_host=$(echo "$REPO_URL" | awk -F/ '{print $3}')

if [ -z "$REPO_USER" ]; then
  read -p "'$repo_host' username: " REPO_USER
fi

if [ -z "$REPO_PASS" ]; then
  stty -echo
  read -p "'$repo_host' password: " REPO_PASS; echo
  stty echo
fi

#outgoing mail only. no command-line options, use env
if [ -n "$MAIL_USER" -a -z "$MAIL_PASSWORD" ]; then
  echo "Configuring mail for '$MAIL_SERVER' (outgoing only)"
  stty -echo
  read -p "'$MAIL_USER' password: " MAIL_PASSWORD; echo
  stty echo
fi

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
pkg install --yes sudo bash bash-completion git emacs-nox11 ezjail ssmtp
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
## DOWNLOAD REPO
##

repo_auth_url="https://$REPO_USER:$REPO_PASS@${REPO_URL#*//}"

mkdir -p "$APP_ROOT"

if ! git clone "$repo_auth_url" "$APP_ROOT"; then
  echo "Unable to download repo, aborting." 1>&2
  exit 1
fi

##
## SYSTEM CONFIG
##

#turn off swap using current /etc/fstab. will reload later
swapoff -aL

cp_conf () {
  local srcpath="$1" destdir="$2"
  env REPLACE_VARS='HOST_CONF_DIR MAIL_SERVER MAIL_USER MAIL_PASSWORD' \
      HOST_CONF_DIR="$APP_ROOT/host" \
      MAIL_SERVER="$MAIL_SERVER" \
      MAIL_USER="$MAIL_USER" \
      MAIL_PASSWORD="$MAIL_PASSWORD" \
      sh -e "$APP_ROOT/src/cp-conf.sh" "$srcpath" "$destdir"
}

cp_conf "$APP_ROOT/host/etc" /etc
cp_conf "$APP_ROOT/host/usr/local/etc" /usr/local/etc
env NO_REPLACE_VARS='HOSTNAME HOST USER' \
    cp_conf "$APP_ROOT/host/usr/share/skel" /usr/share/skel

#git doesn't keep permissions
chmod 700 /usr/share/skel/dot.ssh
chmod 600 /usr/share/skel/dot.ssh/authorized_keys

ln -s "$APP_ROOT"/host/usr/local/bin/* /usr/local/bin/
ln -s "$APP_ROOT"/host/usr/local/sbin/* /usr/local/sbin/

# Create swap file, referenced in /etc/fstab
swap_file="/usr/swap0"
echo "Creating swap file $swap_file (${SWAP_FILE_SIZE}m) ..."

dd if=/dev/zero of="$swap_file" bs=1m count="$SWAP_FILE_SIZE"

#reload /etc/fstab
mount -a
#load swap file. will error if swap isn't off: swapoff -aL
swapon -aL
#verify swap
swapinfo -hm

# Restart services
service syslogd restart
service netif cloneup lo1
service pf start
#pfctl -F all -f /etc/pf.conf
#service ntpd start

#sendmail replaced with outbound-only ssmtp
service sendmail stop
chmod -R 640 /usr/local/etc/ssmtp

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
chown -R "$APP_USER" "$APP_ROOT"

##
## APP JAILS
##

#installs the basejail (use -sp for sources and ports)
ezjail-admin install

# jail list format: 'id:ip[:type],...'
# if [ -n "$JAILLIST" ]; then
#   for jailarg in $(echo "$JAILLIST" | tr ',' ' '); do
#     jailid=$(echo "$jailarg" | cut -d ':' -f1)
#     jailip=$(echo "$jailarg" | cut -d ':' -f2)
#     jailtype=$(echo "$jailarg" | cut -d ':' -f3)
#     echo "Creating jail '$jailid' (type: $jailtype) on $jailip"
#     jailcreate -j "$jailid" -i "$jailip" -t "$jailtype" -u "$APP_USER"
#   done
# fi

# jailcreate -j www -i 192.168.0.1 -u "$APP_USER" -t www
# jailcreate -j db -i 192.168.0.2 -t postgresql -u "$APP_USER"
# jailcreate -j redis -i 192.168.0.3 -t redis
# jailcreate -j rabbitmq -i 192.168.0.3 -t rabbitmq

##
## CLEANUP
##

echo "Done. Should probably reboot."

#exec /usr/bin/env ENV="$HOME/.profile" /bin/sh
