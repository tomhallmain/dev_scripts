"""
Script Finder with Caching

This script provides a file discovery tool designed to find scripts and code files
based on multiple criteria including file size, line count, and content keywords. It features
caching to improve performance on subsequent searches of the same directories, making it
suitable for searching large codebases or entire file systems.

Key Features:
- Multi-criteria search: file extensions, minimum line count, and content keywords
- Caching system with configurable cache expiration (24 hours default)
- Automatic directory skipping for common non-source directories (node_modules, .git, etc.)
- Content-based keyword matching with case-insensitive search
- Detailed progress reporting and verbose output options
- Content preview of matching files
- Cross-platform support with proper path handling

Usage:
    python find_script.py [directory] [options]

The script searches for files that meet all specified criteria, making it useful for finding
large scripts, configuration files, or any code files containing specific functionality.

Example Use Cases:
- Finding large Python scripts containing specific functionality (e.g., LoRA, ML models)
- Locating configuration files with particular settings
- Discovering documentation files with specific topics
- Finding scripts across multiple projects or entire drives
- Identifying files that need refactoring based on size and content

Performance:
- First search: scans all files (can be slow on large directories)
- Subsequent searches: uses cached file lists for near-instant results
- Cache automatically expires after 24 hours to ensure fresh results
"""

import os
import argparse
import sys
import json
import hashlib
from pathlib import Path
from datetime import datetime

class ScriptFinder:
    def __init__(self, cache_dir=None):
        if cache_dir is None:
            cache_dir = '.script_finder_cache'
        self.cache_dir = Path(cache_dir)
        self.cache_dir.mkdir(exist_ok=True)
    
    def _get_cache_key(self, directory, extensions):
        """Generate a unique cache key for directory + extensions."""
        key_string = f"{Path(directory).resolve()}_{'_'.join(sorted(extensions))}"
        return hashlib.md5(key_string.encode()).hexdigest()
    
    def _get_cache_file(self, cache_key):
        """Get the cache file path for a given key."""
        return self.cache_dir / f"{cache_key}.json"
    
    def _read_cache(self, cache_key, max_age_hours=24):
        """Read from cache if it exists and is not too old."""
        cache_file = self._get_cache_file(cache_key)
        
        if not cache_file.exists():
            return None
        
        # Check cache age
        cache_mtime = datetime.fromtimestamp(cache_file.stat().st_mtime)
        cache_age = (datetime.now() - cache_mtime).total_seconds() / 3600
        
        if cache_age > max_age_hours:
            return None
        
        try:
            with open(cache_file, 'r', encoding='utf-8') as f:
                return json.load(f)
        except (json.JSONDecodeError, Exception):
            return None
    
    def _write_cache(self, cache_key, file_list):
        """Write file list to cache."""
        cache_file = self._get_cache_file(cache_key)
        try:
            with open(cache_file, 'w', encoding='utf-8') as f:
                json.dump({
                    'timestamp': datetime.now().isoformat(),
                    'files': file_list
                }, f, indent=2)
            return True
        except Exception:
            return False
    
    def gather_files(self, directory, extensions, use_cache=True, verbose=False):
        """
        Gather all files with specified extensions, with optional caching.
        
        Args:
            directory (str): Directory to search
            extensions (list): File extensions to include
            use_cache (bool): Whether to use cached results
            verbose (bool): Whether to print progress
            
        Returns:
            list: List of file paths
        """
        cache_key = self._get_cache_key(directory, extensions)
        
        # Try to read from cache
        if use_cache:
            cached = self._read_cache(cache_key)
            if cached is not None:
                if verbose:
                    print(f"📁 Using cached file list ({len(cached['files'])} files)")
                return [Path(f) for f in cached['files']]
        
        if verbose:
            print(f"🔍 Gathering files from: {directory}")
            print(f"   Extensions: {', '.join(extensions)}")
        
        file_list = []
        extension_set = {ext.lower() for ext in extensions}
        
        for root, dirs, files in os.walk(directory):
            # Skip common directories that are unlikely to contain the script
            dirs[:] = [d for d in dirs if not self._should_skip_directory(d)]
            
            for file in files:
                file_path = Path(root) / file
                if file_path.suffix.lower() in extension_set:
                    file_list.append(file_path)
            
            if verbose and len(file_list) % 100 == 0 and len(file_list) > 0:
                print(f"   Found {len(file_list)} files so far...")
        
        # Convert to strings for JSON serialization and cache
        file_list_str = [str(f) for f in file_list]
        
        if use_cache:
            self._write_cache(cache_key, file_list_str)
            if verbose:
                print(f"💾 Cached {len(file_list_str)} files for future searches")
        
        return file_list
    
    def _should_skip_directory(self, dir_name):
        """Check if a directory should be skipped during search."""
        skip_dirs = {
            'node_modules', '.git', '__pycache__', '.pytest_cache', '.vscode',
            '.idea', 'venv', 'env', '.env', 'build', 'dist', 'target',
            'AppData', 'Local Settings', 'Windows', 'System32', 'Temp', 'tmp'
            "installer_files", "miniconda3", "anaconda3", "miniconda", "anaconda"
        }
        return dir_name in skip_dirs or dir_name.startswith('.')
    
    def find_script(self, directory, extensions=None, min_lines=300, 
                   content_keywords=None, use_cache=True, verbose=False):
        """
        Find scripts based on file size, line count, and content keywords.
        
        Args:
            directory (str): Root directory to search
            extensions (list): File extensions to search for (default: ['.py'])
            min_lines (int): Minimum number of lines required
            content_keywords (list): Keywords to search for in file content
            use_cache (bool): Whether to use cached file lists
            verbose (bool): Whether to print detailed progress
        """
        if extensions is None:
            extensions = ['.py']
        if content_keywords is None:
            content_keywords = ['lora', 'LoRA', 'model', 'tag']
        
        if verbose:
            print(f"Search criteria:")
            print(f"  Directory: {directory}")
            print(f"  Extensions: {extensions}")
            print(f"  Minimum lines: {min_lines}")
            print(f"  Content keywords: {content_keywords}")
            print(f"  Use cache: {use_cache}")
            print("-" * 50)
        
        # Gather files (with caching)
        all_files = self.gather_files(directory, extensions, use_cache, verbose)
        
        if verbose:
            print(f"📁 Total files to check: {len(all_files)}")
        
        potential_matches = []
        
        for file_path in all_files:
            try:
                # Count lines and check minimum
                with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                    lines = f.readlines()
                
                line_count = len(lines)
                
                if line_count < min_lines:
                    if verbose:
                        print(f"⏩ Skipping {file_path.name} - {line_count} lines (< {min_lines})")
                    continue
                
                # Check for content keywords
                file_content = ''.join(lines).lower()
                keyword_matches = []
                
                for keyword in content_keywords:
                    if keyword.lower() in file_content:
                        keyword_matches.append(keyword)
                
                if keyword_matches:
                    match_info = {
                        'path': file_path,
                        'line_count': line_count,
                        'matched_keywords': keyword_matches,
                        'size_kb': round(file_path.stat().st_size / 1024, 2)
                    }
                    potential_matches.append(match_info)
                    
                    if verbose:
                        print(f"✅ Match: {file_path}")
                        print(f"     Lines: {line_count}, Size: {match_info['size_kb']}KB")
                        print(f"     Keywords: {', '.join(keyword_matches)}")
                else:
                    if verbose:
                        print(f"⏩ Skipping {file_path.name} - no keyword matches")
                        
            except Exception as e:
                if verbose:
                    print(f"❌ Error reading {file_path}: {e}")
        
        return potential_matches

def display_results(matches, show_content_preview=False):
    """Display the search results in a formatted way."""
    if not matches:
        print("❌ No matching files found.")
        return
    
    print(f"\n🎉 Found {len(matches)} potential matches:")
    print("=" * 80)
    
    for i, match in enumerate(matches, 1):
        print(f"\n{i}. {match['path']}")
        print(f"   📊 Lines: {match['line_count']}, Size: {match['size_kb']}KB")
        print(f"   🔍 Matched keywords: {', '.join(match['matched_keywords'])}")
        
        if show_content_preview:
            try:
                with open(match['path'], 'r', encoding='utf-8', errors='ignore') as f:
                    lines = f.readlines()[:5]  # First 5 lines
                print("   📄 Preview:")
                for j, line in enumerate(lines, 1):
                    print(f"      {j}: {line.strip()}")
            except Exception as e:
                print(f"   ❌ Could not read preview: {e}")

def clear_cache(cache_dir=None):
    """Clear all cached file lists."""
    if cache_dir is None:
        cache_dir = Path.home() / '.script_finder_cache'
    cache_dir = Path(cache_dir)
    
    if cache_dir.exists():
        cache_files = list(cache_dir.glob("*.json"))
        for cache_file in cache_files:
            cache_file.unlink()
        print(f"🗑️  Cleared {len(cache_files)} cache files")
    else:
        print("💡 No cache directory found")

def main():
    parser = argparse.ArgumentParser(
        description='Find Python scripts based on size and content criteria',
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  # Basic search for Python scripts with 300+ lines containing LoRA-related content
  python find_script.py C:\\\\Users\\\\YourName
  
  # Search without using cache (force fresh file gathering)
  python find_script.py C:\\\\ --no-cache
  
  # Search with custom extensions and line count
  python find_script.py C:\\\\ --ext .py .txt .md --min-lines 200
  
  # Search with specific keywords
  python find_script.py D:\\\\Projects --keywords lora model tag extraction --verbose
  
  # Show content preview of matches
  python find_script.py . --preview
  
  # Clear all cached file lists
  python find_script.py --clear-cache
        """
    )
    
    parser.add_argument('directory', nargs='?', default=Path.home(), 
                       help='Directory to search (default: home directory)')
    parser.add_argument('--ext', '--extensions', nargs='+', default=['.py'],
                       help='File extensions to search for (default: .py)')
    parser.add_argument('--min-lines', type=int, default=300,
                       help='Minimum number of lines (default: 300)')
    parser.add_argument('--keywords', nargs='+', 
                       default=['lora', 'model', 'tag', 'extract'],
                       help='Keywords to search for in content (default: lora, model, tag, extract)')
    parser.add_argument('--preview', action='store_true',
                       help='Show content preview of matching files')
    parser.add_argument('--verbose', action='store_true',
                       help='Show detailed search progress')
    parser.add_argument('--no-cache', action='store_true',
                       help='Ignore cache and gather fresh file list')
    parser.add_argument('--clear-cache', action='store_true',
                       help='Clear all cached file lists')
    
    args = parser.parse_args()
    
    # Handle clear cache command
    if args.clear_cache:
        clear_cache()
        return
    
    # Validate directory
    if not os.path.exists(args.directory):
        print(f"Error: Directory '{args.directory}' does not exist")
        sys.exit(1)
    
    print("🔍 Script Search Tool with Caching")
    print(f"Searching for files with:")
    print(f"  - Extensions: {', '.join(args.ext)}")
    print(f"  - Minimum lines: {args.min_lines}")
    print(f"  - Keywords: {', '.join(args.keywords)}")
    print(f"  - Use cache: {not args.no_cache}")
    print()
    
    # Initialize finder and perform search
    finder = ScriptFinder()
    matches = finder.find_script(
        directory=args.directory,
        extensions=args.ext,
        min_lines=args.min_lines,
        content_keywords=args.keywords,
        use_cache=not args.no_cache,
        verbose=args.verbose
    )
    
    # Display results
    display_results(matches, show_content_preview=args.preview)

if __name__ == "__main__":
    main()
