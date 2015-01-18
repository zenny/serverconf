## ~/.bash_profile is executed for login shells,
## ~/.bashrc is executed for non-login shells.

# Install aliases if they exist
if [ -f ~/.bash_aliases ]; then
  source ~/.bash_aliases
fi

# Install bash completions if they exist
if [ -f /usr/local/share/bash-completion/bash_completion.sh ]; then
  source /usr/local/share/bash-completion/bash_completion.sh
fi

# Make the default editor something easy
export EDITOR="/usr/bin/ee"    

# Setup prompt
export LSCOLORS="GxFxCxDxBxegedabagaced" #lighter fg colors
PS1="\[\e[1;32m\][\u@\h \W]\$\[\e[0m\] " #green prompt
