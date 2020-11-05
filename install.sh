#!/bin/bash

echo 'Setting up...'

readlink_f() {
  local target_f="$1"
  cd "$(dirname $target_f)"
  echo "$(pwd -P)"
  echo "$dir"
}

ds:verify() {
  cmds_heads="@@@COMMAND@@@ALIAS@@@DESCRIPTION@@@USAGE"
  tmp="tests/data/ds_setup_tmp"
  echo > $tmp
  if [ "$1" = zsh ]; then
    zsh -ic 'ds:commands' 2>/dev/null > $tmp
  else
    bash -ic 'ds:commands' 2>/dev/null > $tmp
  fi
  wait
  grep -q "$cmds_heads" $tmp
  local stts=$?
  rm $tmp
  return $stts
}

error_exit() {
  echo
  echo 'Issues detected with current install.'
  echo
  echo 'You may need to override the DS_LOC variable in case ~ alias is invalid for your shell.'
  echo 'To do this, add DS_LOC=/path/to/dev_scripts to your .bashrc and/or .zshrc and ensure this var'
  echo 'is defined before the source call to commands.sh.'
  echo
  exit 1
}

if [ -n "$($SHELL -c 'echo $ZSH_VERSION')" ]; then
  zzsh=0
  DS_LOC="$(readlink_f "$0")"
  [ -f ~/.zshrc ] && grep -q "dev_scripts" ~/.zshrc && zshrc_set=0
  if [ "$zshrc_set" ]; then
    zshrc_preset=0
  else
    echo "export DS_LOC=\"$DS_LOC\"" >> ~/.zshrc
    echo 'source "$DS_LOC/commands.sh"' >> ~/.zshrc
  fi
elif [ -n "$($SHELL -c 'echo $BASH_VERSION')" ]; then
  DS_LOC="$(readlink_f "$BASH_SOURCE")"
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
    echo "export DS_LOC=\"$DS_LOC\"" >> ~/.bashrc
    echo 'source "$DS_LOC/commands.sh"' >> ~/.bashrc
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
  echo 'Dev Scripts may have already been installed! Verifying installation...'
  echo
  [ "$bazh" ] && (ds:verify 'bash' || bash_install_issue=0)
  [ "$zzsh" ] && (ds:verify 'zsh' || zsh_install_issue=0)

  if [[ "$zsh_install_issue" || "$bash_install_issue" ]]; then
    error_exit
  else
    echo 'The current install is operational.'
    exit
  fi
fi

echo 'Installing...'

[ -f ~/.bashrc ] && grep -q "DS_LOC/commands.sh" ~/.bashrc && bashrc_set=0
[ "$bazh" ] && [ ! "$bashrc_set" ] && bash_install_issue=0

if [[ "$zzsh" && ! "$zsh_set" ]]; then
  [ -f ~/.zshrc ] && grep -q "DS_LOC/commands.sh" ~/.zshrc && zshrc_set=0
  [ "$zzsh" ] && [ ! "$zshrc_set" ] && zsh_install_issue=0
fi

if [[ "$zzsh" && ! "$zsh_install_issue" ]] || [[ "$bazh" && ! "$bash_install_issue" ]]; then
  echo 'Verifying installation...'
  if [ "$bazh" ]; then
    ds:verify 'bash' || bash_install_issue=0
    if [ "$bash_install_issue" ] && grep -qr '\r$' .; then
      unset bash_install_issue
      bash init.sh
      ds:verify 'bash' || bash_install_issue=0
    fi
  fi
  if [ "$zzsh" ]; then
    ds:verify 'zsh' || zsh_install_issue=0
  fi

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

source commands.sh

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
if [[ "$zsh_install_issue" || "$bash_install_issue" ]]; then
  error_exit
fi

echo 'Installation complete!'
echo
echo 'You may want to override the DS_LOC variable in case ~ alias is invalid for your shell.'
echo 'To do this, add DS_LOC=/path/to/dev_scripts to your ~/.bashrc and/or ~/.zshrc and ensure this var'
echo 'is defined before the source call to commands.sh.'
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
  if [ "$zzsh" ]; then zsh; else bash; fi
fi

