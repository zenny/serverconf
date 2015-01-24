#!/bin/sh -e
## Run the command hook files for jailcreate and jailupdate.
## Available environmental vars: JAIL_ID, JAIL_IP, JAIL_TYPE, JAIL_USER

JAIL_TYPE="$1"
HOOK_NAME="${2%.*}" #remove file extension if given
HOOK_ENV="$3"
APP_ROOT="$(cd $(dirname $(readlink -f $0))/..; pwd)"
JAIL_CONF_DIR=''

if [ "$HOOK_ENV" != 'host' -o "$HOOK_ENV" != 'jail' ]; then
  echo "$(basename $0): The hook must be run in either the 'host' or 'jail'." >&2
  exit 1
fi

##
## Get jail config directory
##

#first check path var
if [ -n "$SERVERCONF_JAIL_PATH" ]; then
  for dir in $(echo "$SERVERCONF_JAIL_PATH" | tr ':' ' '); do
    if [ ! -d "$dir" ]; then
      echo "$(basename $0): In var SERVERCONF_JAIL_PATH, '$dir' must be a directory." >&2
      exit 1
    fi
    if [ -d "$dir/$JAIL_TYPE" ]; then
      #found jail type
      JAIL_CONF_DIR="$dir"
      break
    fi
  done
fi

#then check app defaults
cd "$APP_ROOT/jails"
for dir in $(find . ! -path . -type d -maxdepth 1); do
  if [ -d "$dir/$JAIL_TYPE" ]; then
    #found jail type
    JAIL_CONF_DIR="$APP_ROOT/jails/$dir"
    break
  fi
done

if [ -z "$JAIL_CONF_DIR" ]; then
  echo "$(basename $0): Unable to find jail type config directory, aborting." >&2;
  exit 1
fi


cd "$JAIL_CONF_DIR"

#grab jail hook file, ignore file extension, only return first match (shouldn't be)
HOOK_FILE=$(find "$JAIL_CONF_DIR" -name "$HOOK_NAME*" -type f -maxdepth 1 | head -n1)

##
## Run hook on host
##

if [ -f "$HOOK_FILE" -a "$HOOK_ENV" == 'host' ]; then
  echo "Running $HOOK_NAME for '$JAIL_TYPE' on $HOOK_ENV ..."
  if ! env \
       JAIL_ID="$JAIL_ID" \
       JAIL_IP="$JAIL_IP" \
       JAIL_USER="$JAIL_USER" \
       JAIL_TYPE="$JAIL_TYPE" \
       HOOK_NAME="$HOOK_NAME" \
       HOOK_ENV="$HOOK_ENV" \
       JAIL_CONF_DIR="$JAIL_CONF_DIR" \
       sh -e "$JAIL_CONF_DIR/$HOOK_FILE"; then
    echo "Error running '$JAIL_TYPE/$HOOK_NAME', continuing" >&2
  fi
fi

##
## Run hook in jail
##

if [ -f "$HOOK_FILE" -a "$HOOK_ENV" == 'jail' ]; then

  mkdir -p "/usr/jails/$JAIL_ID/tmp/$JAIL_TYPE"

  if ! mount_nullfs "$JAIL_CONF_DIR" "/usr/jails/$JAIL_ID/tmp/$JAIL_TYPE"; then
    echo "In '$JAIL_TYPE/$HOOK_NAME', unable to mount $JAIL_CONF_DIR directory within jail, skipping" >&2

  else
    echo "Running $HOOK_NAME for '$JAIL_TYPE' on $HOOK_ENV ..."
    if ! env \
         JAIL_ID="$JAIL_ID" \
         JAIL_IP="$JAIL_IP" \
         JAIL_USER="$JAIL_USER" \
         JAIL_TYPE="$JAIL_TYPE" \
         HOOK_NAME="$HOOK_NAME" \
         HOOK_ENV="$HOOK_ENV" \
         JAIL_CONF_DIR="/tmp/$JAIL_TYPE" \
         jexec "$JAIL_ID" sh -e "/tmp/$JAIL_TYPE/$HOOK_FILE"; then
      echo "Error running '$JAIL_TYPE/$HOOK_NAME', continuing" >&2
    fi

    umount "/usr/jails/$JAIL_ID/tmp/$JAIL_TYPE"
  fi

  rm -rf "/usr/jails/$JAIL_ID/tmp/$JAIL_TYPE"
fi
