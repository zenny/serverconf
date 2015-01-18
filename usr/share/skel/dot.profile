# .profile - Bourne Shell startup script for login shells
#
# see also sh(1), environ(7).
#

# These are normally set through /etc/login.conf.  You may override them here
# if wanted.
# PATH=/sbin:/bin:/usr/sbin:/usr/bin:/usr/games:/usr/local/sbin:/usr/local/bin:$HOME/bin; export PATH
# BLOCKSIZE=K;  export BLOCKSIZE

# Setting TERM is normally done through /etc/ttys.  Do only override
# if you're sure that you'll never log in via telnet or xterm or a
# serial line.
# TERM=xterm;   export TERM

export EDITOR=ee
export PAGER=more

# set ENV to a file invoked each time sh is started for interactive use.
export ENV=$HOME/.shrc
export HOSTNAME="$(hostname)"

if [ $(id -u) == 0 ]; then
  PS1="$USER@$HOSTNAME# "
else
  PS1="$USER@$HOSTNAME\$ "
fi

# add some aliases
alias ls="ls -F"
alias l="ls"
alias ll="ls -lAF"
alias df="df -H"
alias du="du -h"

alias update-time="ntpd -q" #for vps
