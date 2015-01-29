#!/bin/sh -e

JAIL_TYPE="$1"
APP_ROOT="$(cd $(dirname $(readlink -f $0))/..; pwd)"

#SERVERCONF_JAIL_PATH is a list of jail dirs, or dir that contains jail dirs
if [ -n "$SERVERCONF_JAIL_PATH" ]; then
  for dir in $(echo "$SERVERCONF_JAIL_PATH" | tr ':' ' '); do
    if [ -d "$dir" -a "$(basename $dir)" == "$JAIL_TYPE" ]; then
      JAIL_CONF_DIR="$dir"
      break
    elif [ -d "$dir/$JAIL_TYPE" ]; then
      JAIL_CONF_DIR="$dir/$JAIL_TYPE"
      break
    else
      echo "$(basename $0): In SERVERCONF_JAIL_PATH, '$dir' must be a directory." >&2
      exit 1
    fi
  done
fi

#if not using SERVERCONF_JAIL_PATH, check app defaults
cd "$APP_ROOT/jails"

for dir in $(find . ! -path . -type d -maxdepth 1); do
  if [ "$(basename $dir)" == "$JAIL_TYPE" ]; then
    JAIL_CONF_DIR="$APP_ROOT/jails/$(basename $dir)"
    break
  fi
done

if [ -z "$JAIL_CONF_DIR" ]; then
  echo "$(basename $0): Unable to find jail type config directory, aborting." >&2;
  exit 1
else
	echo "$JAIL_CONF_DIR"
fi
