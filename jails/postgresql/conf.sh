#!/bin/sh

# determine the latest postgres version, something like 'postgresql94-server'
pgpkg=$(pkg search postgres | grep "server" | tail -n 1 | cut -d '-' -f 1-2)

pkg install --yes "$pgpkg"

# jail conf files are copied over after this script runs, but we need the db now
service postgresql oneinitdb
service postgresql onestart


## create db user/database for the jail user account, unless root.
## 'host-based authentication' defined in: /usr/local/pgsql/data/pg_hba.conf
## postgres is owned by the 'pgsql' user

#prompt for db user
if [ "$JAIL_USER" == 'root' ]; then
  read -p "Add a database account: " DB_USER
  if [ -z "$DB_USER" ]; then
    echo "Requires a non-root database account, skipping." >&2;
    exit 0
  fi
else
  read -p "Add a database account [$JAIL_USER]: " DB_USER
  if [ -z "$DB_USER" ]; then DB_USER="$JAIL_USER"; fi
fi

#prompt db user password if not provided
if [ -z "$DB_PASS" ]; then
  stty -echo
  read -p "Database password for '$DB_USER' (required): " DB_PASS; echo
  stty echo
fi
if [ -z "$DB_PASS" ]; then
  echo "Password required for local network database connection, skipping account creation." >&2;
  exit 0
fi

#prompt user's database
if [ -z "$DB_NAME" ]; then
  read -p "Use database [$DB_USER]: " DB_NAME
  if [ -z "$DB_NAME" ]; then DB_NAME="$DB_USER"; fi
fi


# create user
if sudo -u pgsql psql -d postgres -c "create user $DB_USER with password '$DB_PASS';"; then
  echo "Created database user '$DB_USER'"
else
  echo "Unable to create user '$DB_USER', exiting." >&2;
  exit 1;
fi

# create user's database
if sudo -u pgsql createdb --owner "$DB_USER" "$DB_NAME"; then
  echo "Created database '$DB_NAME'"
else
  echo "Unable to create databse '$DB_NAME', exiting" >&2;
  exit 1
fi
