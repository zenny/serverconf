#!/bin/sh -e
## Copies all the children files in a directory to another.
## If a file name ends with '_append' it's concatenated to the end
## of the already existing destination file.
## If the HOST_* and JAIL_* environmental vars are set when this script
## is called, perform a substitution in the destination file.
## Replacement vars in the file must end with a word boundary, ie. they
## can't be right next to another in a string.

SRCDIR="$1"
DESTDIR=$(readlink -f "$2")
#default host vars
HOST_NAME="$(hostname)"
HOSTNAME="$HOST_NAME"
HOST_USER="$(who -m | cut -d ' ' -f1)"

#var names in file we'll substitute. must be in these lists.
JAIL_VARNAMES='JAIL_ID JAIL_IP JAIL_TYPE JAIL_USER JAIL_CONF_DIR'
HOST_VARNAMES='HOST_CONF_DIR HOST_NAME HOST HOSTNAME HOST_USER USER MAIL_SERVER MAIL_USER MAIL_PASSWORD'

sub_var () {
  local varname="$1" filepath="$2"

  if [ -z "$varname" -o ! -f "$filepath" ]; then
    echo "sub_var: Invalid parameters: '$varname', '$filepath'" >&2
    exit 1
  fi

  if grep "\$$varname\b" "$filepath" > /dev/null; then
    local subtext=$(eval echo "\$$(echo $varname)")

    if [ -n "$subtext" ]; then
      #this works for word boundary on this machine at least '\>'
      sed -i '' -e "s|\$$varname\>|$subtext|g" "$filepath"
    else
      echo "Attempting to replace empty \$$varname in $filepath, ignoring." >&2
    fi
  fi
}

# Substitute the HOST_* and JAIL_* vars within config files
# when placing them at the destination.
sub_vars () {
  local filepath="$1"

  for varname in $(echo "$JAIL_VARNAMES"); do
    sub_var "$varname" "$filepath"
  done
  for varname in $(echo "$HOST_VARNAMES"); do
    sub_var "$varname" "$filepath"
  done
}

# Go! ...

if [ ! -d "$SRCDIR" -o ! -d "$DESTDIR" ]; then
  echo "Error: Invalid directory arguments" >&2
  exit 1
fi

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

  sub_vars "$destpath"
done
