#!/bin/bash
#
# Dev Scripts Installation
# Installs and configures development scripts for bash and zsh shells
#
# Features:
# - Automatic shell detection and configuration
# - Dependency verification
# - Backup of existing configurations
# - Installation verification
# - Support for GNU and BSD environments
#
# Usage: ./install.sh

set -e  # Exit on error

# Version tracking
DS_VERSION="1.0.0"

# Enhanced directory resolution with error handling
readlink_dir() {
    local target_f="$1"
    if [ ! -e "$target_f" ]; then
        echo "Error: Path '$target_f' does not exist" >&2
        return 1
    }
    
    local dir
    dir="$(dirname "$target_f")"
    if ! cd "$dir" 2>/dev/null; then
        echo "Error: Cannot access directory of '$target_f'" >&2
        return 1
    }
    
    pwd -P || {
        echo "Error: Cannot resolve physical path" >&2
        return 1
    }
}

# Improved shell detection
detect_shell() {
    if [ -n "$($SHELL -c 'echo $ZSH_VERSION')" ]; then
        echo "zsh"
    elif [ -n "$($SHELL -c 'echo $BASH_VERSION')" ]; then
        echo "bash"
    else
        echo "unknown"
    fi
}

# Enhanced verification with better error messages
ds:verify() {
    local shell_type="$1"
    if [[ ! "$shell_type" =~ ^(zsh|bash)$ ]]; then
        echo "Error: Invalid shell type '$shell_type'" >&2
        return 1
    }
    
    local cmds_heads="@@@COMMAND@@@ALIAS@@@DESCRIPTION@@@USAGE"
    local tmp="tests/data/ds_setup_tmp"
    
    # Ensure test directory exists
    mkdir -p "$(dirname "$tmp")" || {
        echo "Error: Cannot create test directory" >&2
        return 1
    }
    
    echo > "$tmp" || {
        echo "Error: Cannot write to test file" >&2
        return 1
    }
    
    if [ "$shell_type" = "zsh" ]; then
        zsh -ic 'ds:commands "" "" 0' 2>/dev/null > "$tmp" || true
    else
        bash -ic 'ds:commands "" "" 0' 2>/dev/null > "$tmp" || true
    fi
    wait
    
    grep -q "$cmds_heads" "$tmp"
    local status=$?
    rm -f "$tmp"
    return $status
}

# Backup functionality
backup_rc() {
    local rc_file="$1"
    if [ -f "$rc_file" ]; then
        local backup_file="${rc_file}.ds_backup_$(date +%Y%m%d_%H%M%S)"
        if ! cp "$rc_file" "$backup_file" 2>/dev/null; then
            echo "Warning: Failed to create backup of $rc_file" >&2
            return 1
        fi
        echo "Created backup: $backup_file"
        return 0
    fi
    return 1
}

# Dependency checking
check_dependencies() {
    local missing=()
    for cmd in readlink grep awk sed; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing+=("$cmd")
        fi
    done
    
    if [ ${#missing[@]} -gt 0 ]; then
        echo "Error: Missing required dependencies: ${missing[*]}" >&2
        return 1
    fi
    return 0
}

# Enhanced error handling
error_exit() {
    local msg="$1"
    echo >&2
    echo "Installation Error: ${msg:-Issues detected with current install.}" >&2
    echo >&2
    echo "Troubleshooting steps:" >&2
    echo "1. Ensure you have write permissions to your home directory" >&2
    echo "2. Check that all dependencies are installed" >&2
    echo "3. Verify that your shell configuration files are writable" >&2
    echo >&2
    echo "You may need to override the DS_LOC variable if ~ alias is invalid for your shell." >&2
    echo "Add DS_LOC=/path/to/dev_scripts to your .bashrc and/or .zshrc before the source call to commands.sh" >&2
    echo >&2
    exit 1
}

# Progress indication
show_progress() {
    echo -n "$1... "
}

finish_progress() {
    if [ $? -eq 0 ]; then
        echo "Done"
        return 0
    else
        echo "Failed"
        return 1
    fi
}

# Main installation logic
echo 'Setting up Dev Scripts...'

# Check dependencies first
show_progress "Checking dependencies"
check_dependencies || error_exit "Missing required dependencies"
finish_progress

# Detect shell and set up variables
CURRENT_SHELL=$(detect_shell)
if [ "$CURRENT_SHELL" = "unknown" ]; then
    error_exit "Unsupported shell detected. Only bash and zsh are supported."
fi

# Determine installation location
if [ "$CURRENT_SHELL" = "zsh" ]; then
    DS_LOC="$(readlink_dir "$0")" || error_exit "Cannot determine installation location"
    zzsh=0
elif [ "$CURRENT_SHELL" = "bash" ]; then
    DS_LOC="$(readlink_dir "${BASH_SOURCE[0]}")" || error_exit "Cannot determine installation location"
else
    error_exit "Shell detection failed"
fi

# Rest of existing installation logic
if [ -n "$($SHELL -c 'echo $ZSH_VERSION')" ]; then
    show_progress "Checking zsh configuration"
    [ -f ~/.zshrc ] && grep -q "dev_scripts/commands.sh" ~/.zshrc && zshrc_set=0
    if [ "$zshrc_set" ]; then
        zshrc_preset=0
    else
        backup_rc ~/.zshrc
        echo "export DS_LOC=\"$DS_LOC\"" >> ~/.zshrc
        echo 'source "$DS_LOC/commands.sh"' >> ~/.zshrc
    fi
    finish_progress
fi

if [ -f /bin/bash ]; then
    bazh=0
    [ -f ~/.bashrc ] && grep -q "dev_script/commands.sh" ~/.bashrc && bashrc_set=0
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
    echo 'Dev Scripts may have already been installed. Verifying installation...'
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
    echo 'Or if using homebrew, run `brew install coreutils` and then override the default'
    echo 'commands in your PATH by adding the following line to your .bashrc or .zshrc:'
    echo
    echo '    `export PATH="$(brew --prefix coreutils)/libexec/gnubin:/usr/local/bin:$PATH"`'
    echo
    # TODO confirm to install coreutils from here
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

echo 'Installation completed successfully!'
echo
echo 'Configuration Summary:'
echo "- Installation path: $DS_LOC"
echo "- Detected shell: $CURRENT_SHELL"
[ "$gnu_core" ] && echo "- GNU coreutils: Yes" || echo "- GNU coreutils: No"
echo
echo 'Next Steps:'
echo "1. Refresh your shell session (restart terminal or run 'exec $SHELL')"
echo "2. Run 'ds:commands' to see available commands"
echo

# Offer to refresh shell
conf="$(ds:readp 'Would you like to refresh your shell now? (y/n)')"
if [ "$conf" = y ]; then
    echo
    echo 'Restarting shell in 5 seconds...'
    echo
    sleep 5
    clear
    exec "$SHELL"
fi

