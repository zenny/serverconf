#!/bin/sh -e
## Copies a source file or directory to a destination directory.
## Files in a source directory keep their relative directory path. Empty
## directories are omitted.
##
## If a file name ends with '_append' it's concatenated to the end
## of the already existing destination file.
##
## Will replace an allowed set of variables set in the file itself. You
## can add additional ones by setting the REPLACE_VARS environmental variable.
##
## The source file and destination directory *must* exist. Child directories
## do not as they will get created later.

if [ "$#" -ne 2 ] || [ ! -e "$1" -o ! -d "$2" ]; then
  echo "Usage: $(basename $0) sourcepath destdir" >&2
  exit 1
fi

SRCPATH="$1"
DESTDIR=$(readlink -f "$2")

# set some default vars and variations
if [ -z "$HOST_NAME" ]; then HOST_NAME="$(hostname)"; fi
HOSTNAME="$HOST_NAME"
if [ -z "$HOST_USER" ]; then HOST_USER="$(who -m | cut -d ' ' -f1)"; fi

#var names in file we'll substitute. must be in these lists.
host_varnames='HOST_NAME HOST HOSTNAME HOST_USER USER'

REPLACE_VARS="$REPLACE_VARS $host_varnames"

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
  for varname in $(echo "$REPLACE_VARS"); do
    sub_var "$varname" "$filepath"
  done
}

copy_conf_file () {
  local srcpath="$1" destdir="$2"

  if [ ! -f "$srcpath" -o -z "$destdir" ]; then
    echo "copy_conf_file: Invalid params: srcpath=$srcpath, destdir=$destdir" >&2
    exit 1
  fi

  #get proper file destination path
  local srcbasename=$(basename "$srcpath" | sed 's/_append$//')
  local destpath="$destdir/$srcbasename"

  #save backup if destination file already exists
  if [ -e "$destpath" ]; then
    cp "$destpath" "$destpath.bak"
  fi

  mkdir -p "$(dirname $destpath)"

  #append or overwrite
  if echo "$srcpath" | grep '_append$' > /dev/null; then
    cat "$srcpath" >> "$destpath"
  else
    cp "$srcpath" "$destpath"
  fi

  #replace any of the allowed vars in the destination file
  sub_vars "$destpath"
}

# Go! ...
# if given a file, simply copy it over to the destination dir.
# if given a dir, create the relative dir structure within the dest dir.

if [ -f "$SRCPATH" ]; then
  copy_conf_file "$SRCPATH" "$DESTDIR"

elif [ -d "$SRCPATH" ]; then
  #switch to dir for proper rel name
  cd "$SRCPATH"
  #list all child files in src dir
  for fp in $(find . -type f); do
    #add relative directory to destination
    reldestdir=$(dirname "$fp")
    fulldestdir="$DESTDIR/$reldestdir"
    copy_conf_file "$fp" "$fulldestdir"
  done
else
  echo "Error: Invalid parameter '$SRCPATH', aborting." >&2
  exit 1
fi
