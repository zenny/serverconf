#!/bin/sh -e

JAIL_TYPE="$1"
JAIL_CONF_DIR=''
#the default is to throw an error if it can't locate the directory
ERROR_ON_FAIL=1
if [ -n "$NO_ERROR_ON_FAIL" ]; then ERROR_ON_FAIL=''; fi

##
## the environ var SERVERCONF_JAIL_PATH can be a list of jail dirs,
## separated by a colon, or of parent dir that contains multiple jail dirs.
##

if [ -n "$SERVERCONF_JAIL_PATH" ]; then

  for dir in $(echo "$SERVERCONF_JAIL_PATH" | tr ':' ' '); do

    if [ ! -d "$dir" ]; then
      echo "$(basename $0): In SERVERCONF_JAIL_PATH, '$dir' must be a directory." >&2
      exit 1;
    fi
    
    if [ "$(basename $dir)" == "$JAIL_TYPE" ]; then
      JAIL_CONF_DIR="$dir"
      break;

    elif [ -d "$dir/$JAIL_TYPE" ]; then
      JAIL_CONF_DIR="$dir/$JAIL_TYPE"
      break;
    fi
  done
fi

##
## if we haven't found it yet, search app defaults
##

if [ -z "$JAIL_CONF_DIR" ]; then

  APP_ROOT="$(cd $(dirname $(readlink -f $0))/..; pwd)"
  cd "$APP_ROOT/jails"

  for dir in $(find . ! -path . -type d -maxdepth 1); do
    if [ "$(basename $dir)" == "$JAIL_TYPE" ]; then
      JAIL_CONF_DIR="$APP_ROOT/jails/$(basename $dir)"
      break;
    fi
  done  
fi

##
## return dir location or error
##

if [ -z "$JAIL_CONF_DIR" -a -n "$ERROR_ON_FAIL" ]; then
  echo "$(basename $0): Unable to find config directory for '$JAIL_TYPE', aborting." >&2;
  exit 1
else
  echo "$JAIL_CONF_DIR"
fi
