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

: ${DB_USER:="$JAIL_USER"}
: ${DB_NAME:="$DB_USER"}

if [ -n "$DB_USER" -a "$DB_USER" != 'root' ]; then
  #get db user password
  stty -echo
  read -p "Database password for '$DB_USER' (required): " DB_PASS; echo
  stty echo

  if [ -z "$DB_PASS" ]; then
    echo "Password required for local network access to database, skipping user creation." >&2;
    exit 0

  else
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
  fi
fi
