#!/bin/sh -e
## Copies all the children files in a directory to another.
## If a file name ends with '_append' it's concatenated to the end
## of the already existing destination file.
## If the HOST_* and JAIL_* environmental vars are set when this script
## is called, perform a substitution in the destination file.

SRCDIR="$1"
DESTDIR=$(readlink -f "$2")

if [ ! -d "$SRCDIR" -o ! -d "$DESTDIR" ]; then
  echo "Error: Invalid directory arguments" >&2
  exit 1
fi

if [ -n "$JAIL_ID" ]; then
  SUBSTITUTE_FLAG=1
fi

HOST_NAME="$(hostname)"
HOST_USER="$(who -m | cut -d ' ' -f1)"

sub_var () {
  local varname="$1" filepath="$2"

  if grep "\$$varname" "$filepath" > /dev/null; then
    local subtext=$(eval echo "\$$(echo $varname)")

    if [ -n "$subtext" ]; then
      sed -i '' -e "s|\$$varname|$subtext|g" "$filepath"
    else
      echo "Attempting to replace empty \$$varname in $filepath, ignoring." >&2
    fi
  fi
}

# Substitute the HOST_* and JAIL_* vars within config files
# when placing them at the destination.
sub_vars () {
  local filepath="$1"

  # Jail vars
  sub_var 'JAIL_ID' "$filepath"
  sub_var 'JAIL_IP' "$filepath"
  sub_var 'JAIL_TYPE' "$filepath"
  sub_var 'JAIL_USER' "$filepath"
  sub_var 'JAIL_CONF_DIR' "$filepath"

  # Host vars
  sub_var 'HOST_CONF_DIR' "$filepath"
  sub_var 'HOST_NAME' "$HOST_NAME"
  sub_var 'HOSTNAME' "$HOST_NAME"
  sub_var 'HOST_USER' "$HOST_USER"
  sub_var 'USER' "$HOST_USER"
  sub_var 'MAIL_SERVER' "$MAIL_SERVER"
  sub_var 'MAIL_USER' "$MAIL_USER"
  sub_var 'MAIL_PASSWORD' "$MAIL_PASSWORD"
}

cd "$SRCDIR"

#list all children files in src dir

for fp in $(find . -type f); do
  #get proper file destination path
  fpbasename=$(basename "$fp" | sed 's/_append$//')
  fpdirname=$(dirname "$fp")
  destpath="$DESTDIR/$fpdirname/$fpbasename"

  #save backup if destination file already exists
  if [ -e "$destpath" ]; then
    cp "$destpath" "$destpath.bak"
  fi

  mkdir -p "$(dirname $destpath)"

  #append or overwrite
  if echo "$fp" | grep "_append$" > /dev/null; then
    cat "$fp" >> "$destpath"
  else
    cp "$fp" "$destpath"
  fi

  if [ -n "$SUBSTITUTE_FLAG" ]; then
    sub_vars "$destpath"
  fi
done
