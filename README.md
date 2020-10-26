
# dev_scripts

Scripts and CLI commands to make development and data analysis workflows more efficient and expand the capabilities and convenience of your bash or zsh terminal.

Once installed, start a bash or zsh session and run `ds:commands` to see available commands.

All commands are namespaced to `ds:*` so there should be little to no clashing with any existing commands in your local shell environment.


# Basic Install

Run the `install.sh` script in the project base directory. If any trouble is encountered running this script, see below manual install instructions.


# Manual Install

To access the utilities in the `commands.sh` file, add `source ~/dev_scripts/commands.sh` to your `~/.bashrc` file. This file may need to be created.

Once the commands file is sourced to the bash config file, Mac users should add `source ~/.bashrc` to their `~/.zshrc` file and open a new terminal to enable the commands to be run in zsh.


# Issues

To report bugs please contact: tomhall.main@gmail.com
