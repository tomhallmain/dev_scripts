#!/bin/bash

echo 'Setting up...'

if [ -n "$($SHELL -c 'echo $ZSH_VERSION')" ]; then
  zzsh=0
  dir="$(dirname "$0")/.."
  DS_LOC="$(readlink -e "$dir")"
  [ -f ~/.zshrc ] && grep -q "dev_scripts/commands.sh" ~/.zshrc && zshrc_set=0
  if [ "$zshrc_set" ]; then
    zshrc_preset=0
  else
    echo "source $DS_LOC/commands.sh" >> ~/.zshrc
  fi
elif [ -n "$($SHELL -c 'echo $BASH_VERSION')" ]; then
  dir="$(dirname "$BASH_SOURCE")/.."
  DS_LOC="$(readlink -e "$dir")"
else
  echo 'Unhandled shell detected! Only bash and zsh are supported at this time.'
  echo 'Please run this script using zsh or bash, or refer to README for install instructions.'
  exit 1
fi


if [ -f /bin/bash ]; then
  bazh=0
  [ -f ~/.bashrc ] && grep -q "dev_scripts/init.sh" ~/.bashrc && bashrc_set=0
  if [ "$bashrc_set" ]; then
    bashrc_preset=0
  else
    echo "source $DS_LOC/init.sh" >> ~/.bashrc
  fi
  if [ ! -f ~/.bash_profile ]; then
    echo "if [ -f ~/.bashrc ]; then . ~/.bashrc; fi" >> ~/.bash_profile
  elif ! grep -q "\.bashrc" ~/.bash_profile; then
    echo "if [ -f ~/.bashrc ]; then . ~/.bashrc; fi" >> ~/.bash_profile
  fi
fi

if [[ "$zzsh" && "$zshrc_preset" && "$bazh" && "$bashrc_preset" ]]; then
  preset=0
elif [[ "$zzsh" && ! "$bazh" && "$zshrc_preset" ]]; then
  preset=0
elif [[ "$bazh" && ! "$zzsh" && "$bashrc_preset" ]]; then
  preset=0
fi

if [ "$preset" ]; then
  echo 'Dev Scripts already installed!'
  # TODO add handling for preset error cases here
  exit
fi

echo 'Installing...'

[ -f ~/.bashrc ] && grep -q "dev_scripts/init.sh" ~/.bashrc && bashrc_set=0
[ "$bazh" ] && [ ! "$bashrc_set" ] && bash_install_issue=0

if [[ "$zzsh" && ! "$zsh_set" ]]; then
  [ -f ~/.zshrc ] && grep -q "dev_scripts/commands.sh" ~/.zshrc && zshrc_set=0
  [ "$zzsh" ] && [ ! "$zshrc_set" ] && zsh_install_issue=0
fi

if [[ "$zzsh" && ! "$zsh_install_issue" ]] || [[ "$bazh" && ! "$bash_install_issue" ]]; then
  if [ ! ~/dev_scripts = "$DS_LOC" ]; then
    sed -i -e "s#DS_LOC=\"\$HOME/dev_scripts\"#DS_LOC=\"$DS_LOC\"#" commands.sh
  fi

  cmds_heads="COMMAND              ALIAS     DESCRIPTION                                            USAGE"
  tmp="tests/data/ds_setup_tmp"
  echo > $tmp
  echo 'Verifying installation...'
  if [ "$bazh" ]; then
    bash -ic 'ds:commands 200' > $tmp
    grep -q "$cmds_heads" $tmp || bash_install_issue=0
  fi
  if [ "$zzsh" ]; then
    zsh -ic 'ds:commands 200' > $tmp
    grep -q "$cmds_heads" $tmp || zsh_install_issue==0
  fi
  rm $tmp


  if [[ ! "$zzsh" && -f /bin/zsh ]]; then
    echo 'Dev Scripts not set up for zsh - to set up for zsh, run install.sh using zsh or see README'
    echo
  fi
fi

if ls --time-style=%D . >/dev/null 2>&1; then
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

[ "$zzsh" ] && source "$DS_LOC/commands.sh" || source "$DS_LOC/init.sh"

if ! ds:awksafe &> /dev/null; then
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
echo 'Shell session refresh is required before commands will be usable.'
echo
conf="$(ds:readp 'Would you like to refresh now? (y/n)')"
if [ "$(ds:downcase "$conf")" = y ]; then
  echo
  echo 'Dev Scripts now installed - restarting shell in 5 seconds'
  echo
  echo "For a list of available commands, run \`ds:commands\`"
  echo
  sleep 5
  clear
  [ "$zzsh" ] && zsh || bash
fi

