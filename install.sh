#!/bin/bash

if [ -n "`$SHELL -c 'echo $ZSH_VERSION'`" ]; then
  zzsh=0
  DS_LOC="$(dirname $0)"
  [ -f ~/.zshrc ] && grep -q "source $DS_LOC/commands.sh" && zshrc_set=0
  if [ "$zshrc_set" ]; then
    zshrc_preset=0
  else
    export "source $DS_LOC/commands.sh" >> ~/.zshrc
  fi
elif [ -n "`$SHELL -c 'echo $BASH_VERSION'`" ]; then
  DS_LOC="${BASH_SOURCE%/*}"
else
  echo 'Unhandled shell detected! Only bash and zsh are supported at this time.'
  echo 'Please run this script using zsh or bash, or refer to README for install instructions.'
  exit 1
fi

if [ -f /bin/bash ]; then
  bazh=0
  [ -f ~/.bashrc ] && grep -q "source $DS_LOC/commands.sh" && bashrc_set=0
  if [ "$bashrc_set" ]; then
    bashrc_preset=0
  else
    export "source $DS_LOC/init.sh" >> ~/.bashrc
  fi
  if [ ! -f ~/.bash_profile ] || ! grep -q "\.bashrc" ~/bash_profile; then
    export "if [ -f ~/.bashrc ]; then . ~/.bashrc; fi" >> ~/.bash_profile
  fi
fi

[ -f ~/.bashrc ] && grep -q "source .+dev_scripts/init.sh" ~/.bashrc && bashrc_set=0
[ "$bazh" ] && [ ! "$bashrc_set" ] && bash_install_issue=0
[ -f ~/.zshrc ] && grep -q "source .+dev_scripts/commands.sh" ~/.zshrc && zshrc_set=0
[ "$zzsh" ] && [ ! "$zhrc_set" ] && zsh_install_issue=0

if [[ "$zzsh" && ! "$zsh_install_issue" ]] || [[ "$bazh" && ! "$bash_install_issue" ]]; then
  if [ ! ~/dev_scripts = "$DS_LOC" ]; then
    sed -i commands.sh "s#DS_LOC=\"\\\$HOME/dev_scripts\"#DS_LOC=\"$DS_LOC\"#"
  fi

  cmds="tests/data/commands_output"
  tmp="tests/data/ds_setup_tmp"
  if [ "$bazh" ]; then
    bash -ic 'ds:commands 200' > $tmp
    cmp --silent $cmds $tmp || bash_install_issue=0
  fi
  if [ "$zzsh" ]; then
    zsh -ic 'ds:commands 200' > $tmp
    cmp --silent $cmds $tmp || zsh_install_issue==0
  fi
  rm $tmp


  if [[ ! "$zzsh" && -f /bin/zsh ]]; then
    echo 'Dev Scripts not set up for zsh - to set up for zsh, run install.sh using zsh or see README'
    echo
  fi
fi

if ls --color -d . >/dev/null 2>&1; then
  gnu_core=0
elif ls -G -d . >/dev/null 2>&1; then
  bsd_core=0
  echo 'GNU coreutils primary config not detected - some functionality may be limited'
  echo 'Extra setup is required for use of GNU coreutils with dev_scripts.'
  echo
  echo 'To install GNU coreutils, please visit https://www.gnu.org/software/coreutils/'
  echo
else
  solaris_core=0
  echo 'Solaris configuration detected - functionality may be severely limited'
  echo
fi

source "$DS_LOC/commands.sh"

if ! ds:awktest; then
  echo 'Warning: AWK version is not multibyte safe'
  echo 'Some commands including ds:fit may perform sub-optimally on data with multibyte characters'
  echo
fi

if [ "$zsh_install_issue" ]; then
  echo 'Issue encountered installing dev_scripts for zsh - please refer to README for install instructions'
  echo
fi
if [ "$bash_install_issue" ]; then
  echo 'Issue encountered installing dev_scripts for bash - please refer to README for install instructions'
  echo
fi
[[ "$zsh_install_issue" || "$bash_install_issue" ]] && exit 1


echo 'Installation complete!'
echo
echo 'Shell session refresh required before commands will be usable'
echo
conf="$(ds:readp 'Would you like to refresh now? (y/n)')"
if [ "$(ds:downcase "$conf")" = y ]; then
  clear
  [ "$zzsh" ] && zsh || bash
  echo
  echo 'Dev Scripts now installed'
  echo
  echo 'For a list of available commands, run $ ds:commands'
  echo
fi

