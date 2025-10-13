#!/usr/bin/env python3
"""
Fix FQCN issues in Ansible playbooks by adding ansible.builtin prefixes
"""

import re
import sys

def fix_fqcn_in_file(file_path):
    """Fix FQCN issues in a YAML file"""
    
    # Builtin modules that need FQCN prefixes
    builtin_modules = [
        'assert', 'command', 'copy', 'debug', 'fail', 'file', 'get_url',
        'group', 'include_tasks', 'include_vars', 'lineinfile', 'meta',
        'pause', 'raw', 'script', 'service', 'set_fact', 'setup',
        'shell', 'slurp', 'stat', 'template', 'unarchive', 'uri',
        'user', 'wait_for', 'yum', 'apt', 'package', 'systemd',
        'blockinfile', 'replace', 'import_tasks', 'import_playbook'
    ]
    
    try:
        with open(file_path, 'r') as f:
            content = f.read()
        
        # Pattern to match module calls that need FQCN
        for module in builtin_modules:
            # Match patterns like "      debug:" or "        - command:"
            pattern = rf'^(\s+)({module}):(\s*)'
            replacement = rf'\1ansible.builtin.{module}:\3'
            content = re.sub(pattern, replacement, content, flags=re.MULTILINE)
        
        with open(file_path, 'w') as f:
            f.write(content)
        
        print(f"✅ Fixed FQCN issues in {file_path}")
        return True
        
    except Exception as e:
        print(f"❌ Error fixing {file_path}: {e}")
        return False

if __name__ == "__main__":
    if len(sys.argv) != 2:
        print("Usage: python3 fix_fqcn.py <ansible_file.yml>")
        sys.exit(1)
    
    file_path = sys.argv[1]
    success = fix_fqcn_in_file(file_path)
    sys.exit(0 if success else 1)