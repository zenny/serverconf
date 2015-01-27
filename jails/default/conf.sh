#!/bin/sh
## Used by jailconf, this script is run within the jail after it
## has been created started. It's run after jailtype/conf and before
## {jailtype}/postconf. The script default/conf is run for all new jails,
## and before any type-specific {jailtype}/conf script is run.
## Available environmental vars: JAIL_NAME, JAIL_IP, JAIL_TYPE, JAIL_USER, JAIL_CONF_DIR

if ! pkg -N  >/dev/null 2>&1; then
  env ASSUME_ALWAYS_YES=YES pkg bootstrap
fi

pkg update
pkg install --yes sudo ca_root_nss

#ln -s /usr/local/share/certs/ca-root-nss.crt /etc/ssl/cert.pem

# set root environment
cp /usr/share/skel/dot.profile "$HOME/.profile"
chsh -s /bin/sh

# add user if they don't already exist
if [ -n "$JAIL_USER" ]; then
  if ! id "$JAIL_USER" >/dev/null 2>&1; then
    if pw useradd -n "$JAIL_USER" -m -s /bin/sh; then
      echo "Added user '$JAIL_USER' to $JAIL_NAME jail"
    fi
  fi
fi
