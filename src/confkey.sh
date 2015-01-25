#!/bin/sh -e

print_help () {
  echo "Usage: $(basename $0) -f=filename -k=key [-v=value]" >&2;
  echo "Get/set key values in a conf file that uses 'key=value' format." >&2;
  echo " -f=filename  Conf file to parse" >&2;
  echo " -k=key       Key to get/set" >&2;
  echo "Options:" >&2;
  echo " -v=value     If provided, set the value for the key" >&2;
  echo " -h           Print this help message" >&2;
}

while getopts "f:k:v:h" opt; do
  case $opt in
    f) CONFFILE="$OPTARG";;
    k) CONFKEY="$OPTARG";;
    v) CONFVAL="$OPTARG";;
    h) print_help; exit 0;;
    \?) print_help; exit 1;;
  esac
done

# check args
if [ -z "$CONFFILE" -o -z "$CONFKEY" ]; then
  print_help
  exit 1
elif [ ! -f "$CONFFILE" ]; then
  echo "$(basename $0): Invalid file '$CONFFILE', exiting." >&2
  exit 1
fi

CONFDATA=$(cat "$CONFFILE")
# match last record in file and get line number
linematch=$(echo "$CONFDATA" | grep -n "\b$CONFKEY\b[[:space:]]*=" | tail -n1)

##
## SETTER
##

if [ -n "$CONFVAL" ]; then
  newrec="$CONFKEY=$CONFVAL"

  if [ -n "$linematch" ]; then
    #replace current key=val at the matching line number
    lineno=$(echo "$linematch" | cut -d ':' -f1)
    echo "$CONFDATA" | sed -e "${lineno}s/^.*\$/$newrec/" > "$CONFFILE"
  else
    #new value, append
    echo "$newrec" >> "$CONFFILE"
  fi

  exit 0
fi

##
## GETTER
##

if [ -n "$linematch" ]; then
  #get key=val record and strip comments
  rec=$(echo "$linematch" | cut -d ':' -f2 | sed -e 's/[[:space:]]*#.*//')
  #get record value, trim leading and trailing whitespace
  recval=$(echo "$rec" | cut -d '=' -f2 | sed -e 's/^ *//' -e 's/ *$//')
  #and return value
  echo "$recval"
  exit 0
fi

# No get found. Return nothing and use error exit code.
exit 1
