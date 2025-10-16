"""
Windows Directory Permissions Reset Tool

This script resets directory permissions on Windows systems, typically used to restore
access after anti-cheat software has modified permissions to read-only. It uses the
Windows icacls command to reset ACLs and grant full permissions to the current user.

CRITICAL SAFETY WARNING:
This script modifies system permissions and can potentially lock users out of their
computer if used improperly. Incorrect modifications to user directory permissions
may require special recovery procedures or professional assistance to restore access.

Windows-Only Requirements:
- Must be run with administrator privileges
- Requires Windows icacls command availability
- Designed specifically for Windows NTFS file systems

Safety Features:
- Administrator privilege verification before execution
- Detailed logging of all permission changes
- User confirmation prompt before making changes
- Recursive permission application with error handling

Usage:
    Run from elevated Command Prompt or PowerShell as administrator

WARNING: Use extreme caution when modifying this script. Changes to the directory
list or permission logic could result in system lockout requiring specialized
recovery procedures.
"""

#!/usr/bin/env python

import os
import sys
import ctypes
import subprocess
from pathlib import Path
from datetime import datetime

def is_admin():
    """Check if the script is running with administrator privileges."""
    try:
        return ctypes.windll.shell32.IsUserAnAdmin()
    except:
        return False

def run_icacls_command(directory, command_type, recursive=False):
    """Run the icacls command and return its output and success status."""
    try:
        # Build the command
        if command_type == "reset":
            command = ['icacls', directory, '/reset']
        elif command_type == "grant":
            username = os.getenv('USERNAME')
            command = ['icacls', directory, f'/grant', f'{username}:F']
        else:
            raise ValueError(f"Unknown command type: {command_type}")
            
        if recursive:
            command.append('/T')
            
        # Run the command and capture output
        result = subprocess.run(command, capture_output=True, text=True)
        
        # Log the command and its output
        print(f"\nExecuting command: {' '.join(command)}")
        if result.stdout:
            print("Command output:")
            print(result.stdout)
        if result.stderr:
            print("Command errors:")
            print(result.stderr)
            
        return result.returncode == 0
        
    except Exception as e:
        print(f"Error executing icacls command: {str(e)}")
        return False

def reset_permissions(directory, recursive=False):
    """Reset permissions for a directory and optionally its contents to allow read/write access."""
    try:
        # Convert directory to Path object for better handling
        dir_path = Path(directory)
        
        # Ensure the directory exists
        if not dir_path.exists():
            print(f"Directory {directory} does not exist.")
            return False
            
        # Log the current permissions before making changes
        print(f"\nCurrent permissions for {directory}:")
        subprocess.run(['icacls', directory], capture_output=False)
        
        # First reset the permissions
        reset_success = run_icacls_command(directory, "reset", recursive)
        if not reset_success:
            print(f"Failed to reset permissions for {directory}")
            return False
            
        # Then grant full permissions to the user
        grant_success = run_icacls_command(directory, "grant", recursive)
        if not grant_success:
            print(f"Failed to grant permissions for {directory}")
            return False
        
        print(f"Successfully reset and granted permissions for {directory}" + (" and its contents" if recursive else ""))
        return True
        
    except Exception as e:
        print(f"Error resetting permissions for {directory}: {str(e)}")
        return False

def main():
    # Check for administrator privileges
    if not is_admin():
        print("This script requires administrator privileges.")
        print("Please run this script from an elevated command prompt.")
        print("To do this:")
        print("1. Right-click on Command Prompt or PowerShell")
        print("2. Select 'Run as administrator'")
        print("3. Navigate to the script's directory")
        print("4. Run the script again")
        sys.exit(1)

    # Get the user's home directory
    home_dir = os.path.expanduser("~")
    
    # Create a log file with timestamp
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    log_file = os.path.join(home_dir, f"permission_reset_log_{timestamp}.txt")
    
    # List of directories to reset permissions for
    directories_to_reset = [
        # Standard directories
        (os.path.join(home_dir, "Documents"), True),
        (os.path.join(home_dir, "Downloads"), True),
        (os.path.join(home_dir, "Desktop"), True),
        (os.path.join(home_dir, "Pictures"), True),
        (os.path.join(home_dir, "Videos"), True),
        (os.path.join(home_dir, "Music"), True),
        (os.path.join(home_dir, "AppData"), True),
        (os.path.join(home_dir, ".ssh"), True),

        # Projects
        (os.path.join(home_dir, "autogui"), True),
        (os.path.join(home_dir, "ComfyUI"), True),
        (os.path.join(home_dir, "discombobulator"), True),
        (os.path.join(home_dir, "get_modlists"), True),
        (os.path.join(home_dir, "health_data_parser"), True),
        (os.path.join(home_dir, "join"), True),
        (os.path.join(home_dir, "langchain_tests"), True),
        (os.path.join(home_dir, "LLaVA"), True),
        (os.path.join(home_dir, "media-sieve"), True),
        (os.path.join(home_dir, "media-tools"), True),
        (os.path.join(home_dir, "muse"), True),
        (os.path.join(home_dir, "photo-similarity-search"), True),
        (os.path.join(home_dir, "privateGPT"), True),
        (os.path.join(home_dir, "py_i18n_manager"), True),
        (os.path.join(home_dir, "rails_test_app"), True),
        (os.path.join(home_dir, "refacdir"), True),
        (os.path.join(home_dir, "ripme"), True),
        (os.path.join(home_dir, "sd-runner"), True),
        (os.path.join(home_dir, "SillyTavern-MainBranch"), True),
        (os.path.join(home_dir, "silero-api-server"), True),
        (os.path.join(home_dir, "simple_image_compare"), True),
        (os.path.join(home_dir, "stable-diffusion-prompt-reader"), True),
        (os.path.join(home_dir, "stable-diffusion-webui"), True),
        (os.path.join(home_dir, "stable-diffusion-webui-forge"), True),
        (os.path.join(home_dir, "tagesform"), True),
        (os.path.join(home_dir, "temp_tree_sitter_python"), True),

        # Other
        (os.path.join(home_dir, "Deutsch"), True),
        (os.path.join(home_dir, "img"), True),
        (os.path.join(home_dir, "content"), True),
    ]
    
    print("Starting permission reset process...")
    print("This will reset and grant permissions for the following directories:")
    for dir_path, _ in directories_to_reset:
        print(f"  - {dir_path}")
    print("\nIMPORTANT: This script will:")
    print("1. Reset the ACLs to their default state")
    print("2. Grant full permissions to your user account")
    print("3. Apply these changes recursively to all subdirectories")
    print("\nWARNING: While this script is designed to be safe, it's recommended to:")
    print("- Back up important data before running")
    print("- Close any applications that might be using these directories")
    print("- Run this script only when necessary")
    print("\nA log file will be created at:", log_file)
    print("\nPress Enter to continue or Ctrl+C to cancel...")
    input()
    
    # Open log file
    with open(log_file, 'w', encoding='utf-8') as f:
        f.write(f"Permission Reset Log - {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}\n")
        f.write("=" * 50 + "\n\n")
        
        successful_directories = []
        for directory, recursive in directories_to_reset:
            f.write(f"\nProcessing directory: {directory}\n")
            f.write("-" * 30 + "\n")
            
            if reset_permissions(directory, recursive):
                successful_directories.append(directory)
                f.write(f"Successfully reset and granted permissions for {directory}\n")
            else:
                f.write(f"Failed to process permissions for {directory}\n")
            
            f.write("\n")
    
    print(f"\nPermission reset complete. Successfully processed {len(successful_directories)} out of {len(directories_to_reset)} directories.")
    print(f"Detailed log has been saved to: {log_file}")
    
    if len(successful_directories) < len(directories_to_reset):
        print("Some directories could not be processed. Please check the log file for details.")
        sys.exit(1)

if __name__ == "__main__":
    main()

