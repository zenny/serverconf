#!/bin/sh -e
## Run the command hook script for various jail actions.

JAIL_NAME="$1"
HOOK_NAME="${2%.*}" #remove file extension if given
HOOK_ENV="$3"

APP_ROOT="$(cd $(dirname $(readlink -f $0))/..; pwd)"
EZJAIL_CONF="/usr/local/etc/ezjail/$JAIL_NAME"
SERVERCONF_FILE="/usr/jails/$JAIL_NAME/etc/serverconf"
JAIL_TYPE_DEFAULT='default'

##
## CHECK PARAMS
##

if [ ! -e "/usr/local/etc/ezjail/$JAIL_NAME" -o ! -e "/usr/jails/$JAIL_NAME" ]; then
  echo "$(basename $0): Jail '$JAIL_NAME' doesn't exist, exiting." >&2;
  exit 1
fi

if [ "$HOOK_ENV" != 'host' -a "$HOOK_ENV" != 'jail' ]; then
  echo "$(basename $0): Hook '$HOOK_NAME' must be run in either the 'host' or 'jail' environment." >&2
  exit 1
fi

if [ ! -e "$EZJAIL_CONF" ]; then
  echo "$(basename $0): ezjail conf file '$EZJAIL_CONF' doesn't exist, aborting." >&2;
  exit 1
fi

## Determine jail type from /etc/serverconf

if [ -f "$SERVERCONF_FILE" ]; then
  JAIL_TYPE=$(sh -e "$APP_ROOT/src/confkey.sh" -f "$SERVERCONF_FILE" -k "jailtype")
fi

if [ -z "$JAIL_TYPE" ]; then JAIL_TYPE="$JAIL_TYPE_DEFAULT"; fi

#add current user to jail by default (even if sudo'd)
if [ -n "$JAIL_USER" ]; then JAIL_USER="$(who -m | cut -d ' ' -f1)"; fi

##
## GET PARAMS: JAIL_IP, JAIL_UP, JAIL_CONF_DIR
##

if [ -z "$JAIL_IP" ]; then
  #list all installed jails, running or not
  jail_rec=$(ezjail-admin list | tail -n +3 | grep "[[:space:]]$JAIL_NAME[[:space:]]")

  if [ -n "$jail_rec" ]; then
    JAIL_IP=$(echo "$jail_rec" | awk '{print $3}')
  else
    echo "$(basename $0): Unable to get ip address for '$JAIL_NAME' and none provided, exiting." >&2;
    exit 1
  fi
fi

#only list running jails
if jls | tail -n +3 | grep "[[:space:]]$JAIL_NAME[[:space:]]" > /dev/null; then
  JAIL_UP=1
fi


#Get jail config directory
#first check path var, can be a jail dir, or a dir containing jail directories
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

#then check app defaults
cd "$APP_ROOT/jails"
for dir in $(find . ! -path . -type d -maxdepth 1); do
  if [ "$(basename $dir)" == "$JAIL_TYPE" ]; then
    #found jail type
    JAIL_CONF_DIR="$APP_ROOT/jails/$(basename $dir)"
    break
  fi
done

if [ -z "$JAIL_CONF_DIR" ]; then
  echo "$(basename $0): Unable to find jail type config directory, aborting." >&2;
  exit 1
fi

##
## HOOK EXECUTION ENVIRONMENTS
##

run_script_host () {
  local hook_script="$1" jail_type="$2"
  if [ -f "$hook_script" ]; then
    echo "Running '$HOOK_NAME' hook for '$jail_type' on $HOOK_ENV ..."
    if ! env \
         HOOK_NAME="$HOOK_NAME" \
         HOOK_ENV="$HOOK_ENV" \
         JAIL_NAME="$JAIL_NAME" \
         JAIL_TYPE="$JAIL_TYPE" \
         JAIL_IP="$JAIL_IP" \
         JAIL_UP="$JAIL_UP" \
         JAIL_USER="$JAIL_USER" \
         JAIL_CONF_DIR="$JAIL_CONF_DIR" \
         EZJAIL_CONF="$EZJAIL_CONF" \
         SERVERCONF_FILE="$SERVERCONF_FILE" \
         APP_ROOT="$APP_ROOT" \
         sh -e "$hook_script"; then
      echo "Error running '$jail_type/$HOOK_NAME', continuing" >&2
    fi
  fi
}

run_script_jail () {
  local hook_script="$1" jail_type="$2"
  local jail_conf_dir="$APP_ROOT/jails/$jail_type"

  mkdir -p "/usr/jails/$JAIL_NAME/tmp/$jail_type"

  if ! mount_nullfs "$jail_conf_dir" "/usr/jails/$JAIL_NAME/tmp/$jail_type"; then
    echo "In '$jail_type/$HOOK_NAME', unable to mount $jail_conf_dir directory within jail, skipping" >&2

  else
    if [ -f "$hook_script" ]; then
      echo "Running '$HOOK_NAME' hook for '$jail_type' in $HOOK_ENV ..."
      if ! env \
           HOOK_NAME="$HOOK_NAME" \
           HOOK_ENV="$HOOK_ENV" \
           JAIL_NAME="$JAIL_NAME" \
           JAIL_TYPE="$JAIL_TYPE" \
           JAIL_IP="$JAIL_IP" \
           JAIL_UP="$JAIL_UP" \
           JAIL_USER="$JAIL_USER" \
           JAIL_CONF_DIR="/tmp/$jail_type" \
           EZJAIL_CONF="$EZJAIL_CONF" \
           SERVERCONF_FILE="/etc/serverconf" \
           APP_ROOT="$APP_ROOT" \
           jexec "$JAIL_NAME" sh -e "/tmp/$jail_type/$(basename $hook_script)"; then
        echo "Error running '$jail_type/$HOOK_NAME', continuing" >&2
      fi
    fi
    umount "/usr/jails/$JAIL_NAME/tmp/$jail_type"
  fi
  rm -rf "/usr/jails/$JAIL_NAME/tmp/$jail_type"
}

##
## GET HOOK SCRIPTS
##

cd "$JAIL_CONF_DIR"

#grab jail hook file, ignore file extension, only return first match (shouldn't be)
HOOK_DEFAULT_FILE=$(find "$APP_ROOT/jails/$JAIL_TYPE_DEFAULT" -name "$HOOK_NAME*" -type f -maxdepth 1 | head -n1)
HOOK_FILE=$(find "$JAIL_CONF_DIR" -name "$HOOK_NAME*" -type f -maxdepth 1 | head -n1)

##
## Run hook on host. Run default jail before specific type.
##

if [ "$HOOK_ENV" == 'host' ]; then
  run_script_host "$HOOK_DEFAULT_FILE" "$JAIL_TYPE_DEFAULT"

  #don't want to run the default twice
  if [ "$JAIL_TYPE" != "$JAIL_TYPE_DEFAULT" ]; then
    run_script_host "$HOOK_FILE" "$JAIL_TYPE"
  fi
fi

##
## Run hook in jail
##

if [ "$HOOK_ENV" == 'jail' ]; then
  run_script_jail "$HOOK_DEFAULT_FILE" "$JAIL_TYPE_DEFAULT"

  if [ "$JAIL_TYPE" != "$JAIL_TYPE_DEFAULT" ]; then
    run_script_jail "$HOOK_FILE" "$JAIL_TYPE"
  fi
fi
