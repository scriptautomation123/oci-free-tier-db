# Ansible Role Migration Plan

## Overview
Convert the current scattered playbook/task structure into a clean, reusable Ansible role following industry best practices.

## Current State Analysis

### Existing Structure (Problems)
```
ansible/
├── playbooks/
│   ├── local-complete.yml          # 100+ lines, includes many tasks
│   ├── loal-test-validate.yml      # Duplicate testing logic
│   ├── setup-environment.yml      # Simple wrapper 
│   ├── cleanup-resources.yml      # Cleanup logic
│   └── tasks/                      # Task files scattered
│       ├── setup-local-environment.yml    # 202 lines
│       ├── configure-database.yml         # Database config
│       ├── deploy-packages.yml           # Package deployment
│       ├── manage-users.yml              # User management
│       ├── schema-management.yml         # Schema operations
│       └── test-and-validate.yml         # 522 lines testing
├── templates/                      # Templates scattered
└── inventory/
```

### Issues Identified
1. **Duplication**: Multiple playbooks doing similar orchestration
2. **Scattered Logic**: Tasks spread across multiple files
3. **Variable Repetition**: Same defaults defined in multiple places
4. **Hard to Maintain**: Changes require updates in multiple files
5. **Not Reusable**: Can't easily use in other projects

## Target State (Solution)

### New Role Structure
```
ansible/
├── roles/
│   └── oracle_cloud_automation/
│       ├── tasks/
│       │   ├── main.yml                    # Central orchestration
│       │   ├── setup-environment.yml       # Tool installation
│       │   ├── provision-infrastructure.yml # Terraform ops
│       │   ├── configure-database.yml      # DB configuration
│       │   ├── deploy-packages.yml         # Package deployment
│       │   ├── manage-users.yml           # User management
│       │   ├── schema-management.yml      # Schema operations
│       │   ├── test-and-validate.yml      # Testing suite
│       │   └── cleanup.yml                # Resource cleanup
│       ├── templates/                      # All templates centralized
│       │   ├── benchmark-performance.sh.j2
│       │   ├── connection-details.txt.j2
│       │   ├── test-report.md.j2
│       │   └── (all other templates)
│       ├── defaults/
│       │   └── main.yml                    # Default variables
│       ├── vars/
│       │   └── main.yml                    # Role-specific vars
│       ├── handlers/
│       │   └── main.yml                    # Event handlers
│       └── meta/
│           └── main.yml                    # Role metadata
├── playbooks/
│   ├── site.yml                           # Main orchestrator
│   ├── setup.yml                          # Environment setup only
│   ├── deploy.yml                         # Full deployment
│   ├── test.yml                           # Testing only
│   └── cleanup.yml                        # Cleanup only
├── .ansible/                              # Config centralization
│   ├── ansible.cfg
│   └── inventory/
│       └── localhost.yml
└── group_vars/
    └── all.yml                            # Global variables
```

## Migration Steps

### Phase 1: Preparation and Backup
- [ ] **Step 1.1**: Create backup of current structure
- [ ] **Step 1.2**: Create role directory structure
- [ ] **Step 1.3**: Initialize role metadata and defaults

### Phase 2: Role Creation
- [ ] **Step 2.1**: Create role main.yml orchestrator
- [ ] **Step 2.2**: Move and adapt task files to role
- [ ] **Step 2.3**: Move templates to role templates directory
- [ ] **Step 2.4**: Consolidate variables in role defaults

### Phase 3: Playbook Simplification
- [ ] **Step 3.1**: Create simple playbooks that use the role
- [ ] **Step 3.2**: Update variable references and paths
- [ ] **Step 3.3**: Test new playbook structure

### Phase 4: Cleanup and Validation
- [ ] **Step 4.1**: Remove old duplicate files
- [ ] **Step 4.2**: Update documentation and usage patterns
- [ ] **Step 4.3**: Validate all functionality works
- [ ] **Step 4.4**: Update USAGE.md with new patterns

## Implementation Benefits

### Immediate Benefits
1. **Eliminated Duplication**: Single source of truth for all Oracle automation
2. **Cleaner Structure**: Standard Ansible role pattern
3. **Better Maintainability**: Changes in one place
4. **Reusability**: Role can be used in other projects

### Usage Simplification
```bash
# Before (complex)
ansible-playbook ansible/playbooks/local-complete.yml -e "deployment_action=deploy"

# After (simple)
ansible-playbook playbooks/deploy.yml
ansible-playbook playbooks/test.yml
ansible-playbook playbooks/setup.yml
```

### Variable Management
```yaml
# Before: Variables scattered across multiple files
# After: Centralized in role defaults/main.yml
oracle_cloud_automation:
  terraform_version: "latest"
  oci_cli_version: "latest" 
  deployment_action: "deploy"
  always_free_protection: true
  load_test_data: false
```

## Testing Strategy

### Validation Steps
1. **Syntax Check**: All new playbooks pass syntax validation
2. **Dry Run**: Check mode works for all playbooks
3. **Functionality**: Core features work (setup, deploy, test, cleanup)
4. **Compatibility**: Existing workflows continue to work

### Rollback Plan
- Original files backed up with timestamp
- Can restore previous structure if issues arise
- Migration can be done incrementally

## Success Criteria

### Technical
- [ ] All functionality preserved
- [ ] No duplication in codebase
- [ ] Standard Ansible role structure
- [ ] All tests pass

### Operational  
- [ ] Simpler command structure
- [ ] Easier to maintain and extend
- [ ] Documentation updated
- [ ] Team can use new patterns

## Timeline
- **Phase 1**: 15 minutes (preparation)
- **Phase 2**: 30 minutes (role creation)
- **Phase 3**: 20 minutes (playbook creation)
- **Phase 4**: 15 minutes (cleanup and validation)
- **Total**: ~80 minutes

## Risk Mitigation
1. **Backup Strategy**: Full backup before any changes
2. **Incremental Approach**: Test each phase before proceeding
3. **Syntax Validation**: Check all files before testing
4. **Rollback Ready**: Can restore original state quickly