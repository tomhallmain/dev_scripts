# SCRIPTING AND DEVELOPMENT NOTES



# General Terminal Notes:
#
# To delete a char on the right of the cursor on OS X, press Ctrl + D
#
# To click the mouse anywhere on a terminal line within vim or in CLI,
# hold control while clicking
#
# To clear the terminal of all elements and bring up a fresh prompt
clear
#
# To get a list of all currently active functions
declare -f | less
#
# To get a list of all currently active variables
declare | less
# The above declare statement contains all variables printed when running 
# the `env` command and more.
#
# To get the exact definition of a given command, use either of the following
type commandname
which commandname
#
# Program control in Bash is implemented via the exit status of processes. If a
# process exits with a status of 1, it usually indicates an error. If a process
# exists with a status of 0, it usually indicates a successful completion. To
# get a the last process's exit status, use
$?
#
# Dollar signs at the start of words indicate shell variables. The above is a
# shell variable that is reset upon each process completion. They are also
# required for string interpolation in bash, for example with a variable named
# test:
"The variable value will be interpolated here > ${varname}"



# Text Editor Notes:
#
# less
#
# To open a file in less:
less path/to/file
# You can also pipe data to less as in example below but it should be the last 
# command in the chain
echo text | less
#
# To search in less, type /searchterm and press enter - the cursor will be
# taken to the first character of the first instance found parsing the document
# forward and will wrap to the top if none are found at the bottom.
#
# To exit less, type
q
#
#
#
# vim
#
# To open a file in vim
vi path/to/file
#
# Piping data to vim is not advised.
#
# To search in vim, type /searchterm and press enter - the cursor will be taken
# to the first character of the first instance found going forward. Unlike in
# less, you can move to the next instance of a match by entering *
#
# To substitute, type :%s/[originalregex]/[replaceregex]/[regexmods (g,m)]
#
# Opening a directory is also possible in vim. This opens a vim navigator that
# will allow the user to access anywhere in the file structure
vi path/to/dir
#
# vim can be configured in countless ways using the .vimrc file - even using an
# internal script called vimscript
#
# Instances of vim can also be configured on the fly using vimscript. To access
# vim script terminal while in vim, type a colon when in normal mode
:
#
# After having opened a file from the vim file browser, to go back to the previous
# buffer you can type the following vimscript command
:b#
# To quit vim, use the vimscript command (must be in normal mode and the key
# buffer must be empty - typing q first will create an issue.)
:q
# 
# Some examples of configurable settings in vim are:
# Add line numbers
:set number
#
# Add relative line numbers
:set relativenumber
#
# Persist yanked data between vim sessions (sending all yanks to register)
:set clipboard=unnamed
#
# To undo a change made in vim within the scope of vim's opening the file,
# simply type in normal mode
u
# To redo a change, type Ctrl + R in normal mode
#
# To yank (copy a line's data and move it to the register)
yy
# To delete a line and move the line data to the register, press in normal mode
dd
# To delete multiple lines or yank multiple lines, type in normal mode the
# number of lines to yank or delete including the cursor's current position and
# below and either the yank or delete commands. For example
#
# Delete current line and 5 lines after it and send the data to the register
6dd
#
# To paste the newest line data added to the register to the line below the
# cursor, type in normal mode
p
#

