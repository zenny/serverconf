#!/bin/sh
## Used by jailconf, this script is run on the host system after the
## jail has been created and started. It's run after {jailtype}/conf.
## The default/postconf file is run for all new jails, and before any
## type-specific {jailtype}/conf script is run.
## Available environmental vars: JAIL_NAME, JAIL_IP, JAIL_TYPE, JAIL_USER, JAIL_CONF_DIR
