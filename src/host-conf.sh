#!/bin/sh -e

#no command-line options for these, use env to set:
if [ -z "$SWAP_FILE_SIZE" ]; then SWAP_FILE_SIZE=1024; fi #1gig
if [ -z "$MAIL_SERVER" ]; then MAIL_SERVER='smtp.gmail.com:587'; fi #outgoing only
if [ -z "$MAIL_USER" ]; then MAIL_USER=''; fi
if [ -z "$MAIL_PASSWORD" ]; then MAIL_PASSWORD=''; fi
if [ -z "$RESTART_FLAG" ]; then RESTART_FLAG=''; fi #will prompt, timeout to yes

REPO_URL="https://bitbucket.org/hazelnut/serverconf.git"
REPO_HOST=$(echo "$REPO_URL" | awk -F/ '{print $3}')
APP_ROOT="/usr/local/opt/$(basename $REPO_URL '.git')"

print_help () {
  echo "The main server configuration script. Run on the host system." >&2;
  echo "Usage: $(basename $0) [options]" >&2;
  echo "Options:" >&2;
  echo " -h           Print this help message" >&2;
  echo " -u=username  Admin user (required, will prompt)" >&2;
  echo " -p=password  Admin user password" >&2;
  echo " -k=pubkey    Admin user public ssh key for login (string)" >&2;
  echo " -U=username  App repo login ($REPO_HOST)" >&2;
  echo " -P=password  App repo password" >&2;
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
  echo "$(basename $0): This script must be run on FreeBSD." 1>&2
  exit 1
fi

if [ $(id -u) != 0 ]; then
  echo "$(basename $0): This script must be run as root." 1>&2
  echo "If a member of the 'wheel' group, try: su - root -c \"sh -e $0\"" 1>&2
  exit 1
fi

##
## PARSE OPTIONS
##

while getopts "u:p:k:U:P:h" opt; do
  case $opt in
    u) ADMIN_USER="$OPTARG";;
    p) ADMIN_PASS="$OPTARG";;
    k) PUBKEY="$OPTARG";;
    U) REPO_USER="$OPTARG";;
    P) REPO_PASS="$OPTARG";;
    h) print_help; exit 0;;
    \?) print_help; exit 1;;
  esac
done

if [ -z "$REPO_USER" ]; then
  read -p "'$REPO_HOST' username: " REPO_USER
fi

if [ -z "$REPO_PASS" ]; then
  stty -echo
  read -p "'$REPO_HOST' password: " REPO_PASS; echo
  stty echo
fi

#prompt for admin user. can be new user or this user, but not root.
if [ -z "$ADMIN_USER" -o "$ADMIN_USER" == 'root' ]; then
  if [ $(id -u) == 0 ]; then
    prompt_user="Add admin user (required): "
  else
    prompt_user="Add admin user [$(id -un)]: "
  fi
  read -p "$prompt_user" ADMIN_USER
  if [ -z "$ADMIN_USER" ]; then ADMIN_USER="$(id -un)"; fi

  if [ "$ADMIN_USER" == 'root' ]; then
    echo "$(basename $0): An admin user other than 'root' is required, exiting." >&2
    exit 1
  fi
fi

#prompt for password if not given and the user doesn't already exist
if [ -z "$ADMIN_PASS" ] && ! id "$ADMIN_USER" >/dev/null 2>&1; then
  stty -echo
  read -p "'$ADMIN_USER' password: " ADMIN_PASS; echo
  stty echo
  if [ -z "$ADMIN_PASS" ]; then
    echo "No password used"
  fi
fi

#outgoing mail only. no command-line option, use env
if [ -z "$MAIL_USER" ]; then
  echo "Configuring mail for '$MAIL_SERVER' (outgoing only)"
  read -p "Enter email address: " MAIL_USER
fi

if [ -n "$MAIL_USER" -a -z "$MAIL_PASSWORD" ]; then
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
pkg install --yes sudo bash bash-completion git emacs-nox11 ezjail ssmtp rsync
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
  echo "$(basename $0): Unable to download repo, aborting." 1>&2
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

# admin user

if id "$ADMIN_USER" >/dev/null 2>&1; then
  #admin user alreay exists. assumed in wheel group if running this script
  pw usermod "$ADMIN_USER" -G jailed
elif [ -n "$ADMIN_USER" ]; then
  #admin user doesn't exist, create
  if [ -n "$ADMIN_PASS" ]; then
    echo "$ADMIN_PASS" | pw useradd -n "$ADMIN_USER" -m -G wheel,jailed -s /usr/local/bin/bash -h 0
  else
    pw useradd -n "$ADMIN_USER" -m -G wheel,jailed -s /usr/local/bin/bash
  fi
else
  echo "$(basename $0): Unable to add an admin user, aborting." >&2;
  exit 1
fi

#make owner of this app
chown -R "$ADMIN_USER" "$APP_ROOT"

# if given a key param, let the admin use it

if [ -f "$PUBKEY" ]; then
  echo "$(basename $0): Pubkey param '$PUBKEY' is a file. That's confusing so not adding for $ADMIN_USER" >&2;

elif [ -n "$PUBKEY" -a "$ADMIN_USER" != "$(id -un)" ]; then
  #this account should already have the key installed
  keyfiletmp=$(mktemp -t 'pubkey')
  echo "$PUBKEY" > "$keyfiletmp"
  #check if valid key file
  if ! ssh-keygen -l -f "$keyfiletmp" > /dev/null; then
    echo "$(basename $0): Invalid key, not adding for $ADMIN_USER" >&2;
  else
    keyringfile="/home/$ADMIN_USER/.ssh/authorized_keys"
    if cat "$keyfiletmp" >> "$keyringfile"; then
      echo "Added key to $(hostname):$keyringfile"
    fi
  fi
  rm "$keyfiletmp"
fi

##
## CLEANUP
##

#remove the root key if we're root
if [ $(id -u) == 0 -a -f '/root/.ssh/authorized_keys' ]; then
  rm -rf '/root/.ssh/authorized_keys'
  echo "Removed key from $(hostname):/root/.ssh/authorized_keys"
fi

#ask to reboot system. default will timeout to yes.
#it looks like this script finishes beore the shutdown.
if [ -z "$RESTART_FLAG" ]; then
  read -t 15 -p "Finished host setup, reboot? [y] " RESTART_FLAG || true
  if [ -z "$RESTART_FLAG" ]; then RESTART_FLAG='y'; fi
fi

if [ "$RESTART_FLAG" == 'y' -o "$RESTART_FLAG" == 'yes' ]; then
  echo -e "\nRestarting system ..."
  shutdown -r now
fi
