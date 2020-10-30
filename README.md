
# dev_scripts

Scripts and CLI commands to make development and data analysis workflows more efficient and expand the capabilities and convenience of your bash or zsh terminal.

Once installed, start a bash or zsh session and run `ds:commands` to see available commands.

All commands are namespaced to `ds:*` so there should be little to no clashing with any existing commands in your local shell environment.


# Basic Install

Run the `install.sh` script in the project base directory. If any trouble is encountered running this script, see below manual install instructions.


# Manual Install

To access the utilities in the `commands.sh` file, add `source ~/dev_scripts/commands.sh` to your `~/.bashrc` file. This file may need to be created.

Once the commands file is sourced to the bash config file, Mac users should add `source ~/.bashrc` to their `~/.zshrc` file and open a new terminal to enable the commands to be run in zsh.


# Selected Functions

I have found the below functions are especially useful when working in the terminal.

`ds:reo`

Select, reorder, slice data using inferred field separators. Supports expression evaluation, regex searches, exclusions, and/or logic, frame expressions, reversals, and more.

![](https://github.com/tomhallmain/dev_scripts/blob/master/assets/reo_ex_1.png?raw=true)

![](https://github.com/tomhallmain/dev_scripts/blob/master/assets/reo_ex_2.png?raw=true)


`ds:fit`

Fits tabular data (including multibyte characters) dynamically into your terminal, and attempts to format it intelligently. If the max field length combined is too long, the longest fields will be right-truncated until the terminal width is reached.

!]](https://github.com/tomhallmain/dev_scripts/blob/master/assets/fit_ex.png?raw=true)

ds:reo will apply ds:fit if the output is to a terminal.

![](https://github.com/tomhallmain/dev_scripts/blob/master/assets/reo_ex_fit_emoji.png?raw=true)


`ds:sbsp`

Split out and create new fields by a given inner field subseparator pattern.

![](https://github.com/tomhallmain/dev_scripts/blob/master/assets/sbsp_ex.png?raw=true)


`ds:trace`

View or search shell trace output.

![](https://github.com/tomhallmain/dev_scripts/blob/master/assets/trace_ex.png?raw=true)


`ds:git_cross_view`

View the current state of your git branches across all repos.

![](https://github.com/tomhallmain/dev_scripts/blob/master/gcv_ex.png?raw=true)


`ds:git_refresh`

Refresh all repos in a given base directory with the newest data.


# Issues

To report bugs please contact: tomhall.main@gmail.com
