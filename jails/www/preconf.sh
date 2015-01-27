#!/bin/sh
## Used by jail-create, this script is run on the host system before the
## jail has been created and started. Ran before jail/conf.
## The default/preconf file is run for all new jails, and before any
## type-specific jail/preconf script is run.
## Available environmental vars: JAIL_NAME, JAIL_IP, JAIL_TYPE, JAIL_USER, JAIL_CONF_DIR

HOST_APP="$(cd $(dirname $(readlink -f $JAIL_CONF_DIR))/../../app; pwd)"
JAIL_APP="/usr/jails/$JAIL_NAME/usr/local/opt/kola/app"

mkdir -p "$JAIL_APP"

sed -i '' \
    -e "s|\$HOST_APP|$HOST_APP|g" \
    -e "s|\$JAIL_APP|$JAIL_APP|g" \
    "$JAIL_CONF_DIR/host/etc/fstab_append"
