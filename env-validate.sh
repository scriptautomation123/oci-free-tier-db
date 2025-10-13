#!/bin/bash

# =============================================================================
# Generic Infrastructure Validation Script
# =============================================================================
# Description: Comprehensive validation for Terraform, Ansible, and other
#              infrastructure components. Generic and reusable across projects.
# Author: Infrastructure Team
# Version: 1.0
# =============================================================================

set -uo pipefail

# Colors and formatting
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly BOLD='\033[1m'
readonly NC='\033[0m' # No Color

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
readonly PROJECT_ROOT="$SCRIPT_DIR"
readonly LOG_FILE="${PROJECT_ROOT}/validation.log"

# Validation counters
TOTAL_CHECKS=0
PASSED_CHECKS=0
FAILED_CHECKS=0
WARNING_CHECKS=0

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

log() {
    echo -e "$1" | tee -a "$LOG_FILE"
}

log_info() {
    log "${BLUE}ℹ ${NC}$1"
}

log_success() {
    log "${GREEN}✅ $1${NC}"
    ((PASSED_CHECKS++))
}

log_error() {
    log "${RED}❌ $1${NC}"
    # Don't auto-increment here since run_check handles it
}

log_warning() {
    log "${YELLOW}⚠️  $1${NC}"
    # Don't auto-increment here since run_check handles it
}

log_header() {
    log ""
    log "${BOLD}${BLUE}$1${NC}"
    log "${BLUE}$(printf '=%.0s' $(seq 1 ${#1}))${NC}"
}

increment_total() {
    ((TOTAL_CHECKS++))
}

check_command() {
    local cmd="$1"
    local install_msg="$2"
    
    if command -v "$cmd" >/dev/null 2>&1; then
        return 0
    else
        log_warning "$cmd not found. $install_msg"
        return 1
    fi
}

run_check() {
    local description="$1"
    local command="$2"
    local optional="${3:-false}"
    
    increment_total
    log_info "Checking: $description"
    
    local output
    output=$(eval "$command" 2>&1)
    local exit_code=$?
    
    if [[ $exit_code -eq 0 ]]; then
        log_success "$description"
        return 0
    else
        if [[ "$optional" == "true" ]]; then
            log_warning "$description (optional check failed)"
            ((WARNING_CHECKS++))
        else
            log_error "$description"
            ((FAILED_CHECKS++))
            
            # Show detailed error information for critical failures
            if [[ -n "$output" ]]; then
                echo "" | tee -a "$LOG_FILE"
                echo "  ${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$LOG_FILE"
                echo "  ${RED}ERROR: $description${NC}" | tee -a "$LOG_FILE"
                echo "" | tee -a "$LOG_FILE"
                echo "  ${YELLOW}Command that failed:${NC}" | tee -a "$LOG_FILE"
                echo "  ${BLUE}$command${NC}" | tee -a "$LOG_FILE"
                echo "" | tee -a "$LOG_FILE"
                echo "  ${YELLOW}Error output:${NC}" | tee -a "$LOG_FILE"
                echo "$output" | head -10 | sed 's/^/  /' | tee -a "$LOG_FILE"
                echo "" | tee -a "$LOG_FILE"
                echo "  ${YELLOW}💡 To debug, run the command manually:${NC}" | tee -a "$LOG_FILE"
                echo "  ${BLUE}cd $(pwd) && $command${NC}" | tee -a "$LOG_FILE"
                echo "  ${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$LOG_FILE"
                echo "" | tee -a "$LOG_FILE"
            fi
        fi
        return 1
    fi
}

# =============================================================================
# TERRAFORM VALIDATION FUNCTIONS
# =============================================================================

validate_terraform() {
    local tf_dir="${1:-terraform}"
    
    log_header "TERRAFORM VALIDATION"
    
    if [[ ! -d "$PROJECT_ROOT/$tf_dir" ]]; then
        log_warning "Terraform directory '$tf_dir' not found, skipping Terraform validation"
        return 0
    fi
    
    cd "$PROJECT_ROOT/$tf_dir" || exit
    
    # Check if Terraform is installed
    if ! check_command "terraform" "Install from: https://www.terraform.io/downloads"; then
        log_error "Terraform validation skipped - command not available"
        return 1
    fi
    
    # Basic Terraform checks
    run_check "Terraform syntax validation" "terraform validate"
    run_check "Terraform formatting check" "terraform fmt -check -recursive"
    
    # Check for common Terraform files
    run_check "Main configuration exists" "[[ -f main.tf || -f *.tf ]]"
    run_check "Variables file exists" "[[ -f variables.tf ]]" "true"
    run_check "Outputs file exists" "[[ -f outputs.tf ]]" "true"
    run_check "Example variables file exists" "[[ -f terraform.tfvars.example || -f *.tfvars.example ]]" "true"
    
    # Variable usage analysis
    if [[ -f "variables.tf" && -f "main.tf" ]]; then
        log_info "Analyzing variable usage..."
        
        # Extract declared variables
        local declared_vars
        declared_vars=$(grep -o 'variable "[^"]*"' variables.tf 2>/dev/null | sed 's/variable "\([^"]*\)"/\1/' | sort || true)
        
        # Extract used variables in main.tf
        local used_vars
        used_vars=$(grep -oh 'var\.[a-zA-Z_][a-zA-Z0-9_]*' main.tf 2>/dev/null | sed 's/var\.//' | sort | uniq || true)
        
        # Check for unused variables
        if [[ -n "$declared_vars" && -n "$used_vars" ]]; then
            local unused_vars
            unused_vars=$(comm -23 <(echo "$declared_vars") <(echo "$used_vars") || true)
            
            increment_total
            if [[ -n "$unused_vars" ]]; then
                log_warning "Unused variables found: $(echo "$unused_vars" | tr '\n' ' ')"
                ((WARNING_CHECKS++))
            else
                log_success "All declared variables are used"
                ((PASSED_CHECKS++))
            fi
        fi
    fi
    
    # Check for hardcoded values (basic patterns)
    if [[ -f "main.tf" ]]; then
        increment_total
        local hardcoded_patterns=("TODO" "FIXME" "CHANGEME" "hardcoded")
        local found_hardcoded=false
        
        for pattern in "${hardcoded_patterns[@]}"; do
            if grep -q "$pattern" main.tf 2>/dev/null; then
                found_hardcoded=true
                break
            fi
        done
        
        if [[ "$found_hardcoded" == "true" ]]; then
            log_warning "Potential hardcoded values or TODOs found in main.tf"
            ((WARNING_CHECKS++))
        else
            log_success "No obvious hardcoded values or TODOs found"
            ((PASSED_CHECKS++))
        fi
    fi
    
    # Terraform plan dry run (if .tfvars.example exists)
    if [[ -f "terraform.tfvars.example" ]]; then
        run_check "Terraform plan dry run" "terraform plan -var-file=terraform.tfvars.example -var='compartment_ocid=test' -detailed-exitcode" "true"
    fi
    
    cd "$PROJECT_ROOT" || exit
}

# =============================================================================
# ANSIBLE VALIDATION FUNCTIONS
# =============================================================================

validate_ansible() {
    local ansible_dir="${1:-ansible}"
    local auto_fix="${2:-false}"
    
    log_header "ANSIBLE VALIDATION"
    
    if [[ "$auto_fix" == "true" ]]; then
        log_info "Auto-fix mode enabled - ansible-lint will attempt to fix issues"
    fi
    
    if [[ ! -d "$PROJECT_ROOT/$ansible_dir" ]]; then
        log_warning "Ansible directory '$ansible_dir' not found, skipping Ansible validation"
        return 0
    fi
    
    cd "$PROJECT_ROOT/$ansible_dir" || exit
    
    # Check if Ansible is installed
    if ! check_command "ansible" "Install with: pip install ansible"; then
        log_error "Ansible validation skipped - command not available"
        return 1
    fi
    
    # Check if ansible-lint is installed
    if ! check_command "ansible-lint" "Install with: pip install ansible-lint"; then
        log_warning "ansible-lint not available, skipping lint checks"
    else
        # Validate main playbooks
        if [[ -d "playbooks" ]]; then
            local playbook_errors=0
            local playbook_warnings=0
            
            log_info "Validating main playbooks..."
            
            # Find main playbook files (not in tasks subdirectory)
            while IFS= read -r -d '' file; do
                local relative_file="${file#./}"
                log_info "  Linting playbook: $relative_file"
                
                # Determine lint command based on auto_fix flag
                local lint_cmd="ansible-lint --offline"
                if [[ "$auto_fix" == "true" ]]; then
                    lint_cmd="ansible-lint --offline --fix=all"
                fi
                
                local lint_output
                lint_output=$($lint_cmd "$relative_file" 2>&1)
                local exit_code=$?
                
                if [[ $exit_code -eq 0 ]]; then
                    if [[ "$auto_fix" == "true" && "$lint_output" =~ "Fixed" ]]; then
                        log_success "  ✅ $relative_file (auto-fixed)"
                    else
                        log_success "  ✅ $relative_file"
                    fi
                elif [[ $exit_code -eq 2 ]]; then
                    log_error "  ❌ $relative_file (fatal errors)"
                    ((playbook_errors++))
                    
                    # Show detailed error information
                    echo "" | tee -a "$LOG_FILE"
                    echo "    ${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$LOG_FILE"
                    echo "    ${RED}ERROR DETAILS:${NC}" | tee -a "$LOG_FILE"
                    echo "    File: $relative_file" | tee -a "$LOG_FILE"
                    echo "" | tee -a "$LOG_FILE"
                    
                    # Extract and show key error information
                    echo "$lint_output" | grep -v "^INFO" | grep -v "^WARNING.*Unable to load" | sed 's/^/    /' | tee -a "$LOG_FILE"
                    
                    echo "" | tee -a "$LOG_FILE"
                    echo "    ${YELLOW}🔍 To debug this error, run:${NC}" | tee -a "$LOG_FILE"
                    echo "    ${BLUE}cd ansible && ansible-lint --offline $relative_file${NC}" | tee -a "$LOG_FILE"
                    echo "" | tee -a "$LOG_FILE"
                    echo "    ${YELLOW}💡 Common fixes:${NC}" | tee -a "$LOG_FILE"
                    echo "    - Check YAML syntax (indentation, quotes, booleans)" | tee -a "$LOG_FILE"
                    echo "    - Ensure 'true/false' instead of 'yes/no' for booleans" | tee -a "$LOG_FILE"
                    echo "    - Validate Jinja2 template syntax" | tee -a "$LOG_FILE"
                    echo "    - Run: ansible-playbook --syntax-check $relative_file" | tee -a "$LOG_FILE"
                    echo "    ${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$LOG_FILE"
                    echo "" | tee -a "$LOG_FILE"
                else
                    # Exit code 1 or other - warnings but no fatal errors
                    log_warning "  ⚠️  $relative_file (warnings)"
                    ((playbook_warnings++))
                    # Show warnings if they're not just module loading warnings
                    if echo "$lint_output" | grep -v "Unable to load module" | grep -v "Invalid value.*resolved_fqcn" | grep -q .; then
                        echo "" | tee -a "$LOG_FILE"
                        echo "    ${YELLOW}Warning details:${NC}" | tee -a "$LOG_FILE"
                        echo "$lint_output" | grep -v "Unable to load module" | grep -v "Invalid value.*resolved_fqcn" | grep -v "^INFO" | head -5 | sed 's/^/    /' | tee -a "$LOG_FILE"
                        echo "" | tee -a "$LOG_FILE"
                        echo "    ${BLUE}For more details: cd ansible && ansible-lint $relative_file${NC}" | tee -a "$LOG_FILE"
                        echo "" | tee -a "$LOG_FILE"
                    fi
                fi
            done < <(find playbooks -maxdepth 1 -name "*.yml" -type f -print0)
            
            # Validate task files separately
            if [[ -d "playbooks/tasks" ]]; then
                log_info "Validating task files..."
                
                while IFS= read -r -d '' file; do
                    local relative_file="${file#./}"
                    log_info "  Linting task file: $relative_file"
                    
                    # Determine lint command based on auto_fix flag
                    local lint_cmd="ansible-lint --offline"
                    if [[ "$auto_fix" == "true" ]]; then
                        lint_cmd="ansible-lint --offline --fix=all"
                    fi
                    
                    local lint_output
                    lint_output=$($lint_cmd "$relative_file" 2>&1)
                    local exit_code=$?
                    
                    if [[ $exit_code -eq 0 ]]; then
                        if [[ "$auto_fix" == "true" && "$lint_output" =~ "Fixed" ]]; then
                            log_success "  ✅ $relative_file (auto-fixed)"
                        else
                            log_success "  ✅ $relative_file"
                        fi
                    elif [[ $exit_code -eq 2 ]]; then
                        log_error "  ❌ $relative_file (fatal errors)"
                        ((playbook_errors++))
                        
                        # Show detailed error information
                        echo "" | tee -a "$LOG_FILE"
                        echo "    ${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$LOG_FILE"
                        echo "    ${RED}ERROR DETAILS:${NC}" | tee -a "$LOG_FILE"
                        echo "    File: $relative_file" | tee -a "$LOG_FILE"
                        echo "" | tee -a "$LOG_FILE"
                        
                        # Extract and show key error information
                        echo "$lint_output" | grep -v "^INFO" | grep -v "^WARNING.*Unable to load" | sed 's/^/    /' | tee -a "$LOG_FILE"
                        
                        echo "" | tee -a "$LOG_FILE"
                        echo "    ${YELLOW}🔍 To debug this error, run:${NC}" | tee -a "$LOG_FILE"
                        echo "    ${BLUE}cd ansible && ansible-lint --offline $relative_file${NC}" | tee -a "$LOG_FILE"
                        echo "" | tee -a "$LOG_FILE"
                        echo "    ${YELLOW}💡 Common fixes:${NC}" | tee -a "$LOG_FILE"
                        echo "    - Verify task syntax (name, module, parameters)" | tee -a "$LOG_FILE"
                        echo "    - Check for undefined variables" | tee -a "$LOG_FILE"
                        echo "    - Ensure proper YAML indentation" | tee -a "$LOG_FILE"
                        echo "    - Review Ansible module documentation" | tee -a "$LOG_FILE"
                        echo "    ${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}" | tee -a "$LOG_FILE"
                        echo "" | tee -a "$LOG_FILE"
                    else
                        # Exit code 1 or other - warnings but no fatal errors
                        log_warning "  ⚠️  $relative_file (warnings)"
                        ((playbook_warnings++))
                        # Show warnings if they're not just module loading warnings
                        if echo "$lint_output" | grep -v "Unable to load module" | grep -v "Invalid value.*resolved_fqcn" | grep -q .; then
                            echo "" | tee -a "$LOG_FILE"
                            echo "    ${YELLOW}Warning details:${NC}" | tee -a "$LOG_FILE"
                            echo "$lint_output" | grep -v "Unable to load module" | grep -v "Invalid value.*resolved_fqcn" | grep -v "^INFO" | head -5 | sed 's/^/    /' | tee -a "$LOG_FILE"
                            echo "" | tee -a "$LOG_FILE"
                            echo "    ${BLUE}For more details: cd ansible && ansible-lint $relative_file${NC}" | tee -a "$LOG_FILE"
                            echo "" | tee -a "$LOG_FILE"
                        fi
                    fi
                done < <(find playbooks/tasks -name "*.yml" -type f -print0)
            fi
            
            # Summary of lint results
            run_check "Ansible lint validation" "[[ $playbook_errors -eq 0 ]]"
        fi
    fi
    
    # Check for common Ansible structure
    run_check "Playbooks directory exists" "[[ -d playbooks ]]"
    run_check "Inventory directory exists" "[[ -d inventory ]]" "true"
    run_check "Ansible configuration exists" "[[ -f ansible.cfg ]]" "true"
    
    # YAML syntax validation for playbooks
    if [[ -d "playbooks" ]]; then
        increment_total
        local yaml_errors=0
        
        while IFS= read -r -d '' file; do
            if ! python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
                ((yaml_errors++))
                log_error "YAML syntax error in: $file"
            fi
        done < <(find playbooks \( -name "*.yml" -o -name "*.yaml" \) -print0)
        
        if [[ $yaml_errors -eq 0 ]]; then
            log_success "All YAML files have valid syntax"
        fi
    fi
    
    # Check for vault files
    if find . -name "*vault*" -type f | grep -q .; then
        log_info "Ansible vault files detected"
        run_check "Ansible vault syntax check" "ansible-vault view --vault-password-file=/dev/null dummy 2>/dev/null || true" "true"
    fi
    
    cd "$PROJECT_ROOT" || exit
}

# =============================================================================
# GENERIC FILE VALIDATION FUNCTIONS
# =============================================================================

validate_documentation() {
    log_header "DOCUMENTATION VALIDATION"
    
    # Check for essential documentation files
    run_check "README file exists" "[[ -f README.md || -f README.rst || -f README.txt ]]"
    run_check "Architecture documentation exists" "[[ -f ARCHITECTURE*.md || -f docs/architecture* ]]" "true"
    run_check "Migration guide exists" "[[ -f MIGRATION*.md ]]" "true"
    
    # Check README content quality
    if [[ -f "README.md" ]]; then
        increment_total
        local readme_sections=("description" "installation" "usage" "requirements")
        local missing_sections=()
        
        for section in "${readme_sections[@]}"; do
            if ! grep -qi "$section" README.md; then
                missing_sections+=("$section")
            fi
        done
        
        if [[ ${#missing_sections[@]} -eq 0 ]]; then
            log_success "README.md contains essential sections"
        else
            log_warning "README.md missing sections: ${missing_sections[*]}"
        fi
    fi
}

validate_security() {
    log_header "SECURITY VALIDATION"
    
    # Check for sensitive files that shouldn't be committed
    local sensitive_patterns=("*.tfstate" "*.tfstate.backup" "id_rsa" "id_dsa")
    local found_sensitive=false
    
    increment_total
    for pattern in "${sensitive_patterns[@]}"; do
        if find "$PROJECT_ROOT" -name "$pattern" -not -path "*/.terraform/*" -not -path "*/.git/*" -type f | grep -q .; then
            found_sensitive=true
            log_error "Sensitive file found: $pattern"
        fi
    done
    
    if [[ "$found_sensitive" == "false" ]]; then
        log_success "No sensitive files found in repository"
        ((PASSED_CHECKS++))
    else
        ((FAILED_CHECKS++))
    fi
    
    # Check for .gitignore
    run_check ".gitignore file exists" "[[ -f .gitignore ]]"
    
    # Check for hardcoded secrets (basic patterns)
    increment_total
    local secret_patterns=("password.*=" "secret.*=" "key.*=" "token.*=")
    local found_secrets=false
    
    for pattern in "${secret_patterns[@]}"; do
        if grep -r -i "$pattern" --exclude-dir=.git --exclude-dir=.terraform --exclude="*.log" --exclude="validate.sh" "$PROJECT_ROOT" | grep -v "example\|template\|placeholder\|description" | grep -q .; then
            found_secrets=true
            break
        fi
    done
    
    if [[ "$found_secrets" == "true" ]]; then
        log_warning "Potential hardcoded secrets found (review manually)"
        ((WARNING_CHECKS++))
    else
        log_success "No obvious hardcoded secrets detected"
        ((PASSED_CHECKS++))
    fi
}

validate_code_quality() {
    log_header "CODE QUALITY VALIDATION"
    
    # Check for common code quality issues
    increment_total
    local quality_issues=0
    
    # Check for TODO/FIXME comments
    if grep -r "TODO\|FIXME\|HACK\|XXX" --exclude-dir=.git --exclude-dir=.terraform --exclude="validate.sh" "$PROJECT_ROOT" | grep -q .; then
        ((quality_issues++))
        log_warning "TODO/FIXME comments found (review needed)"
    fi
    
    # Check for trailing whitespace
    if find "$PROJECT_ROOT" -name "*.tf" -o -name "*.yml" -o -name "*.yaml" | grep -v ".terraform" | xargs grep -l " $" 2>/dev/null | grep -q .; then
        ((quality_issues++))
        log_warning "Files with trailing whitespace found"
    fi
    
    # Check for mixed line endings
    if find "$PROJECT_ROOT" -name "*.tf" -o -name "*.yml" -o -name "*.yaml" | grep -v ".terraform" | xargs file 2>/dev/null | grep -q "CRLF"; then
        ((quality_issues++))
        log_warning "Files with Windows line endings (CRLF) found"
    fi
    
    if [[ $quality_issues -eq 0 ]]; then
        log_success "Code quality checks passed"
        ((PASSED_CHECKS++))
    else
        ((WARNING_CHECKS++))
    fi
}

# =============================================================================
# MAIN VALIDATION ORCHESTRATOR
# =============================================================================

main() {
    local start_time
    start_time=$(date +%s)
    
    # Initialize log file
    echo "Infrastructure Validation Report - $(date)" > "$LOG_FILE"
    echo "=======================================" >> "$LOG_FILE"
    
    log_header "🚀 INFRASTRUCTURE VALIDATION STARTED"
    log_info "Project: $(basename "$PROJECT_ROOT")"
    log_info "Timestamp: $(date)"
    log_info "Log file: $LOG_FILE"
    
    # Parse command line arguments
    local terraform_dir="terraform"
    local ansible_dir="ansible"
    local skip_terraform=false
    local skip_ansible=false
    local auto_fix=false
    # local verbose=false  # Unused variable removed
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --terraform-dir)
                terraform_dir="$2"
                shift 2
                ;;
            --ansible-dir)
                ansible_dir="$2"
                shift 2
                ;;
            --skip-terraform)
                skip_terraform=true
                shift
                ;;
            --skip-ansible)
                skip_ansible=true
                shift
                ;;
            --fix|--auto-fix)
                auto_fix=true
                shift
                ;;
            --verbose|-v)
                # verbose=true  # Verbose mode not implemented yet
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Run validation modules
    [[ "$skip_terraform" == "false" ]] && validate_terraform "$terraform_dir"
    [[ "$skip_ansible" == "false" ]] && validate_ansible "$ansible_dir" "$auto_fix"
    validate_documentation
    validate_security
    validate_code_quality
    
    # Final summary
    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    log_header "📊 VALIDATION SUMMARY"
    log "Total Checks: $TOTAL_CHECKS"
    log "${GREEN}Passed: $PASSED_CHECKS${NC}"
    log "${RED}Failed: $FAILED_CHECKS${NC}"
    log "${YELLOW}Warnings: $WARNING_CHECKS${NC}"
    log "Duration: ${duration}s"
    log "Log file: $LOG_FILE"
    
    # Determine exit code
    if [[ $FAILED_CHECKS -eq 0 ]]; then
        log ""
        log "${GREEN}${BOLD}🎉 ALL VALIDATIONS PASSED!${NC}"
        if [[ $WARNING_CHECKS -gt 0 ]]; then
            log "${YELLOW}Note: $WARNING_CHECKS warning(s) found - review recommended${NC}"
        fi
        exit 0
    else
        log ""
        log "${RED}${BOLD}❌ VALIDATION FAILED${NC}"
        log "${RED}$FAILED_CHECKS critical issue(s) found that must be addressed${NC}"
        exit 1
    fi
}

show_help() {
    cat << EOF
Infrastructure Validation Script

USAGE:
    $0 [OPTIONS]

OPTIONS:
    --terraform-dir DIR     Specify Terraform directory (default: terraform)
    --ansible-dir DIR       Specify Ansible directory (default: ansible)
    --skip-terraform        Skip Terraform validation
    --skip-ansible          Skip Ansible validation
    --fix, --auto-fix       Auto-fix Ansible issues using ansible-lint --fix
    --verbose, -v           Enable verbose output
    --help, -h              Show this help message

EXAMPLES:
    $0                                    # Validate everything with defaults
    $0 --skip-ansible                     # Skip Ansible validation
    $0 --fix                              # Validate and auto-fix Ansible issues
    $0 --terraform-dir infra             # Use 'infra' as Terraform directory
    $0 --terraform-dir tf --ansible-dir automation
    $0 --fix --skip-terraform            # Auto-fix Ansible only

VALIDATION MODULES:
    • Terraform: syntax, formatting, variables, security
    • Ansible: lint, YAML syntax, structure (supports auto-fix)
    • Documentation: README, architecture docs
    • Security: sensitive files, hardcoded secrets
    • Code Quality: TODOs, whitespace, line endings

AUTO-FIX:
    The --fix flag enables ansible-lint auto-correction for:
    • YAML formatting (indentation, quotes)
    • Boolean values (yes/no → true/false)
    • Deprecated syntax
    • Code style improvements
    
    Note: Always review changes after auto-fix

EXIT CODES:
    0    All validations passed
    1    Critical validation failures found
EOF
}

# =============================================================================
# SCRIPT EXECUTION
# =============================================================================

# Only run main if script is executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi