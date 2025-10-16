"""
JSON File Merger with Configurable Merge Strategies

This script provides a sophisticated JSON file merging utility that allows you to intelligently
combine two JSON files with fine-grained control over merge behavior. It's particularly useful
for configuration management, data migration, and preserving user customizations while updating
application settings.

Key Features:
- Flexible merge strategies with customizable rules for different data types
- Support for nested key exclusion using dot notation (e.g., "info.weather")
- Type-aware merging with special handling for dictionaries, lists, and primitives
- Custom handlers for specific keys or data types
- Conflict resolution with multiple action options (keep new, keep old, skip, custom)
- Command-line interface for easy integration into workflows

Usage:
    python update_json.py <old_file> <new_file> [<output_file>]

The script merges the 'old_file' into the 'new_file', preserving new values while selectively
incorporating old values based on the configured merge strategy. This is ideal for scenarios
where you want to update a configuration file while preserving certain user customizations.

Example Use Cases:
- Updating application configs while preserving user settings
- Merging database schemas with custom field definitions
- Combining API responses with cached data
- Preserving user preferences during software updates
"""

import json
from typing import Any, Dict, List, Set, Union, Optional, Callable
from pathlib import Path
from enum import Enum, auto

class MergeAction(Enum):
    """Defines possible actions to take during merge operations"""
    SKIP = auto()  # Skip this key/value pair
    KEEP_NEW = auto()  # Keep the new value
    KEEP_OLD = auto()  # Keep the old value
    MERGE = auto()  # Merge the values (for dicts and lists)
    CUSTOM = auto()  # Use custom handler

class MergeStrategy:
    """
    Defines how to handle different merge scenarios.
    Each method returns a MergeAction or a custom handler function.
    """
    def __init__(self):
        # Default behaviors
        self._exclude_rules: Dict[str, MergeAction] = {}
        self._missing_key_rules: Dict[str, MergeAction] = {}
        self._none_value_rules: Dict[str, MergeAction] = {}
        self._type_mismatch_rules: Dict[tuple, MergeAction] = {}
        self._type_specific_rules: Dict[type, Callable] = {}
        self._custom_handlers: Dict[str, Callable] = {}

    def set_exclude_rule(self, key_pattern: str, action: MergeAction) -> None:
        """Set how to handle excluded keys"""
        self._exclude_rules[key_pattern] = action

    def set_missing_key_rule(self, key_pattern: str, action: MergeAction) -> None:
        """Set how to handle keys missing in new dict"""
        self._missing_key_rules[key_pattern] = action

    def set_none_value_rule(self, key_pattern: str, action: MergeAction) -> None:
        """Set how to handle None values"""
        self._none_value_rules[key_pattern] = action

    def set_type_mismatch_rule(self, old_type: type, new_type: type, action: MergeAction) -> None:
        """Set how to handle type mismatches"""
        self._type_mismatch_rules[(old_type, new_type)] = action

    def set_type_specific_rule(self, value_type: type, handler: Callable) -> None:
        """Set custom handler for specific types"""
        self._type_specific_rules[value_type] = handler

    def set_custom_handler(self, key_pattern: str, handler: Callable) -> None:
        """Set custom handler for specific keys"""
        self._custom_handlers[key_pattern] = handler

    def get_exclude_action(self, key: str) -> Optional[MergeAction]:
        """Get action for excluded key"""
        for pattern, action in self._exclude_rules.items():
            if key.startswith(pattern):
                return action
        return None

    def get_missing_key_action(self, key: str) -> Optional[MergeAction]:
        """Get action for missing key"""
        for pattern, action in self._missing_key_rules.items():
            if key.startswith(pattern):
                return action
        return MergeAction.SKIP

    def get_none_value_action(self, key: str) -> Optional[MergeAction]:
        """Get action for None value"""
        for pattern, action in self._none_value_rules.items():
            if key.startswith(pattern):
                return action
        return MergeAction.SKIP

    def get_type_mismatch_action(self, old_type: type, new_type: type) -> Optional[MergeAction]:
        """Get action for type mismatch"""
        return self._type_mismatch_rules.get((old_type, new_type))

    def get_type_specific_handler(self, value_type: type) -> Optional[Callable]:
        """Get handler for specific type"""
        return self._type_specific_rules.get(value_type)

    def get_custom_handler(self, key: str) -> Optional[Callable]:
        """Get custom handler for key"""
        for pattern, handler in self._custom_handlers.items():
            if key.startswith(pattern):
                return handler
        return None

def make_hashable(obj: Any) -> Union[str, Any]:
    """
    Convert an object into a hashable form for comparison.
    For dicts and lists, returns a JSON string representation.
    For other types, returns the object as-is if it's hashable.
    """
    if isinstance(obj, (dict, list)):
        return json.dumps(obj, sort_keys=True)
    return obj

def load_json_file(file_path: str) -> Dict[str, Any]:
    """Load a JSON file and return its contents as a dictionary."""
    with open(file_path, 'r') as f:
        return json.load(f)

def save_json_file(data: Dict[str, Any], file_path: str) -> None:
    """Save a dictionary to a JSON file."""
    with open(file_path, 'w') as f:
        json.dump(data, f, indent=4)

def merge_dicts_with_strategy(
    new_dict: Dict[str, Any],
    old_dict: Dict[str, Any],
    strategy: MergeStrategy,
    current_path: str = ""
) -> Dict[str, Any]:
    """
    Merge two dictionaries using a provided strategy.
    This is a facade around the core merge_dicts function that provides flexible merge behaviors.
    
    Args:
        new_dict: The new dictionary to be updated
        old_dict: The old dictionary containing values to merge
        strategy: MergeStrategy defining merge behaviors
        current_path: Current path in the dictionary structure (used for nested keys)
    
    Returns:
        Merged dictionary
    """
    result = new_dict.copy()
    
    for key, old_value in old_dict.items():
        full_path = f"{current_path}.{key}" if current_path else key
        
        # Check for exclude rules
        exclude_action = strategy.get_exclude_action(full_path)
        if exclude_action:
            if exclude_action == MergeAction.CUSTOM:
                custom_handler = strategy.get_custom_handler(full_path)
                if custom_handler:
                    result[key] = custom_handler(new_dict.get(key), old_value)
            continue
            
        # Check for missing key rules
        if key not in new_dict:
            missing_action = strategy.get_missing_key_action(full_path)
            if missing_action == MergeAction.KEEP_OLD:
                result[key] = old_value
            elif missing_action == MergeAction.CUSTOM:
                custom_handler = strategy.get_custom_handler(full_path)
                if custom_handler:
                    result[key] = custom_handler(None, old_value)
            continue
            
        new_value = new_dict[key]
        
        # Check for None value rules
        if old_value is None or new_value is None:
            none_action = strategy.get_none_value_action(full_path)
            if none_action == MergeAction.KEEP_NEW:
                continue
            elif none_action == MergeAction.KEEP_OLD:
                result[key] = old_value
            elif none_action == MergeAction.CUSTOM:
                custom_handler = strategy.get_custom_handler(full_path)
                if custom_handler:
                    result[key] = custom_handler(new_value, old_value)
            continue
            
        # Check for type mismatch rules
        if type(old_value) is not type(new_value):
            type_action = strategy.get_type_mismatch_action(type(old_value), type(new_value))
            if type_action == MergeAction.KEEP_NEW:
                continue
            elif type_action == MergeAction.KEEP_OLD:
                result[key] = old_value
            elif type_action == MergeAction.CUSTOM:
                custom_handler = strategy.get_custom_handler(full_path)
                if custom_handler:
                    result[key] = custom_handler(new_value, old_value)
            continue
            
        # Check for type-specific handlers
        type_handler = strategy.get_type_specific_handler(type(old_value))
        if type_handler:
            result[key] = type_handler(new_value, old_value)
            continue
            
        # Default behavior for each type
        if isinstance(old_value, dict):
            result[key] = merge_dicts_with_strategy(
                new_value,
                old_value,
                strategy,
                full_path
            )
        elif isinstance(old_value, list):
            new_list = new_value.copy()
            existing_items = {make_hashable(item) for item in new_list}
            
            for item in old_value:
                hashable_item = make_hashable(item)
                if hashable_item not in existing_items:
                    new_list.append(item)
                    existing_items.add(hashable_item)
                    
            result[key] = new_list
        elif isinstance(old_value, (int, float, str, bool)):
            if old_value != new_value:
                print(f"Info: Value mismatch for '{full_path}': old={old_value}, new={new_value} (keeping new value)")
            
    return result

def update_json_files(
    new_file: str,
    old_file: str,
    output_file: str,
    exclude_keys: List[str]
) -> None:
    """
    Merge two JSON files, preserving values from the new file while updating with old file values.
    
    Args:
        new_file: Path to the new JSON file
        old_file: Path to the old JSON file
        output_file: Path to save the merged result
        exclude_keys: List of keys to exclude from merging (can be nested using dot notation)
    """
    new_data = load_json_file(new_file)
    old_data = load_json_file(old_file)
    
    # Convert exclude_keys to a set for faster lookups
    exclude_set = set(exclude_keys)
    
    # Perform the merge
    merged_data = merge_dicts_with_strategy(new_data, old_data, exclude_set)
    
    # Save the result
    save_json_file(merged_data, output_file)

# Example usage with strategy
if __name__ == "__main__":
    import os
    import sys
    if len(sys.argv) < 3:
        print("Usage: python update_json.py <old_file> <new_file> [<output_file>]")
        sys.exit(1)
    
    # Example paths - replace with actual paths
    old_file = sys.argv[1]
    new_file = sys.argv[2]
    output_file = sys.argv[3] if len(sys.argv) > 3 else None

    if not Path(new_file).exists():
        print(f"Error: New file {new_file} does not exist")
        sys.exit(1)
    if not Path(old_file).exists():
        print(f"Error: Old file {old_file} does not exist")
        sys.exit(1)
    if output_file and not Path(output_file).parent.exists():
        print(f"Error: Output directory {output_file.parent} does not exist")
        sys.exit(1)
    
    if output_file is None:
        output_file = os.path.join(os.path.dirname(new_file), f"{Path(new_file).stem}_merged.json")

    print(f"Updating {new_file} with {old_file} into {output_file}")

    # Example keys to exclude - can be nested using dot notation
    exclude_keys = [
        "info.directories_cache",
        "info.config_history_index",
        "info.weather",
        "info.news",
        "info.joke",
        "info.quote",
        "info.fact",
        "info.fable",
        "info.funny_story",
        "info.poem",
        "info.aphorism",
        "info.riddle",
        "info.motivation",
        "info.random_wiki_article",
        "info.truth_and_lie",
        "info.hackernews",
        "info.tongue_twister",
        "info.calendar",
        "info.track_context_prior",
        "info.track_context_post",
        "info.language_learning",
        "history"
        "trackers"
    ]
    
    # Create and configure merge strategy
    strategy = MergeStrategy()
    
    # Set up exclude rules
    for key in exclude_keys:
        strategy.set_exclude_rule(key, MergeAction.SKIP)
    
    # Set up type-specific handlers
    def handle_lists(new_list: List, old_list: List) -> List:
        """Custom list merging logic"""
        result = new_list.copy()
        existing_items = {make_hashable(item) for item in result}
        for item in old_list:
            hashable_item = make_hashable(item)
            if hashable_item not in existing_items:
                result.append(item)
                existing_items.add(hashable_item)
        return result
    
    strategy.set_type_specific_rule(list, handle_lists)
    
    # Set up custom handlers for specific keys
    def handle_history(new_history: Any, old_history: Any) -> Any:
        """Custom handler for history field"""
        if new_history is None:
            return old_history
        if old_history is None:
            return new_history
        # Implement custom history merging logic here
        return new_history
    
    strategy.set_custom_handler("history", handle_history)
    
    # Perform the merge with strategy
    new_data = load_json_file(new_file)
    old_data = load_json_file(old_file)
    merged_data = merge_dicts_with_strategy(new_data, old_data, strategy)
    
    # Save the result
    save_json_file(merged_data, output_file)

    print(f"Updated file saved to {output_file}")
