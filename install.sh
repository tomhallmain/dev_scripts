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
  echo 'Please refer to README for install instructions.'
  exit 1
fi

if [ -f /bin/bash ]; then
  bazh=0
  [ -f ~/.bashrc ] && grep -q "source $DS_LOC/commands.sh" && bashrc_set=0
  if [ "$bashrc_set" ]; then
    bashrc_preset=0
  else
    export "source $DS_LOC/commands.sh" >> ~/.bashrc
  fi
fi

[ -f ~/.bashrc ] && grep -q "source .+commands.sh" ~/.bashrc && bashrc_set=0
[ "$bazh" ] && [ ! "$bashrc_set" ] && bash_install_issue=0
[ -f ~/.zshrc ] && grep -q "source .+commands.sh" ~/.zshrc && zshrc_set=0
[ "$zzsh" ] && [ ! "$zhrc_set" ] && zsh_install_issue=0


if [ ! ~/dev_scripts = "$DS_LOC" ]; then
  sed -i commands.sh "s#DS_LOC=\"\\\$HOME/dev_scripts\"#DS_LOC=\"$DS_LOC\"#"
fi

cmds="tests/data/commands_output"
tmp="tests/data/ds_setup_tmp"
if [ "$bazh" ]; then
  bash -c 'ds:commands' > $tmp
  cmp --silent $cmds $tmp || bash_install_issue=0
fi
if [ "$zzsh" ]; then
  zsh -c 'ds:commands' > $tmp
  cmp --silent $cmds $tmp || zsh_install_issue==0
fi
rm $tmp


if [[ ! "$zzsh" && -f /bin/zsh ]]; then
  echo 'dev_scripts not set up for zsh - to setup zsh, run install.sh using zsh or see README'
fi

if ls --color -d . >/dev/null 2>&1; then
  gnu_core=0
elif ls -G -d . >/dev/null 2>&1; then
  bsd_core=0
  echo 'GNU coreutils primary config not detected - some functionality may be limited'
  echo
  echo 'Extra setup is required for use of GNU coreutils with dev_scripts.'
  echo
  echo 'To install GNU coreutils, please visit https://www.gnu.org/software/coreutils/'
  echo
else
  solaris_core=0
  echo 'Solaris configuration detected - functionality may be severely limited'
  echo
fi

if [ "$zsh_install_issue" ]; then
  echo 'Issue encountered installing dev_scripts for zsh - please refer to README for install instructions'
fi
if [ "$bash_install_issue" ]; then
  echo 'Issue encountered installing dev_scripts for bash - please refer to README for install instructions'
fi
[[ "$zsh_install_issue" || "$bash_install_issue" ]] && exit 1

echo 'Installation complete!'
echo
echo 'Shell session refresh required before commands will be usable'
echo
conf="$(ds:readp 'Would you like to refresh now? (y/n)')"
if [ "$(ds:downcase "$conf")" = y ]; then
  clear
  if [ "$zzsh" ]; then
    zsh
  else
    bash
  fi
  echo
  echo 'Dev Scripts now installed'
  echo
  echo 'For a list of available commands, run $ ds:commands'
  echo
fi

