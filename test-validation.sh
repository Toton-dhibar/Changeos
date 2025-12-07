#!/bin/bash
#
# Validation and Testing Script for distro-migrator.sh
# This script validates the distro-migrator.sh without running destructive operations
#

set -eo pipefail

readonly SCRIPT="distro-migrator.sh"
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_RED='\033[0;31m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_RESET='\033[0m'

TESTS_PASSED=0
TESTS_FAILED=0

# Helper functions
pass() {
    echo -e "${COLOR_GREEN}✓${COLOR_RESET} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

fail() {
    echo -e "${COLOR_RED}✗${COLOR_RESET} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

warn() {
    echo -e "${COLOR_YELLOW}⚠${COLOR_RESET} $1"
}

section() {
    echo ""
    echo "=== $1 ==="
}

# Test functions
test_file_exists() {
    section "File Existence Tests"
    
    if [[ -f "$SCRIPT" ]]; then
        pass "Script file exists"
    else
        fail "Script file not found"
        exit 1
    fi
    
    if [[ -x "$SCRIPT" ]]; then
        pass "Script is executable"
    else
        fail "Script is not executable"
    fi
}

test_syntax() {
    section "Syntax Validation"
    
    if bash -n "$SCRIPT" 2>/dev/null; then
        pass "Bash syntax is valid"
    else
        fail "Bash syntax errors detected"
        bash -n "$SCRIPT"
    fi
}

test_shebang() {
    section "Shebang Test"
    
    local shebang=$(head -n 1 "$SCRIPT")
    if [[ "$shebang" == "#!/bin/bash" ]]; then
        pass "Correct shebang: $shebang"
    else
        fail "Incorrect shebang: $shebang"
    fi
}

test_required_functions() {
    section "Required Functions Test"
    
    local required_functions=(
        "main"
        "log_init"
        "log_info"
        "log_success"
        "log_warning"
        "log_error"
        "log_fatal"
        "show_banner"
        "check_root"
        "check_not_container"
        "check_disk_space"
        "check_network"
        "check_dependencies"
        "detect_cloud_provider"
        "detect_network_config"
        "create_backup"
        "show_distro_menu"
        "show_version_menu"
        "confirm_migration"
        "detect_root_device"
        "install_ubuntu_debian"
        "install_rhel_based"
        "install_arch"
        "prepare_disk"
        "restore_network_config"
        "restore_network_ubuntu_debian"
        "restore_network_rhel"
        "restore_network_arch"
        "restore_ssh"
        "install_bootloader"
        "post_install_config"
        "perform_migration"
        "verify_migration"
        "attempt_recovery"
        "error_handler"
    )
    
    local missing=0
    for func in "${required_functions[@]}"; do
        if grep -q "^${func}()" "$SCRIPT"; then
            pass "Function: $func"
        else
            fail "Function missing: $func"
            missing=$((missing + 1))
        fi
    done
    
    if [[ $missing -eq 0 ]]; then
        pass "All required functions present"
    fi
}

test_required_variables() {
    section "Required Variables Test"
    
    local required_vars=(
        "SCRIPT_VERSION"
        "SCRIPT_NAME"
        "LOG_FILE"
        "BACKUP_DIR"
        "MIN_DISK_SPACE_GB"
        "CONFIRMATION_PHRASE"
        "COLOR_RED"
        "COLOR_GREEN"
        "COLOR_YELLOW"
        "COLOR_BLUE"
        "COLOR_CYAN"
        "COLOR_WHITE"
        "COLOR_RESET"
    )
    
    for var in "${required_vars[@]}"; do
        if grep -q "readonly ${var}=" "$SCRIPT" || grep -q "^${var}=" "$SCRIPT"; then
            pass "Variable: $var"
        else
            fail "Variable missing: $var"
        fi
    done
}

test_distribution_support() {
    section "Distribution Support Test"
    
    local distros=("ubuntu" "debian" "almalinux" "rocky" "centos" "fedora" "arch")
    
    for distro in "${distros[@]}"; do
        if grep -q "$distro" "$SCRIPT"; then
            pass "Distribution supported: $distro"
        else
            fail "Distribution not found: $distro"
        fi
    done
}

test_cloud_provider_support() {
    section "Cloud Provider Support Test"
    
    local providers=("aws" "azure" "gcp" "oracle")
    
    for provider in "${providers[@]}"; do
        if grep -qi "$provider" "$SCRIPT"; then
            pass "Cloud provider supported: $provider"
        else
            fail "Cloud provider not found: $provider"
        fi
    done
}

test_error_handling() {
    section "Error Handling Test"
    
    if grep -q "set -euo pipefail" "$SCRIPT"; then
        pass "Strict error handling enabled"
    else
        fail "Strict error handling not found"
    fi
    
    if grep -q "trap.*error_handler" "$SCRIPT"; then
        pass "Error trap configured"
    else
        fail "Error trap not configured"
    fi
}

test_security_features() {
    section "Security Features Test"
    
    if grep -q "check_root" "$SCRIPT" && grep -q "EUID.*-ne.*0" "$SCRIPT"; then
        pass "Root check implemented"
    else
        fail "Root check not implemented"
    fi
    
    if grep -q "check_not_container" "$SCRIPT"; then
        pass "Container detection implemented"
    else
        fail "Container detection not implemented"
    fi
    
    if grep -q "DESTROY-AND-REPLACE" "$SCRIPT"; then
        pass "Confirmation phrase required"
    else
        fail "No confirmation phrase"
    fi
    
    if grep -q "openssl rand" "$SCRIPT"; then
        pass "Secure password generation"
    else
        warn "No secure password generation found"
    fi
}

test_backup_functionality() {
    section "Backup Functionality Test"
    
    if grep -q "create_backup" "$SCRIPT"; then
        pass "Backup function exists"
    else
        fail "Backup function missing"
    fi
    
    if grep -q "BACKUP_DIR" "$SCRIPT"; then
        pass "Backup directory defined"
    else
        fail "Backup directory not defined"
    fi
    
    # Check if backup includes critical files
    local critical_items=("ssh" "network" "hostname" "hosts" "resolv.conf" "fstab")
    for item in "${critical_items[@]}"; do
        if grep -q "$item" "$SCRIPT"; then
            pass "Backs up: $item"
        else
            warn "May not backup: $item"
        fi
    done
}

test_network_preservation() {
    section "Network Preservation Test"
    
    if grep -q "detect_network_config" "$SCRIPT"; then
        pass "Network detection implemented"
    else
        fail "Network detection missing"
    fi
    
    if grep -q "restore_network_config" "$SCRIPT"; then
        pass "Network restoration implemented"
    else
        fail "Network restoration missing"
    fi
    
    # Check for netplan, network-scripts, and NetworkManager support
    if grep -q "netplan" "$SCRIPT"; then
        pass "Netplan support (Ubuntu/Debian)"
    else
        warn "No netplan support found"
    fi
    
    if grep -q "network-scripts" "$SCRIPT"; then
        pass "network-scripts support (RHEL)"
    else
        warn "No network-scripts support found"
    fi
    
    if grep -q "NetworkManager" "$SCRIPT"; then
        pass "NetworkManager support (Arch)"
    else
        warn "No NetworkManager support found"
    fi
}

test_ssh_preservation() {
    section "SSH Preservation Test"
    
    if grep -q "restore_ssh" "$SCRIPT"; then
        pass "SSH restoration implemented"
    else
        fail "SSH restoration missing"
    fi
    
    if grep -q "authorized_keys" "$SCRIPT"; then
        pass "Preserves authorized_keys"
    else
        warn "May not preserve authorized_keys"
    fi
}

test_bootloader() {
    section "Bootloader Test"
    
    if grep -q "install_bootloader" "$SCRIPT"; then
        pass "Bootloader installation implemented"
    else
        fail "Bootloader installation missing"
    fi
    
    if grep -q "grub" "$SCRIPT"; then
        pass "GRUB support"
    else
        fail "No GRUB support found"
    fi
}

test_logging() {
    section "Logging Test"
    
    if grep -q "LOG_FILE" "$SCRIPT"; then
        pass "Log file defined"
    else
        fail "Log file not defined"
    fi
    
    local log_levels=("log_info" "log_success" "log_warning" "log_error" "log_fatal")
    for level in "${log_levels[@]}"; do
        if grep -q "$level" "$SCRIPT"; then
            pass "Log level: $level"
        else
            fail "Log level missing: $level"
        fi
    done
}

test_interactive_menu() {
    section "Interactive Menu Test"
    
    if grep -q "show_distro_menu" "$SCRIPT"; then
        pass "Distribution menu implemented"
    else
        fail "Distribution menu missing"
    fi
    
    if grep -q "show_version_menu" "$SCRIPT"; then
        pass "Version menu implemented"
    else
        fail "Version menu missing"
    fi
}

test_code_quality() {
    section "Code Quality Test"
    
    local line_count=$(wc -l < "$SCRIPT")
    if [[ $line_count -gt 500 ]]; then
        pass "Substantial implementation ($line_count lines)"
    else
        fail "Implementation too small ($line_count lines)"
    fi
    
    if command -v shellcheck &>/dev/null; then
        local warnings=$(shellcheck -S warning "$SCRIPT" 2>&1 | grep -c "^In" || true)
        if [[ $warnings -lt 20 ]]; then
            pass "ShellCheck warnings: $warnings (acceptable)"
        else
            warn "ShellCheck warnings: $warnings (many warnings)"
        fi
    else
        warn "ShellCheck not available, skipping"
    fi
}

# Main execution
main() {
    echo "╔══════════════════════════════════════════════════════════════╗"
    echo "║                                                              ║"
    echo "║     distro-migrator.sh Validation Test Suite                ║"
    echo "║                                                              ║"
    echo "╚══════════════════════════════════════════════════════════════╝"
    
    test_file_exists
    test_syntax
    test_shebang
    test_required_functions
    test_required_variables
    test_distribution_support
    test_cloud_provider_support
    test_error_handling
    test_security_features
    test_backup_functionality
    test_network_preservation
    test_ssh_preservation
    test_bootloader
    test_logging
    test_interactive_menu
    test_code_quality
    
    section "Test Summary"
    echo ""
    echo "Tests Passed: ${COLOR_GREEN}$TESTS_PASSED${COLOR_RESET}"
    echo "Tests Failed: ${COLOR_RED}$TESTS_FAILED${COLOR_RESET}"
    echo ""
    
    if [[ $TESTS_FAILED -eq 0 ]]; then
        echo -e "${COLOR_GREEN}╔══════════════════════════════════════════╗${COLOR_RESET}"
        echo -e "${COLOR_GREEN}║     ALL TESTS PASSED ✓                   ║${COLOR_RESET}"
        echo -e "${COLOR_GREEN}╚══════════════════════════════════════════╝${COLOR_RESET}"
        return 0
    else
        echo -e "${COLOR_RED}╔══════════════════════════════════════════╗${COLOR_RESET}"
        echo -e "${COLOR_RED}║     SOME TESTS FAILED ✗                  ║${COLOR_RESET}"
        echo -e "${COLOR_RED}╚══════════════════════════════════════════╝${COLOR_RESET}"
        return 1
    fi
}

main "$@"
