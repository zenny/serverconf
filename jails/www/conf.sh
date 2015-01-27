#!/bin/sh
## Used by jailconf, this script is run within the jail after it
## has been started. Run after preconf and before postconf.
## The default/conf is run for all new jails, and before any
## type-specific jail conf script is run.
## Available environmental vars: JAIL_NAME, JAIL_IP, JAIL_TYPE, JAIL_USER, JAIL_CONF_DIR

pkg install --yes node npm

npm install forever -g
