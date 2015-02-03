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

if [ -n "$DB_USER" -a "$DBL_USER" != 'root' ]; then
  #get db user password
  stty -echo
  read -p "Database password for '$DB_USER': " DB_PASS; echo
  stty echo

  #create user with(out) password
  if [ -n "$DB_PASS" ]; then
    sudo -u pgsql psql -c "create user $DB_USER with password '$DB_PASS';"
  else
    echo "No database password for $DB_USER" >&2;
    if sudo -u pgsql createuser --no-password "$DB_USER"; then
      echo "Created database user '$DB_USER'"
    else
      echo "Unable to create user '$DB_USER', exiting." >&2;
      exit 1;
    fi
  fi

  #create database for user
  if sudo -u pgsql createdb --owner "$DB_USER" "$DB_NAME"; then
    echo "Created database '$DB_NAME'"
  else
    echo "Unable to create databse '$DB_NAME', exiting" >&2;
    exit 1
  fi

  #generate .pgpass file for db login
  if [ -n "$DB_PASS" -a -d "/home/$JAIL_USER" ]; then
    pgpassfile="/home/$JAIL_USER/.pgpass"
    echo "$JAIL_IP:5432:$DB_NAME:$JAIL_USER:$DB_PASS" > "$pgpassfile"
    chmod 600 "$pgpassfile"
    echo "Created file $pgpassfile"
  fi
fi
