#!/bin/sh

# determine the latest postgres version, something like 'postgresql94-server'
pgpkg=$(pkg search postgres | grep "server" | tail -n 1 | cut -d '-' -f 1-2)

pkg install --yes "$pgpkg"

# jail conf files are copied over after this script runs,
# but we need to start it now
service postgresql oneinitdb
service postgresql onestart

if [ -n "$JAIL_USER" ]; then
  DBNAME="$JAIL_USER"
  # postgres is owned by the 'pgsql' user
  sudo -u pgsql createuser --no-createdb --no-password "$JAIL_USER"
  sudo -u pgsql createdb --owner "$JAIL_USER" "$DBNAME"
fi

# TODO:
#   WARNING: enabling "trust" authentication for local connections
#   You can change this by editing pg_hba.conf or using the option -A, or
#   --auth-local and --auth-host, the next time you run initdb.
