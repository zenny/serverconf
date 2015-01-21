#!/bin/sh -e
## Run on the host machine to install packages and configure the server.

REPO_URL="https://bitbucket.org/hazelnut/serverconf.git"
APP_ROOT="/usr/local/opt/$(basename $REPO_URL '.git')"
SWAP_FILE_SIZE=1024 #1g
MAIL_SERVER="smtp.gmail.com:587"
MAIL_USER="serverconfstatus@gmail.com"
MAIL_PASSWORD=''

print_help () {
  echo "Configure the FreeBSD app server. Run on the host system." >&2;
  echo "Usage: $(basename $0) [options]" >&2;
  echo "Options:" >&2;
  echo " -h           Print this help message" >&2;
  echo " -u=username  User on host system to manage app (sudo privledges)" >&2;
  echo " -p=password  App user password" >&2;
  echo " -k=pubkey    App user public key" >&2;
  echo " -U=username  Repo user" >&2;
  echo " -P=password  Repo password" >&2;
}

cp_conf () {
  local srcpath="$1" destdir="$2" replacevars="$3" ignorevars="$4"
  env REPLACE_VARS="$replacevars HOST_CONF_DIR MAIL_SERVER MAIL_USER MAIL_PASSWORD" \
      NO_REPLACE_VARS="$ignorevars" \
      HOST_CONF_DIR="$APP_ROOT/host" \
      MAIL_SERVER="$MAIL_SERVER" \
      MAIL_USER="$MAIL_USER" \
      MAIL_PASSWORD="$MAIL_PASSWORD" \
      sh -e "$APP_ROOT/src/cp-conf.sh" "$srcpath" "$destdir"
}

## Sanity checks

if [ $(uname -s) != "FreeBSD" ]; then
  echo "This script must be run on FreeBSD." 1>&2
  exit 1
fi

if [ $(id -u) != 0 ]; then
  echo "This script must be run as root." 1>&2
  echo "If a member of the 'wheel' group, try: su - root -c \"./$(basename $0) -h\"" 1>&2
  exit 1
fi

##
## PARSE OPTIONS
##

while getopts "u:p:U:P:k:h" opt; do
  case $opt in
    u) APP_USER="$OPTARG";;
    p) APP_PASS="$OPTARG";;
    U) REPO_USER="$OPTARG";;
    P) REPO_PASS="$OPTARG";;
    k) USER_PUBKEY="$OPTARG";;
    h) print_help; exit 0;;
    \?) print_help; exit 1;;
  esac
done

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
## INSTALL PACKAGES
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


## Install this project

repo_auth_url="https://$REPO_USER:$REPO_PASS@${REPO_URL#*//}"

mkdir -p "$APP_ROOT"

if ! git clone "$repo_auth_url" "$APP_ROOT"; then
  echo "Unable to download repo, aborting." 1>&2
  exit 1
fi

ln -s "$APP_ROOT"/host/usr/local/bin/* /usr/local/bin/
ln -s "$APP_ROOT"/host/usr/local/sbin/* /usr/local/sbin/

##
## SYSTEM CONFIG
##

#turn off swap using current /etc/fstab. will reload later
swapoff -aL

cp_conf "$APP_ROOT/host/etc" /etc
cp_conf "$APP_ROOT/host/usr/local/etc" /usr/local/etc
cp_conf "$APP_ROOT/host/usr/share/skel" /usr/share/skel '' 'HOSTNAME HOST USER'

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

#restart services
service syslogd restart
service netif cloneup lo1
service pf start
#pfctl -F all -f /etc/pf.conf
#service ntpd start

#sendmail replaced with outbound-only ssmtp
service sendmail stop

# permissions
chmod 700 /usr/share/skel/dot.ssh
chmod 600 /usr/share/skel/dot.ssh/authorized_keys
chmod -R 640 /usr/local/etc/ssmtp

#installs the basejail (use -sp for sources and ports)
ezjail-admin install

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

#setup ssh keys for login. should disable password-based auth
if [ -n "$USER_PUBKEY" ]; then
  pubkey_file=$(mktemp)
  if [ -f "$USER_PUBKEY" ]; then
    cat "$USER_PUBKEY" > "$pubkey_file"
  else
    echo "$USER_PUBKEY" > "$pubkey_file"
  fi
  #check fingerprint to make sure it's a valid key
  if ssh-keygen -l -f "$pubkey_file" > /dev/null; then
    cat "$pubkey_file" >> "/home/$APP_USER/.ssh/authorized_keys"
  else
    echo "Invalid public key, not adding." >&2;
  fi
  rm "$pubkey_file"
fi

##
## FINISH
##

echo "Finished host setup, the system should probably reboot."
