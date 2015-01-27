#!/bin/sh
## Used by jail-create, this script is run on the host system after the
## jail has been created and started. Ran after jail/conf.
## The default/postconf file is run for all new jails, and before any
## type-specific jail/postconf script is run.
## Available environmental vars: JAIL_NAME, JAIL_IP, JAIL_TYPE, JAIL_USER, JAIL_CONF_DIR

#re-mount using updated /etc/fstab
mount -a
