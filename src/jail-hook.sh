#!/bin/sh -e
## Run the command hook script for various jail actions.

JAIL_NAME="$1"
HOOK_NAME="${2%.*}" #remove file extension if given
HOOK_ENV="$3"

APP_ROOT="$(cd $(dirname $(readlink -f $0))/..; pwd)"
EZJAIL_CONF="/usr/local/etc/ezjail/$JAIL_NAME"
SERVERCONF_FILE="/usr/jails/$JAIL_NAME/etc/serverconf"
JAIL_TYPE_DEFAULT='default'

if [ -z "$LOG_NAME" ]; then LOG_NAME="$(basename $0)"; fi

#if set and not zero, delete the jail install on an aborted script hook attempt
if [ -n "$REMOVE_JAIL_ON_ERROR" ] &&  echo "$REMOVE_JAIL_ON_ERROR" | egrep -q '^[0-9]+$'; then
  if [ "$REMOVE_JAIL_ON_ERROR" -eq 0 ]; then
    REMOVE_JAIL_ON_ERROR='';
  fi
fi
#if set and not zero, do not run the default hooks
if [ -n "$NO_DEFAULT_HOOK" ] &&  echo "$NO_DEFAULT_HOOK" | egrep -q '^[0-9]+$'; then
  if [ "$NO_DEFAULT_HOOK" -eq 0 ]; then
    NO_DEFAULT_HOOK='';
  fi
fi

##
## CHECK PARAMS
##

#list all installed jails, running or not
jail_rec=$(ezjail-admin list | tail -n +3 | grep "[[:space:]]$JAIL_NAME[[:space:]]")

if [ -z "$jail_rec" -o ! -e "/usr/jails/$JAIL_NAME" ]; then
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

#the jail user is the one who called the script (even if sudo'd)
if [ -z "$JAIL_USER" ]; then JAIL_USER="$(who -m | cut -d ' ' -f1)"; fi

JAIL_IP=$(echo "$jail_rec" | awk '{print $3}')

#only list running jails
if jls | tail -n +3 | grep "[[:space:]]$JAIL_NAME[[:space:]]" > /dev/null; then
  JAIL_UP=1
fi

#get jail type from /etc/serverconf
if [ -f "$SERVERCONF_FILE" ]; then
  JAIL_TYPE=$(sh -e "$APP_ROOT/src/confkey.sh" -f "$SERVERCONF_FILE" -k "jailtype")
fi
if [ -z "$JAIL_TYPE" ]; then JAIL_TYPE="$JAIL_TYPE_DEFAULT"; fi

#uses SERVERCONF_JAIL_PATH if set
JAIL_CONF_DIR=$(sh -e "$APP_ROOT/src/get-jail-conf.sh" "$JAIL_TYPE")

##
## HOOK EXECUTION ENVIRONMENTS
##

abort_cleanup () {
  if [ -n "$REMOVE_JAIL_ON_ERROR" ]; then
    if ezjail-admin delete -f -w "$JAIL_NAME"; then
      echo "[$LOG_NAME] Removing jail '$JAIL_NAME'" >&2;
    else
      echo "[$LOG_NAME] Unable to remove jail '$JAIL_NAME'" >&2;
    fi
  fi
}

run_script_host () {
  local hook_script="$1" jail_type="$2"
  local jail_conf_dir=$(sh -e "$APP_ROOT/src/get-jail-conf.sh" "$jail_type")

  if [ -f "$hook_script" ]; then
    echo "[$LOG_NAME] Running '$HOOK_NAME' hook for '$jail_type' on $HOOK_ENV ..."
    if ! env \
         HOOK_NAME="$HOOK_NAME" \
         HOOK_ENV="$HOOK_ENV" \
         JAIL_NAME="$JAIL_NAME" \
         JAIL_TYPE="$JAIL_TYPE" \
         JAIL_IP="$JAIL_IP" \
         JAIL_UP="$JAIL_UP" \
         JAIL_USER="$JAIL_USER" \
         JAIL_CONF_DIR="$jail_conf_dir" \
         EZJAIL_CONF="$EZJAIL_CONF" \
         SERVERCONF_FILE="$SERVERCONF_FILE" \
         APP_ROOT="$APP_ROOT" \
         sh -e "$hook_script"; then
      echo "[$LOG_NAME] Error running '$jail_type/$HOOK_NAME', aborting." >&2
      abort_cleanup
      exit 1;
    fi
  fi
}

run_script_jail () {
  local hook_script="$1" jail_type="$2"
  local src_dir=$(sh -e "$APP_ROOT/src/get-jail-conf.sh" "$jail_type")
  local jail_mnt_dir="/tmp/$jail_type"
  local host_mnt_dir="/usr/jails/$JAIL_NAME/$jail_mnt_dir"

  mkdir -p "$host_mnt_dir"

  if ! mount_nullfs "$src_dir" "$host_mnt_dir"; then
    echo "[$LOG_NAME] In '$jail_type/$HOOK_NAME', unable to mount $src_dir directory within jail, skipping" >&2

  else
    if [ -f "$hook_script" ]; then
      echo "[$LOG_NAME] Running '$HOOK_NAME' hook for '$jail_type' in $HOOK_ENV ..."
      if ! env \
           HOOK_NAME="$HOOK_NAME" \
           HOOK_ENV="$HOOK_ENV" \
           JAIL_NAME="$JAIL_NAME" \
           JAIL_TYPE="$JAIL_TYPE" \
           JAIL_IP="$JAIL_IP" \
           JAIL_UP="$JAIL_UP" \
           JAIL_USER="$JAIL_USER" \
           JAIL_CONF_DIR="$jail_mnt_dir" \
           EZJAIL_CONF="$EZJAIL_CONF" \
           SERVERCONF_FILE="/etc/serverconf" \
           APP_ROOT="$APP_ROOT" \
           jexec "$JAIL_NAME" sh -e "$jail_mnt_dir/$(basename $hook_script)"; then
        echo "[$LOG_NAME] Error running '$jail_type/$HOOK_NAME', aborting." >&2
        umount "$host_mnt_dir"
        rm -rf "$host_mnt_dir"
        abort_cleanup
        exit 1;
      fi
    fi
    umount "$host_mnt_dir"
  fi
  rm -rf "$host_mnt_dir"
}

##
## GET HOOK SCRIPTS
##

cd "$JAIL_CONF_DIR"

#grab jail hook file, ignore file extension, only return first match (shouldn't be)
if [ -z "$NO_DEFAULT_HOOK" ]; then
  HOOK_DEFAULT_FILE=$(find "$APP_ROOT/jails/$JAIL_TYPE_DEFAULT" -name "$HOOK_NAME*" -type f -maxdepth 1 | head -n1)
fi
HOOK_FILE=$(find "$JAIL_CONF_DIR" -name "$HOOK_NAME*" -type f -maxdepth 1 | head -n1)

##
## Run hook on host. Run default jail before specific type.
##

if [ "$HOOK_ENV" == 'host' ]; then
  if [ -z "$NO_DEFAULT_HOOK" ]; then
    run_script_host "$HOOK_DEFAULT_FILE" "$JAIL_TYPE_DEFAULT"
  fi

  #don't want to run the default twice
  if [ "$JAIL_TYPE" != "$JAIL_TYPE_DEFAULT" ]; then
    run_script_host "$HOOK_FILE" "$JAIL_TYPE"
  fi
fi

##
## Run hook in jail
##

if [ "$HOOK_ENV" == 'jail' ]; then
  if [ -z "$NO_DEFAULT_HOOK" ]; then
    run_script_jail "$HOOK_DEFAULT_FILE" "$JAIL_TYPE_DEFAULT"
  fi

  if [ "$JAIL_TYPE" != "$JAIL_TYPE_DEFAULT" ]; then
    run_script_jail "$HOOK_FILE" "$JAIL_TYPE"
  fi
fi
