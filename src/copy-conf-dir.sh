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

# Substitute the HOST_* and JAIL_* vars within config files
# when placing them at the destination.
substitute_vars () {
  local filepath="$1"

  if grep "\$JAIL_" "$filepath" > /dev/null; then
    sed -i '' \
        -e "s|\$JAIL_ID|$JAIL_ID|g" \
        -e "s|\$JAIL_IP|$JAIL_IP|g" \
        -e "s|\$JAIL_TYPE|$JAIL_TYPE|g" \
        -e "s|\$JAIL_CONF_DIR|$JAIL_CONF_DIR|g" \
        "$filepath"

    if [ -z "$JAIL_USER" -a $(grep -l "\$JAIL_USER" "$filepath") ]; then
      echo "Attempting to replace empty \$JAIL_USER in $filepath, ignoring." >&2
    else
      sed -i '' -e "s|\$JAIL_USER|$JAIL_USER|g" "$filepath"
    fi
  fi
}


cd "$srcdir"

#list all children files in src dir

for fp in $(find . -type f); do
  #get proper file destination path
  fpbasename=$(basename "$fp" | sed 's/_append$//')
  fpdirname=$(dirname "$fp")
  destpath="$destdir/$fpdirname/$fpbasename"

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
    substitute_vars "$destpath"
  fi
done
