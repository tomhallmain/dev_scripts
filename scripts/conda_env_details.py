import json
import os
import subprocess
import sys
import argparse
from typing import Dict, List, Optional, Tuple, Any


def run_command(command: List[str]) -> Tuple[int, str, str]:
    """
    Run a command and return (returncode, stdout, stderr) with stdout/stderr decoded as UTF-8.
    """
    try:
        completed = subprocess.run(
            command,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
            text=True,
            encoding="utf-8",
        )
        return completed.returncode, completed.stdout, completed.stderr
    except FileNotFoundError as exc:
        return 127, "", str(exc)


def human_size(num_bytes: Optional[int]) -> str:
    if num_bytes is None:
        return "-"
    units = ["B", "KB", "MB", "GB", "TB"]
    size = float(num_bytes)
    for unit in units:
        if size < 1024.0 or unit == units[-1]:
            return f"{size:.1f} {unit}"
        size /= 1024.0


def get_python_major_minor_version_tuple(version_str: Optional[str]) -> Tuple[int, int]:
    """Extract major.minor version as tuple of integers for proper numerical sorting."""
    if not version_str:
        return (0, 0)
    try:
        # Extract major.minor from version string like "3.11.11"
        parts = version_str.split('.')
        if len(parts) >= 2:
            return (int(parts[0]), int(parts[1]))
        elif len(parts) == 1:
            return (int(parts[0]), 0)
        return (0, 0)
    except (ValueError, IndexError):
        return (0, 0)


def parse_python_version(version_str: Optional[str]) -> Tuple[str, str, str]:
    """Parse Python version into major, minor, patch components."""
    if not version_str:
        return ("-", "-", "-")
    try:
        parts = version_str.split('.')
        major = parts[0] if len(parts) > 0 else "-"
        minor = parts[1] if len(parts) > 1 else "-"
        patch = parts[2] if len(parts) > 2 else "-"
        return (major, minor, patch)
    except (ValueError, IndexError):
        return ("-", "-", "-")


def get_directory_size_bytes(root_path: str) -> Optional[int]:
    """
    Recursively sum file sizes under root_path. Returns None if path doesn't exist.
    """
    if not os.path.isdir(root_path):
        return None
    total = 0
    for dirpath, _, filenames in os.walk(root_path):
        for filename in filenames:
            file_path = os.path.join(dirpath, filename)
            try:
                total += os.path.getsize(file_path)
            except OSError:
                # Skip files we cannot access
                continue
    return total


def conda_env_list_json() -> Optional[Dict[str, Any]]:
    code, out, _ = run_command(["conda", "env", "list", "--json"])
    if code != 0:
        return None
    try:
        return json.loads(out)
    except json.JSONDecodeError:
        return None


def parse_conda_env_list_text(text: str) -> List[Dict[str, Any]]:
    """
    Fallback parser for `conda env list` text output. Returns list of {name, prefix, is_base}.
    """
    envs: List[Dict[str, Any]] = []
    lines = [ln.rstrip() for ln in text.splitlines()]
    for ln in lines:
        if not ln or ln.startswith("#"):
            continue
        # Remove possible marker '*'
        marker_stripped = ln.replace(" * ", " ").replace("* ", "").replace(" *", "")
        # Split on 2+ spaces
        parts = [p for p in marker_stripped.split(" ") if p]
        if len(parts) == 1:
            # Some outputs include only a path (e.g., installer_files/conda). Treat name as last folder name.
            prefix = parts[0]
            name = os.path.basename(prefix.rstrip(os.sep)) or prefix
        else:
            # name then path
            name, prefix = parts[0], parts[-1]
        is_base = name.lower() == "base"
        envs.append({"name": name, "prefix": prefix, "is_base": is_base})
    return envs


def conda_envs() -> List[Dict[str, Any]]:
    data = conda_env_list_json()
    if data and isinstance(data, dict) and "envs" in data:
        env_paths = data.get("envs", [])
        default_prefix = data.get("default_prefix")
        results: List[Dict[str, Any]] = []
        for prefix in env_paths:
            name = os.path.basename(prefix.rstrip(os.sep))
            # base env is usually at miniconda root (without envs subdir)
            is_base = default_prefix == prefix or name.lower() == "base"
            results.append({"name": name, "prefix": prefix, "is_base": is_base})
        return results

    # Fallback to text parsing
    code, out, _ = run_command(["conda", "env", "list"])
    if code != 0:
        return []
    return parse_conda_env_list_text(out)


def conda_run_python(prefix: str, code_snippet: str, timeout: int = 60) -> Tuple[int, str, str]:
    """
    Execute Python code within the target environment using `conda run -p <prefix>`.
    Returns (returncode, stdout, stderr).
    """
    try:
        completed = subprocess.run(
            ["conda", "run", "-p", prefix, "python", "-c", code_snippet],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
            text=True,
            encoding="utf-8",
            timeout=timeout,
        )
        return completed.returncode, completed.stdout.strip(), completed.stderr.strip()
    except subprocess.TimeoutExpired:
        return 124, "", "Timed out"
    except FileNotFoundError as exc:
        return 127, "", str(exc)


def get_python_version(prefix: str) -> Optional[str]:
    rc, out, _ = conda_run_python(prefix, "import platform; print(platform.python_version())")
    return out if rc == 0 and out else None


def get_pip_version(prefix: str) -> Optional[str]:
    # Try multiple methods to get pip version with shorter timeout
    methods = [
        "import sys;\ntry:\n import pip; print(pip.__version__)\nexcept Exception:\n sys.exit(1)",
        "import subprocess; import sys; result = subprocess.run([sys.executable, '-m', 'pip', '--version'], capture_output=True, text=True); print(result.stdout.split()[1] if result.returncode == 0 else '')",
        "import sys; print('pip not available')"
    ]
    
    for method in methods:
        rc, out, err = conda_run_python(prefix, method, timeout=30)
        if rc == 0 and out and out.strip() and out.strip() != "pip not available":
            return out.strip()
    
    return None


def get_pip_packages_count(prefix: str) -> Optional[int]:
    # Use python -m pip list --format=json to count unique packages
    try:
        completed = subprocess.run(
            ["conda", "run", "-p", prefix, "python", "-m", "pip", "list", "--format=json"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
            text=True,
            encoding="utf-8",
            timeout=240,
        )
    except (FileNotFoundError, subprocess.TimeoutExpired):
        return None
    if completed.returncode != 0:
        return None
    try:
        data = json.loads(completed.stdout)
        if isinstance(data, list):
            # Count unique names to exclude effective duplicates
            unique_names = {str(pkg.get("name", "")).lower() for pkg in data}
            return len([n for n in unique_names if n])
        return None
    except json.JSONDecodeError:
        return None


def gather_env_details(env: Dict[str, Any], current: int, total: int) -> Dict[str, Any]:
    prefix = env.get("prefix")
    env_name = env.get("name", "unknown")
    
    # Show progress
    print(f"Data gathered from {current} / {total} environments (current: {env_name})", flush=True)
    
    details = {
        "name": env_name,
        "prefix": prefix,
        "is_base": bool(env.get("is_base")),
        "size_bytes": None,
        "python_version": None,
        "package_count": None,
    }

    print(f"  Calculating directory size for {env_name}...", flush=True)
    details["size_bytes"] = get_directory_size_bytes(prefix)
    
    print(f"  Getting Python version for {env_name}...", flush=True)
    details["python_version"] = get_python_version(prefix)
    
    # print(f"  Getting pip version for {env_name}...", flush=True)
    # details["pip_version"] = get_pip_version(prefix)
    # if details["pip_version"] is None:
    #     print(f"    Warning: Could not get pip version for {env_name}", flush=True)
    
    print(f"  Counting packages for {env_name}...", flush=True)
    details["package_count"] = get_pip_packages_count(prefix)
    
    print(f"  Completed {env_name}", flush=True)
    return details


def render_table(rows: List[Dict[str, Any]]) -> str:
    headers = ["Major", "Minor", "Patch", "Name", "Path", "Size", "Pkgs"]
    data_rows: List[List[str]] = []
    for r in rows:
        major, minor, patch = parse_python_version(r.get("python_version"))
        data_rows.append([
            major,
            minor,
            patch,
            str(r.get("name") or ""),
            str(r.get("prefix") or ""),
            human_size(r.get("size_bytes")),
            str(r.get("package_count") if r.get("package_count") is not None else "-"),
        ])

    # compute column widths
    widths = [len(h) for h in headers]
    for row in data_rows:
        for i, cell in enumerate(row):
            widths[i] = max(widths[i], len(cell))

    def fmt_row(cells: List[str]) -> str:
        formatted_cells = []
        for i, cell in enumerate(cells):
            # Right-align Major, Minor, Patch, Size, and Pkgs columns
            if i in [0, 1, 2, 5, 6]:  # Major, Minor, Patch, Size, Pkgs
                formatted_cells.append(cell.rjust(widths[i]))
            else:  # Name, Path
                formatted_cells.append(cell.ljust(widths[i]))
        return "  ".join(formatted_cells)

    lines = [fmt_row(headers), fmt_row(["-" * w for w in widths])]
    for row in data_rows:
        lines.append(fmt_row(row))
    return "\n".join(lines)


def main(argv: Optional[List[str]] = None) -> int:
    parser = argparse.ArgumentParser(description="Enhanced Conda environments listing with details.")
    parser.add_argument("--json", action="store_true", help="Output JSON instead of a table.")
    parser.add_argument("--sort", choices=["name", "size", "python"], default="python", help="Sort by column.")
    args = parser.parse_args(argv)

    env_list = conda_envs()
    # Exclude installer/root entries and meta envs often named 'conda' or 'miniconda'
    env_list = [e for e in env_list if str(e.get("name", "")).lower() not in ("conda", "miniconda")]
    if not env_list:
        print("No conda environments found or 'conda' not available.", file=sys.stderr)
        return 1

    details: List[Dict[str, Any]] = []
    total_envs = len(env_list)
    for i, env in enumerate(env_list, 1):
        details.append(gather_env_details(env, i, total_envs))

    if args.sort == "name":
        details.sort(key=lambda d: (str(d.get("name") or "").lower()))
    elif args.sort == "size":
        details.sort(key=lambda d: (-(d.get("size_bytes") or -1)))
    elif args.sort == "python":
        # Sort by Python major.minor version (as tuple), then by name, then by size (desc), then by package count (desc)
        details.sort(key=lambda d: (
            get_python_major_minor_version_tuple(d.get("python_version")),
            str(d.get("name") or "").lower(),
            -(d.get("size_bytes") or -1),
            -(d.get("package_count") or -1)
        ))

    if args.__dict__.get("json"):
        print(json.dumps(details, indent=2))
    else:
        print(render_table(details))
    return 0


if __name__ == "__main__":
    sys.exit(main())


