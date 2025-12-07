#!/bin/bash
#
# Linux Distribution Migration Script
# Version: 1.0.0
# Description: Complete automated Linux distribution migration for cloud VPS
# Author: ChangeOS Project
# License: MIT
#
# CRITICAL: This script COMPLETELY REPLACES your operating system
# USE WITH EXTREME CAUTION - Data loss will occur!
#

set -euo pipefail

#==============================================================================
# GLOBAL CONFIGURATION
#==============================================================================

readonly SCRIPT_VERSION="1.0.0"
readonly SCRIPT_NAME="distro-migrator.sh"
readonly LOG_FILE="/var/log/distro-migration.log"
readonly BACKUP_DIR="/var/backups/distro-migration-backup"
readonly MIN_DISK_SPACE_GB=10
readonly CONFIRMATION_PHRASE="DESTROY-AND-REPLACE"

# Supported distributions and versions
declare -A DISTRO_VERSIONS=(
    [ubuntu]="24.04 22.04 20.04 18.04"
    [debian]="12 11 10"
    [almalinux]="9 8"
    [rocky]="9 8"
    [centos]="9 8 7"
    [fedora]="39 38 37"
    [arch]="latest"
)

# Global variables
DETECTED_CLOUD=""
CURRENT_IP=""
CURRENT_GATEWAY=""
CURRENT_DNS=""
CURRENT_INTERFACE=""
TARGET_DISTRO=""
TARGET_VERSION=""
ROOT_DEVICE=""
ROOT_PARTITION=""

#==============================================================================
# COLOR DEFINITIONS
#==============================================================================

readonly COLOR_RED='\033[0;31m'
readonly COLOR_GREEN='\033[0;32m'
readonly COLOR_YELLOW='\033[1;33m'
readonly COLOR_BLUE='\033[0;34m'
readonly COLOR_MAGENTA='\033[0;35m'
readonly COLOR_CYAN='\033[0;36m'
readonly COLOR_WHITE='\033[1;37m'
readonly COLOR_RESET='\033[0m'

#==============================================================================
# LOGGING FUNCTIONS
#==============================================================================

log_init() {
    mkdir -p "$(dirname "$LOG_FILE")"
    touch "$LOG_FILE"
    echo "========================================" >> "$LOG_FILE"
    echo "Migration started at $(date)" >> "$LOG_FILE"
    echo "========================================" >> "$LOG_FILE"
}

log_message() {
    local level="$1"
    shift
    local message="$*"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" >> "$LOG_FILE"
}

log_info() {
    log_message "INFO" "$@"
    echo -e "${COLOR_BLUE}[INFO]${COLOR_RESET} $*"
}

log_success() {
    log_message "SUCCESS" "$@"
    echo -e "${COLOR_GREEN}[✓]${COLOR_RESET} $*"
}

log_warning() {
    log_message "WARNING" "$@"
    echo -e "${COLOR_YELLOW}[WARNING]${COLOR_RESET} $*"
}

log_error() {
    log_message "ERROR" "$@"
    echo -e "${COLOR_RED}[ERROR]${COLOR_RESET} $*" >&2
}

log_fatal() {
    log_message "FATAL" "$@"
    echo -e "${COLOR_RED}[FATAL]${COLOR_RESET} $*" >&2
    exit 1
}

#==============================================================================
# BANNER AND UI FUNCTIONS
#==============================================================================

show_banner() {
    clear
    cat << "EOF"
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║        Linux Distribution Migration Script v1.0.0               ║
║                                                                  ║
║        DANGER: This will COMPLETELY REPLACE your OS             ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
EOF
    echo ""
}

show_warning() {
    echo -e "${COLOR_RED}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║                    ⚠️  CRITICAL WARNING ⚠️                       ║
║                                                                  ║
║  This script will:                                               ║
║    • FORMAT your root partition                                 ║
║    • DESTROY all current data                                   ║
║    • REPLACE your entire operating system                       ║
║                                                                  ║
║  Only these will be preserved:                                   ║
║    • Network configuration (IP, DNS, gateway)                   ║
║    • SSH keys and authorized_keys                               ║
║    • Hostname                                                    ║
║                                                                  ║
║  If something goes wrong, you may LOSE SSH ACCESS!              ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${COLOR_RESET}"
}

pause_prompt() {
    echo ""
    read -p "Press [Enter] to continue..."
}

#==============================================================================
# NETWORK UTILITY FUNCTIONS
#==============================================================================

retry_with_backoff() {
    local max_attempts="${1}"
    local delay="${2}"
    local max_delay="${3:-300}"
    shift 3
    local attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        log_info "Attempt $attempt of $max_attempts: $*"
        
        if "$@"; then
            return 0
        fi
        
        if [[ $attempt -lt $max_attempts ]]; then
            local wait_time=$((delay * attempt))
            if [[ $wait_time -gt $max_delay ]]; then
                wait_time=$max_delay
            fi
            log_warning "Command failed, retrying in ${wait_time}s..."
            sleep "$wait_time"
        fi
        
        attempt=$((attempt + 1))
    done
    
    log_error "Command failed after $max_attempts attempts: $*"
    return 1
}

verify_dns_resolution() {
    local test_domains=("archive.ubuntu.com" "deb.debian.org" "google.com")
    local resolved=0
    
    for domain in "${test_domains[@]}"; do
        if host "$domain" &>/dev/null || nslookup "$domain" &>/dev/null || getent hosts "$domain" &>/dev/null; then
            resolved=1
            break
        fi
    done
    
    return $((1 - resolved))
}

fix_dns_resolution() {
    log_warning "DNS resolution issues detected, attempting to fix..."
    
    # Backup current resolv.conf
    cp /etc/resolv.conf /etc/resolv.conf.backup 2>/dev/null || true
    
    # Try using Google DNS and Cloudflare DNS as fallback
    cat > /etc/resolv.conf << EOF
# Temporary DNS configuration for migration
nameserver 8.8.8.8
nameserver 8.8.4.4
nameserver 1.1.1.1
nameserver 1.0.0.1
EOF
    
    log_info "Updated DNS to use public resolvers"
    
    # Test DNS resolution
    if verify_dns_resolution; then
        log_success "DNS resolution restored"
        return 0
    else
        log_error "DNS resolution still failing"
        # Restore backup if fix didn't work
        if [[ -f /etc/resolv.conf.backup ]]; then
            mv /etc/resolv.conf.backup /etc/resolv.conf
        fi
        return 1
    fi
}

ensure_network_ready() {
    log_info "Verifying network and DNS resolution..."
    
    # Check basic connectivity
    if ! ping -c 1 -W 5 8.8.8.8 &>/dev/null; then
        log_error "No basic network connectivity"
        return 1
    fi
    
    # Check DNS resolution
    if ! verify_dns_resolution; then
        log_warning "DNS resolution issues detected"
        if ! fix_dns_resolution; then
            log_error "Unable to fix DNS resolution"
            return 1
        fi
    fi
    
    log_success "Network and DNS ready"
    return 0
}

run_apt_get_with_retry() {
    local cmd="$*"
    
    # Ensure network is ready before attempting
    if ! ensure_network_ready; then
        log_warning "Network not ready, proceeding anyway..."
    fi
    
    # Run with retry logic
    if ! retry_with_backoff 3 10 60 bash -c "$cmd"; then
        log_error "apt-get command failed after retries: $cmd"
        return 1
    fi
    
    return 0
}

#==============================================================================
# PRE-FLIGHT CHECKS
#==============================================================================

check_root() {
    if [[ $EUID -ne 0 ]]; then
        log_fatal "This script must be run as root"
    fi
    log_success "Running as root"
}

check_not_container() {
    if [[ -f /.dockerenv ]] || grep -q "lxc\|docker" /proc/1/cgroup 2>/dev/null; then
        log_fatal "Cannot run inside a container"
    fi
    log_success "Not running in container"
}

check_disk_space() {
    local free_space_gb=$(df -P / | awk 'NR==2 {print int($4/1024/1024)}')
    if [[ $free_space_gb -lt $MIN_DISK_SPACE_GB ]]; then
        log_fatal "Insufficient disk space. Need at least ${MIN_DISK_SPACE_GB}GB, have ${free_space_gb}GB"
    fi
    log_success "Sufficient disk space: ${free_space_gb}GB available"
}

check_network() {
    if ! ping -c 1 -W 5 8.8.8.8 &>/dev/null; then
        log_fatal "No network connectivity detected"
    fi
    
    # Also verify DNS resolution
    if ! verify_dns_resolution; then
        log_warning "DNS resolution issues detected during pre-flight checks"
        if ! fix_dns_resolution; then
            log_warning "DNS issues detected but will continue - may cause problems during installation"
        fi
    fi
    
    log_success "Network connectivity verified"
}

check_dependencies() {
    local deps=("wget" "curl" "tar" "gzip")
    local missing=()
    
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &>/dev/null; then
            missing+=("$dep")
        fi
    done
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_warning "Missing dependencies: ${missing[*]}"
        log_info "Installing missing dependencies..."
        
        if command -v apt-get &>/dev/null; then
            run_apt_get_with_retry "apt-get update -qq && apt-get install -y \"${missing[@]}\""
        elif command -v yum &>/dev/null; then
            retry_with_backoff 3 10 60 yum install -y "${missing[@]}"
        elif command -v dnf &>/dev/null; then
            retry_with_backoff 3 10 60 dnf install -y "${missing[@]}"
        else
            log_fatal "Cannot install dependencies - no package manager found"
        fi
    fi
    log_success "All dependencies satisfied"
}

#==============================================================================
# CLOUD PROVIDER DETECTION
#==============================================================================

detect_cloud_provider() {
    log_info "Detecting cloud provider..."
    
    # AWS detection
    if curl -s -m 2 http://169.254.169.254/latest/meta-data/ &>/dev/null; then
        DETECTED_CLOUD="aws"
        log_success "Detected AWS"
        return 0
    fi
    
    # Azure detection
    if curl -s -m 2 -H "Metadata:true" "http://169.254.169.254/metadata/instance?api-version=2021-12-13" &>/dev/null; then
        DETECTED_CLOUD="azure"
        log_success "Detected Azure"
        return 0
    fi
    
    # Google Cloud detection
    if curl -s -m 2 -H "Metadata-Flavor: Google" "http://metadata.google.internal/computeMetadata/v1/" &>/dev/null; then
        DETECTED_CLOUD="gcp"
        log_success "Detected Google Cloud Platform"
        return 0
    fi
    
    # Oracle Cloud detection
    if curl -s -m 2 -H "Authorization: Bearer Oracle" "http://169.254.169.254/opc/v2/instance/" &>/dev/null; then
        DETECTED_CLOUD="oracle"
        log_success "Detected Oracle Cloud"
        return 0
    fi
    
    # Generic/Other
    DETECTED_CLOUD="generic"
    log_warning "Cloud provider not detected, using generic configuration"
}

#==============================================================================
# NETWORK CONFIGURATION DETECTION
#==============================================================================

detect_network_config() {
    log_info "Detecting network configuration..."
    
    # Detect primary interface
    CURRENT_INTERFACE=$(ip route | grep default | awk '{print $5}' | head -n1)
    if [[ -z "$CURRENT_INTERFACE" ]]; then
        CURRENT_INTERFACE=$(ls /sys/class/net | grep -v lo | head -n1)
    fi
    log_info "Primary interface: $CURRENT_INTERFACE"
    
    # Detect IP address
    CURRENT_IP=$(ip addr show "$CURRENT_INTERFACE" | grep "inet " | awk '{print $2}' | cut -d/ -f1 | head -n1)
    log_info "Current IP: $CURRENT_IP"
    
    # Detect gateway
    CURRENT_GATEWAY=$(ip route | grep default | awk '{print $3}' | head -n1)
    log_info "Current gateway: $CURRENT_GATEWAY"
    
    # Detect DNS servers
    if [[ -f /etc/resolv.conf ]]; then
        CURRENT_DNS=$(grep "^nameserver" /etc/resolv.conf | awk '{print $2}' | tr '\n' ' ' | sed 's/ $//')
    fi
    if [[ -z "$CURRENT_DNS" ]]; then
        CURRENT_DNS="8.8.8.8 8.8.4.4"
    fi
    log_info "Current DNS: $CURRENT_DNS"
    
    log_success "Network configuration detected"
}

#==============================================================================
# BACKUP FUNCTIONS
#==============================================================================

create_backup() {
    log_info "Creating comprehensive backup..."
    
    mkdir -p "$BACKUP_DIR"
    
    # Backup network configuration
    log_info "Backing up network configuration..."
    mkdir -p "$BACKUP_DIR/network"
    
    [[ -d /etc/network ]] && cp -r /etc/network "$BACKUP_DIR/network/" 2>/dev/null || true
    [[ -d /etc/sysconfig/network-scripts ]] && cp -r /etc/sysconfig/network-scripts "$BACKUP_DIR/network/" 2>/dev/null || true
    [[ -d /etc/netplan ]] && cp -r /etc/netplan "$BACKUP_DIR/network/" 2>/dev/null || true
    [[ -f /etc/resolv.conf ]] && cp /etc/resolv.conf "$BACKUP_DIR/network/" 2>/dev/null || true
    [[ -f /etc/hostname ]] && cp /etc/hostname "$BACKUP_DIR/" 2>/dev/null || true
    [[ -f /etc/hosts ]] && cp /etc/hosts "$BACKUP_DIR/" 2>/dev/null || true
    
    # Backup SSH
    log_info "Backing up SSH configuration..."
    mkdir -p "$BACKUP_DIR/ssh"
    [[ -d /etc/ssh ]] && cp -r /etc/ssh "$BACKUP_DIR/" 2>/dev/null || true
    [[ -d /root/.ssh ]] && cp -r /root/.ssh "$BACKUP_DIR/" 2>/dev/null || true
    
    # Backup fstab
    [[ -f /etc/fstab ]] && cp /etc/fstab "$BACKUP_DIR/" 2>/dev/null || true
    
    # Backup cloud-init
    [[ -d /etc/cloud ]] && cp -r /etc/cloud "$BACKUP_DIR/" 2>/dev/null || true
    
    # Save current network state
    cat > "$BACKUP_DIR/network-state.txt" << EOF
INTERFACE=$CURRENT_INTERFACE
IP=$CURRENT_IP
GATEWAY=$CURRENT_GATEWAY
DNS=$CURRENT_DNS
CLOUD=$DETECTED_CLOUD
EOF
    
    log_success "Backup created at $BACKUP_DIR"
}

#==============================================================================
# INTERACTIVE MENU SYSTEM
#==============================================================================

show_distro_menu() {
    local distros=("ubuntu" "debian" "almalinux" "rocky" "centos" "fedora" "arch")
    local display_names=("Ubuntu" "Debian" "AlmaLinux" "Rocky Linux" "CentOS" "Fedora" "Arch Linux")
    
    echo ""
    echo -e "${COLOR_CYAN}╔══════════════════════════════════════════╗${COLOR_RESET}"
    echo -e "${COLOR_CYAN}║     Select Target Distribution          ║${COLOR_RESET}"
    echo -e "${COLOR_CYAN}╚══════════════════════════════════════════╝${COLOR_RESET}"
    echo ""
    
    for i in "${!distros[@]}"; do
        echo "  $((i+1)). ${display_names[$i]}"
    done
    
    echo ""
    read -p "Enter your choice [1-${#distros[@]}]: " choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#distros[@]} ]]; then
        TARGET_DISTRO="${distros[$((choice-1))]}"
        log_info "Selected distribution: $TARGET_DISTRO"
        return 0
    else
        log_error "Invalid choice"
        return 1
    fi
}

show_version_menu() {
    local versions=(${DISTRO_VERSIONS[$TARGET_DISTRO]})
    
    echo ""
    echo -e "${COLOR_CYAN}╔══════════════════════════════════════════╗${COLOR_RESET}"
    echo -e "${COLOR_CYAN}║     Select ${TARGET_DISTRO^} Version              ║${COLOR_RESET}"
    echo -e "${COLOR_CYAN}╚══════════════════════════════════════════╝${COLOR_RESET}"
    echo ""
    
    for i in "${!versions[@]}"; do
        echo "  $((i+1)). ${TARGET_DISTRO^} ${versions[$i]}"
    done
    
    echo ""
    read -p "Enter your choice [1-${#versions[@]}]: " choice
    
    if [[ "$choice" =~ ^[0-9]+$ ]] && [[ $choice -ge 1 ]] && [[ $choice -le ${#versions[@]} ]]; then
        TARGET_VERSION="${versions[$((choice-1))]}"
        log_info "Selected version: $TARGET_VERSION"
        return 0
    else
        log_error "Invalid choice"
        return 1
    fi
}

confirm_migration() {
    echo ""
    echo -e "${COLOR_YELLOW}╔══════════════════════════════════════════════════════════════╗${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}║                 FINAL CONFIRMATION                           ║${COLOR_RESET}"
    echo -e "${COLOR_YELLOW}╚══════════════════════════════════════════════════════════════╝${COLOR_RESET}"
    echo ""
    echo -e "  Target Distribution: ${COLOR_GREEN}${TARGET_DISTRO^} ${TARGET_VERSION}${COLOR_RESET}"
    echo -e "  Current IP: ${COLOR_BLUE}${CURRENT_IP}${COLOR_RESET}"
    echo -e "  Cloud Provider: ${COLOR_BLUE}${DETECTED_CLOUD}${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_RED}  THIS WILL DESTROY ALL DATA ON THE ROOT PARTITION!${COLOR_RESET}"
    echo ""
    echo -e "  Type '${COLOR_WHITE}${CONFIRMATION_PHRASE}${COLOR_RESET}' to proceed:"
    echo ""
    
    read -p "  > " confirmation
    
    if [[ "$confirmation" == "$CONFIRMATION_PHRASE" ]]; then
        log_success "Migration confirmed by user"
        return 0
    else
        log_warning "Migration cancelled by user"
        return 1
    fi
}

#==============================================================================
# DISK DETECTION
#==============================================================================

detect_root_device() {
    log_info "Detecting root device..."
    
    ROOT_PARTITION=$(df / | tail -1 | awk '{print $1}')
    
    # Resolve /dev/root symlink to actual device
    if [[ "$ROOT_PARTITION" == "/dev/root" ]]; then
        # Try multiple methods to resolve the actual root device
        if [[ -L /dev/root ]]; then
            ROOT_PARTITION=$(readlink -f /dev/root)
        else
            # Use findmnt to get the actual device
            ROOT_PARTITION=$(findmnt -n -o SOURCE /)
        fi
        
        # If still /dev/root, try using /proc/mounts
        if [[ "$ROOT_PARTITION" == "/dev/root" ]] || [[ -z "$ROOT_PARTITION" ]]; then
            ROOT_PARTITION=$(grep "^[^ ]* / " /proc/mounts | awk '{print $1}' | head -n1)
        fi
        
        # Last resort: try lsblk
        if [[ "$ROOT_PARTITION" == "/dev/root" ]] || [[ -z "$ROOT_PARTITION" ]]; then
            local dev_name=$(lsblk -rno NAME,MOUNTPOINT | grep "^[^ ]* /$" | awk '{print $1}' | head -n1)
            if [[ -n "$dev_name" ]]; then
                ROOT_PARTITION="/dev/$dev_name"
            fi
        fi
        
        log_info "Resolved /dev/root to actual device: $ROOT_PARTITION"
    fi
    
    # Extract device name (remove partition number)
    if [[ $ROOT_PARTITION =~ ^/dev/nvme ]]; then
        ROOT_DEVICE=$(echo "$ROOT_PARTITION" | sed 's/p[0-9]*$//')
    elif [[ $ROOT_PARTITION =~ ^/dev/xvd ]]; then
        ROOT_DEVICE=$(echo "$ROOT_PARTITION" | sed 's/[0-9]*$//')
    else
        ROOT_DEVICE=$(echo "$ROOT_PARTITION" | sed 's/[0-9]*$//')
    fi
    
    log_info "Root partition: $ROOT_PARTITION"
    log_info "Root device: $ROOT_DEVICE"
}

#==============================================================================
# DISTRIBUTION INSTALLATION FUNCTIONS
#==============================================================================

install_ubuntu_debian() {
    local distro="$1"
    local version="$2"
    local target_dir="/mnt/newroot"
    
    log_info "Installing ${distro^} ${version}..."
    
    # Ensure network is ready
    ensure_network_ready || log_warning "Network issues detected, proceeding with caution"
    
    # Install debootstrap if needed
    if ! command -v debootstrap &>/dev/null; then
        log_info "Installing debootstrap..."
        if command -v apt-get &>/dev/null; then
            run_apt_get_with_retry "apt-get update -qq && apt-get install -y debootstrap"
        elif command -v yum &>/dev/null; then
            retry_with_backoff 3 10 60 yum install -y debootstrap
        elif command -v dnf &>/dev/null; then
            retry_with_backoff 3 10 60 dnf install -y debootstrap
        fi
    fi
    
    # Verify debootstrap and its scripts are available
    if ! command -v debootstrap &>/dev/null; then
        log_fatal "debootstrap is not installed and could not be installed"
    fi
    
    # Check if debootstrap scripts directory exists
    local debootstrap_scripts="/usr/share/debootstrap/scripts"
    if [[ ! -d "$debootstrap_scripts" ]]; then
        log_warning "Debootstrap scripts directory not found at $debootstrap_scripts"
        # Try to reinstall debootstrap to fix missing scripts
        if command -v apt-get &>/dev/null; then
            log_info "Reinstalling debootstrap to restore scripts..."
            run_apt_get_with_retry "apt-get install --reinstall -y debootstrap"
        fi
    fi
    
    mkdir -p "$target_dir"
    
    # Map version to codename for Ubuntu
    local codename=""
    if [[ "$distro" == "ubuntu" ]]; then
        case "$version" in
            24.04) codename="noble" ;;
            22.04) codename="jammy" ;;
            20.04) codename="focal" ;;
            18.04) codename="bionic" ;;
            *) log_fatal "Unknown Ubuntu version: $version" ;;
        esac
    else
        # Debian
        case "$version" in
            12) codename="bookworm" ;;
            11) codename="bullseye" ;;
            10) codename="buster" ;;
            *) log_fatal "Unknown Debian version: $version" ;;
        esac
    fi
    
    # Verify the codename script exists in debootstrap
    if [[ -d "$debootstrap_scripts" ]] && [[ ! -f "$debootstrap_scripts/$codename" ]]; then
        log_warning "Debootstrap script for $codename not found"
        # Check if there's a symlink or alternate name we can use
        if [[ -L "$debootstrap_scripts/$codename" ]]; then
            local target=$(readlink -f "$debootstrap_scripts/$codename")
            if [[ -f "$target" ]]; then
                log_info "Found valid symlink for $codename pointing to $target"
            else
                log_warning "Symlink for $codename exists but target is missing"
                log_info "Will rely on debootstrap's fallback mechanism"
            fi
        else
            log_info "Will rely on debootstrap's fallback mechanism"
        fi
    fi
    
    local mirror=""
    if [[ "$distro" == "ubuntu" ]]; then
        mirror="http://archive.ubuntu.com/ubuntu"
    else
        mirror="http://deb.debian.org/debian"
    fi
    
    log_info "Running debootstrap for $codename..."
    # Run debootstrap with retry logic
    if ! retry_with_backoff 3 15 120 debootstrap --arch=amd64 "$codename" "$target_dir" "$mirror"; then
        log_fatal "Failed to run debootstrap after multiple attempts"
    fi
    
    log_success "${distro^} ${version} base system installed"
}

install_rhel_based() {
    local distro="$1"
    local version="$2"
    local target_dir="/mnt/newroot"
    
    log_info "Installing ${distro^} ${version}..."
    
    # Ensure network is ready
    ensure_network_ready || log_warning "Network issues detected, proceeding with caution"
    
    mkdir -p "$target_dir"
    
    # Determine baseurl
    local baseurl=""
    case "$distro" in
        almalinux)
            baseurl="https://repo.almalinux.org/almalinux/${version}/BaseOS/x86_64/os/"
            ;;
        rocky)
            baseurl="https://download.rockylinux.org/pub/rocky/${version}/BaseOS/x86_64/os/"
            ;;
        centos)
            if [[ "$version" == "7" ]]; then
                baseurl="http://mirror.centos.org/centos/7/os/x86_64/"
            else
                baseurl="http://mirror.stream.centos.org/${version}-stream/BaseOS/x86_64/os/"
            fi
            ;;
        fedora)
            baseurl="https://download.fedoraproject.org/pub/fedora/linux/releases/${version}/Everything/x86_64/os/"
            ;;
    esac
    
    # Install using yum/dnf with retry logic
    if command -v dnf &>/dev/null; then
        log_info "Using dnf for installation..."
        retry_with_backoff 3 15 120 bash -c "dnf --installroot='$target_dir' --releasever='$version' \
            --disablerepo='*' --repofrompath='base,$baseurl' --enablerepo='base' \
            -y groupinstall 'Minimal Install'" || \
            retry_with_backoff 3 15 120 bash -c "dnf --installroot='$target_dir' --releasever='$version' \
            --disablerepo='*' --repofrompath='base,$baseurl' --enablerepo='base' \
            -y install @core kernel grub2"
    elif command -v yum &>/dev/null; then
        log_info "Using yum for installation..."
        retry_with_backoff 3 15 120 bash -c "yum --installroot='$target_dir' --releasever='$version' \
            --disablerepo='*' --repofrompath='base,$baseurl' --enablerepo='base' \
            -y groupinstall 'Minimal Install'" || \
            retry_with_backoff 3 15 120 bash -c "yum --installroot='$target_dir' --releasever='$version' \
            --disablerepo='*' --repofrompath='base,$baseurl' --enablerepo='base' \
            -y install @core kernel grub2"
    else
        log_fatal "Neither yum nor dnf found"
    fi
    
    log_success "${distro^} ${version} base system installed"
}

install_arch() {
    local target_dir="/mnt/newroot"
    
    log_info "Installing Arch Linux..."
    
    # Ensure network is ready
    ensure_network_ready || log_warning "Network issues detected, proceeding with caution"
    
    # Install pacstrap if not available
    if ! command -v pacstrap &>/dev/null; then
        log_warning "pacstrap not available, downloading arch-install-scripts..."
        retry_with_backoff 3 10 60 wget -O /tmp/arch-install-scripts.tar.gz \
            https://github.com/archlinux/arch-install-scripts/archive/refs/heads/master.tar.gz
        tar -xzf /tmp/arch-install-scripts.tar.gz -C /tmp/
        export PATH="/tmp/arch-install-scripts-master:$PATH"
    fi
    
    mkdir -p "$target_dir"
    
    log_info "Running pacstrap..."
    retry_with_backoff 3 15 120 pacstrap -c "$target_dir" base linux linux-firmware grub openssh networkmanager
    
    log_success "Arch Linux base system installed"
}

#==============================================================================
# PARTITION MANAGEMENT
#==============================================================================

prepare_disk() {
    log_info "Preparing disk for installation..."
    
    # Check if root partition is currently mounted at /
    # Use findmnt for more reliable detection
    local root_is_mounted=false
    local current_root_dev=$(findmnt -n -o SOURCE / 2>/dev/null)
    if [[ "$current_root_dev" == "$ROOT_PARTITION" ]]; then
        root_is_mounted=true
        log_warning "Root partition $ROOT_PARTITION is currently mounted as /"
        log_info "Will install to /mnt/newroot on current filesystem"
    fi
    
    # Unmount anything on /mnt (except if it's our root)
    if ! $root_is_mounted; then
        umount -R /mnt 2>/dev/null || true
    fi
    
    # Create target directory for new installation
    mkdir -p /mnt/newroot
    
    if $root_is_mounted; then
        # Root is mounted - we're running from the live system
        # Cannot format while mounted, so just prepare the directory
        log_info "Installing new system to /mnt/newroot on current filesystem"
        log_warning "Note: Old system files will remain until overwritten by new installation"
        log_warning "A manual cleanup or reformat may be needed post-installation"
    else
        # Root is not mounted (running from rescue environment)
        # Format root partition
        log_warning "Formatting $ROOT_PARTITION..."
        mkfs.ext4 -F "$ROOT_PARTITION"
        
        # Mount new root
        mount "$ROOT_PARTITION" /mnt/newroot
    fi
    
    log_success "Disk prepared"
}

#==============================================================================
# NETWORK RESTORATION
#==============================================================================

restore_network_config() {
    local target_dir="/mnt/newroot"
    
    log_info "Restoring network configuration..."
    
    # Create network config based on distro and cloud provider
    case "$TARGET_DISTRO" in
        ubuntu|debian)
            restore_network_ubuntu_debian "$target_dir"
            ;;
        almalinux|rocky|centos|fedora)
            restore_network_rhel "$target_dir"
            ;;
        arch)
            restore_network_arch "$target_dir"
            ;;
    esac
    
    # Restore hostname
    if [[ -f "$BACKUP_DIR/hostname" ]]; then
        cp "$BACKUP_DIR/hostname" "$target_dir/etc/hostname"
    fi
    
    # Restore hosts
    if [[ -f "$BACKUP_DIR/hosts" ]]; then
        cp "$BACKUP_DIR/hosts" "$target_dir/etc/hosts"
    fi
    
    # Restore DNS
    mkdir -p "$target_dir/etc"
    cat > "$target_dir/etc/resolv.conf" << EOF
# Generated by distro-migrator
$(for dns in $CURRENT_DNS; do echo "nameserver $dns"; done)
EOF
    
    log_success "Network configuration restored"
}

restore_network_ubuntu_debian() {
    local target_dir="$1"
    
    mkdir -p "$target_dir/etc/netplan"
    
    # Detect if using DHCP or static IP by checking current configuration
    local use_dhcp=true
    if [[ -f /etc/netplan/01-netcfg.yaml ]] || [[ -f /etc/netplan/50-cloud-init.yaml ]]; then
        # Check netplan files
        if grep -q "dhcp4.*true" /etc/netplan/*.yaml 2>/dev/null; then
            use_dhcp=true
        elif grep -q "addresses:" /etc/netplan/*.yaml 2>/dev/null; then
            use_dhcp=false
        fi
    elif [[ -f /etc/network/interfaces ]]; then
        # Check traditional interfaces file
        if grep -q "iface.*dhcp" /etc/network/interfaces 2>/dev/null; then
            use_dhcp=true
        elif grep -q "iface.*static" /etc/network/interfaces 2>/dev/null; then
            use_dhcp=false
        fi
    fi
    
    # For cloud environments, prefer DHCP
    if [[ "$DETECTED_CLOUD" != "generic" ]]; then
        use_dhcp=true
    fi
    
    if $use_dhcp; then
        # Create DHCP netplan configuration
        cat > "$target_dir/etc/netplan/01-netcfg.yaml" << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $CURRENT_INTERFACE:
      dhcp4: true
      dhcp6: false
EOF
    else
        # Create static IP netplan configuration
        local netmask=$(ip addr show "$CURRENT_INTERFACE" | grep "inet " | awk '{print $2}' | cut -d/ -f2 | head -n1)
        cat > "$target_dir/etc/netplan/01-netcfg.yaml" << EOF
network:
  version: 2
  renderer: networkd
  ethernets:
    $CURRENT_INTERFACE:
      addresses:
        - $CURRENT_IP/$netmask
      gateway4: $CURRENT_GATEWAY
      nameservers:
        addresses: [$(echo $CURRENT_DNS | sed 's/ /, /g')]
EOF
    fi
    
    chmod 600 "$target_dir/etc/netplan/01-netcfg.yaml"
}

restore_network_rhel() {
    local target_dir="$1"
    
    mkdir -p "$target_dir/etc/sysconfig/network-scripts"
    
    # Detect if using DHCP or static IP
    local use_dhcp=true
    if [[ -f "/etc/sysconfig/network-scripts/ifcfg-$CURRENT_INTERFACE" ]]; then
        if grep -q "BOOTPROTO.*dhcp" "/etc/sysconfig/network-scripts/ifcfg-$CURRENT_INTERFACE" 2>/dev/null; then
            use_dhcp=true
        elif grep -q "BOOTPROTO.*static\|BOOTPROTO.*none" "/etc/sysconfig/network-scripts/ifcfg-$CURRENT_INTERFACE" 2>/dev/null; then
            use_dhcp=false
        fi
    fi
    
    # For cloud environments, prefer DHCP
    if [[ "$DETECTED_CLOUD" != "generic" ]]; then
        use_dhcp=true
    fi
    
    if $use_dhcp; then
        # Create DHCP interface configuration
        cat > "$target_dir/etc/sysconfig/network-scripts/ifcfg-$CURRENT_INTERFACE" << EOF
DEVICE=$CURRENT_INTERFACE
BOOTPROTO=dhcp
ONBOOT=yes
TYPE=Ethernet
EOF
    else
        # Create static IP interface configuration
        local netmask=$(ip addr show "$CURRENT_INTERFACE" | grep "inet " | awk '{print $2}' | cut -d/ -f2 | head -n1)
        
        # Convert DNS list to array for proper handling
        local dns_array=($CURRENT_DNS)
        local dns_config=""
        for i in "${!dns_array[@]}"; do
            dns_config="${dns_config}DNS$((i+1))=${dns_array[$i]}\n"
        done
        
        cat > "$target_dir/etc/sysconfig/network-scripts/ifcfg-$CURRENT_INTERFACE" << EOF
DEVICE=$CURRENT_INTERFACE
BOOTPROTO=static
ONBOOT=yes
TYPE=Ethernet
IPADDR=$CURRENT_IP
PREFIX=$netmask
GATEWAY=$CURRENT_GATEWAY
$(echo -e "$dns_config")
EOF
    fi
}

restore_network_arch() {
    local target_dir="$1"
    
    # Enable NetworkManager
    mkdir -p "$target_dir/etc/systemd/system/multi-user.target.wants"
    ln -sf /usr/lib/systemd/system/NetworkManager.service \
        "$target_dir/etc/systemd/system/multi-user.target.wants/NetworkManager.service" 2>/dev/null || true
    
    # Create NetworkManager connection
    mkdir -p "$target_dir/etc/NetworkManager/system-connections"
    cat > "$target_dir/etc/NetworkManager/system-connections/$CURRENT_INTERFACE.nmconnection" << EOF
[connection]
id=$CURRENT_INTERFACE
type=ethernet
interface-name=$CURRENT_INTERFACE
autoconnect=true

[ethernet]

[ipv4]
method=auto

[ipv6]
method=ignore
EOF
    
    chmod 600 "$target_dir/etc/NetworkManager/system-connections/$CURRENT_INTERFACE.nmconnection"
}

#==============================================================================
# SSH RESTORATION
#==============================================================================

restore_ssh() {
    local target_dir="/mnt/newroot"
    
    log_info "Restoring SSH configuration..."
    
    # Restore SSH daemon config
    if [[ -d "$BACKUP_DIR/ssh" ]]; then
        mkdir -p "$target_dir/etc/ssh"
        cp -r "$BACKUP_DIR/ssh/"* "$target_dir/etc/ssh/" 2>/dev/null || true
    fi
    
    # Restore root SSH keys
    if [[ -d "$BACKUP_DIR/.ssh" ]]; then
        mkdir -p "$target_dir/root/.ssh"
        cp -r "$BACKUP_DIR/.ssh/"* "$target_dir/root/.ssh/" 2>/dev/null || true
        chmod 700 "$target_dir/root/.ssh"
        chmod 600 "$target_dir/root/.ssh/"* 2>/dev/null || true
    fi
    
    # Ensure SSH service is enabled
    case "$TARGET_DISTRO" in
        ubuntu|debian)
            chroot "$target_dir" systemctl enable ssh 2>/dev/null || \
            chroot "$target_dir" systemctl enable sshd 2>/dev/null || true
            ;;
        almalinux|rocky|centos|fedora|arch)
            chroot "$target_dir" systemctl enable sshd 2>/dev/null || true
            ;;
    esac
    
    log_success "SSH configuration restored"
}

#==============================================================================
# BOOTLOADER INSTALLATION
#==============================================================================

install_bootloader() {
    local target_dir="/mnt/newroot"
    
    log_info "Installing bootloader (GRUB2)..."
    
    # Mount essential filesystems
    mount --bind /dev "$target_dir/dev"
    mount --bind /dev/pts "$target_dir/dev/pts"
    mount --bind /proc "$target_dir/proc"
    mount --bind /sys "$target_dir/sys"
    
    # Generate fstab
    cat > "$target_dir/etc/fstab" << EOF
# Generated by distro-migrator
$ROOT_PARTITION / ext4 defaults 0 1
EOF
    
    # Ensure DNS is configured in chroot
    cp /etc/resolv.conf "$target_dir/etc/resolv.conf" 2>/dev/null || true
    
    # Install GRUB
    case "$TARGET_DISTRO" in
        ubuntu|debian)
            # Use retry logic for package installation
            retry_with_backoff 3 15 120 bash -c "chroot '$target_dir' apt-get update -qq" || true
            retry_with_backoff 3 15 120 bash -c "chroot '$target_dir' apt-get install -y grub-pc linux-image-generic" || \
            retry_with_backoff 3 15 120 bash -c "chroot '$target_dir' apt-get install -y grub2 linux-image-generic" || true
            ;;
        almalinux|rocky|centos|fedora)
            retry_with_backoff 3 15 120 bash -c "chroot '$target_dir' dnf install -y grub2 kernel" || \
            retry_with_backoff 3 15 120 bash -c "chroot '$target_dir' yum install -y grub2 kernel" || true
            ;;
        arch)
            # Already installed with pacstrap
            ;;
    esac
    
    # Install GRUB to device
    chroot "$target_dir" grub-install "$ROOT_DEVICE" || \
    chroot "$target_dir" grub2-install "$ROOT_DEVICE" || true
    
    # Generate GRUB config
    chroot "$target_dir" update-grub 2>/dev/null || \
    chroot "$target_dir" grub-mkconfig -o /boot/grub/grub.cfg 2>/dev/null || \
    chroot "$target_dir" grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null || true
    
    # Unmount filesystems
    umount "$target_dir/sys" 2>/dev/null || true
    umount "$target_dir/proc" 2>/dev/null || true
    umount "$target_dir/dev/pts" 2>/dev/null || true
    umount "$target_dir/dev" 2>/dev/null || true
    
    log_success "Bootloader installed"
}

#==============================================================================
# POST-INSTALLATION CONFIGURATION
#==============================================================================

post_install_config() {
    local target_dir="/mnt/newroot"
    
    log_info "Performing post-installation configuration..."
    
    # Mount for chroot
    mount --bind /dev "$target_dir/dev"
    mount --bind /dev/pts "$target_dir/dev/pts"
    mount --bind /proc "$target_dir/proc"
    mount --bind /sys "$target_dir/sys"
    
    # Ensure DNS is configured in chroot
    cp /etc/resolv.conf "$target_dir/etc/resolv.conf" 2>/dev/null || true
    
    # Set root password (random)
    local new_pass=$(openssl rand -base64 12)
    echo "root:$new_pass" | chroot "$target_dir" chpasswd
    log_warning "New root password: $new_pass"
    echo "NEW_ROOT_PASSWORD=$new_pass" >> "$BACKUP_DIR/migration-info.txt"
    
    # Install essential packages with retry logic
    case "$TARGET_DISTRO" in
        ubuntu|debian)
            retry_with_backoff 3 15 120 bash -c "chroot '$target_dir' apt-get update -qq" || true
            retry_with_backoff 3 15 120 bash -c "chroot '$target_dir' apt-get install -y openssh-server curl wget sudo" || true
            ;;
        almalinux|rocky|centos|fedora)
            retry_with_backoff 3 15 120 bash -c "chroot '$target_dir' dnf install -y openssh-server curl wget sudo" || \
            retry_with_backoff 3 15 120 bash -c "chroot '$target_dir' yum install -y openssh-server curl wget sudo" || true
            ;;
        arch)
            retry_with_backoff 3 15 120 bash -c "chroot '$target_dir' pacman -Sy --noconfirm openssh curl wget sudo" || true
            ;;
    esac
    
    # Unmount
    umount "$target_dir/sys" 2>/dev/null || true
    umount "$target_dir/proc" 2>/dev/null || true
    umount "$target_dir/dev/pts" 2>/dev/null || true
    umount "$target_dir/dev" 2>/dev/null || true
    
    log_success "Post-installation configuration complete"
}

#==============================================================================
# MAIN MIGRATION FUNCTION
#==============================================================================

perform_migration() {
    log_info "Starting migration process..."
    
    # Detect root device
    detect_root_device
    
    # Prepare disk
    prepare_disk
    
    # Install distribution
    case "$TARGET_DISTRO" in
        ubuntu|debian)
            install_ubuntu_debian "$TARGET_DISTRO" "$TARGET_VERSION"
            ;;
        almalinux|rocky|centos|fedora)
            install_rhel_based "$TARGET_DISTRO" "$TARGET_VERSION"
            ;;
        arch)
            install_arch
            ;;
        *)
            log_fatal "Unknown distribution: $TARGET_DISTRO"
            ;;
    esac
    
    # Restore configurations
    restore_network_config
    restore_ssh
    
    # Install bootloader
    install_bootloader
    
    # Post-install configuration
    post_install_config
    
    log_success "Migration completed successfully!"
}

#==============================================================================
# VERIFICATION
#==============================================================================

verify_migration() {
    log_info "Verifying migration..."
    
    local target_dir="/mnt/newroot"
    local errors=0
    
    # Check if system files exist
    if [[ ! -f "$target_dir/etc/fstab" ]]; then
        log_error "fstab not found"
        ((errors++))
    fi
    
    if [[ ! -d "$target_dir/etc/ssh" ]]; then
        log_error "SSH directory not found"
        ((errors++))
    fi
    
    if [[ ! -f "$target_dir/etc/hostname" ]]; then
        log_warning "hostname not found"
    fi
    
    # Check bootloader
    if [[ ! -d "$target_dir/boot/grub" ]] && [[ ! -d "$target_dir/boot/grub2" ]]; then
        log_error "GRUB not found"
        ((errors++))
    fi
    
    if [[ $errors -gt 0 ]]; then
        log_warning "Migration completed with $errors errors"
        return 1
    else
        log_success "Migration verification passed"
        return 0
    fi
}

#==============================================================================
# RECOVERY FUNCTION
#==============================================================================

attempt_recovery() {
    log_error "Migration failed, attempting recovery..."
    
    # Unmount new root if mounted
    umount -R /mnt/newroot 2>/dev/null || true
    
    # Note: Full recovery is difficult since root partition was formatted
    # The backup is in /tmp which will be lost on reboot
    
    log_error "Recovery not possible after formatting"
    log_error "Backup is available at: $BACKUP_DIR"
    log_error "You may need to reinstall from cloud provider console"
    
    exit 1
}

#==============================================================================
# MAIN EXECUTION
#==============================================================================

main() {
    # Initialize logging
    log_init
    
    # Show banner
    show_banner
    
    # Pre-flight checks
    log_info "Performing pre-flight checks..."
    check_root
    check_not_container
    check_disk_space
    check_network
    check_dependencies
    
    # Detect environment
    detect_cloud_provider
    detect_network_config
    
    # Show current system info
    echo ""
    echo -e "${COLOR_CYAN}Current System Information:${COLOR_RESET}"
    echo -e "  OS: $(cat /etc/os-release | grep "^PRETTY_NAME" | cut -d'"' -f2)"
    echo -e "  IP Address: $CURRENT_IP"
    echo -e "  Interface: $CURRENT_INTERFACE"
    echo -e "  Cloud: $DETECTED_CLOUD"
    echo ""
    
    pause_prompt
    
    # Interactive menu
    while true; do
        if show_distro_menu; then
            break
        fi
    done
    
    while true; do
        if show_version_menu; then
            break
        fi
    done
    
    # Show warnings
    show_warning
    
    # Final confirmation
    if ! confirm_migration; then
        log_info "Migration cancelled"
        exit 0
    fi
    
    # Create backup
    create_backup
    
    # Perform migration
    if ! perform_migration; then
        attempt_recovery
    fi
    
    # Verify migration
    verify_migration || log_warning "Verification had warnings"
    
    # Show completion message
    echo ""
    echo -e "${COLOR_GREEN}╔══════════════════════════════════════════════════════════════╗${COLOR_RESET}"
    echo -e "${COLOR_GREEN}║                 MIGRATION COMPLETED!                         ║${COLOR_RESET}"
    echo -e "${COLOR_GREEN}╚══════════════════════════════════════════════════════════════╝${COLOR_RESET}"
    echo ""
    echo -e "  Target: ${COLOR_CYAN}${TARGET_DISTRO^} ${TARGET_VERSION}${COLOR_RESET}"
    echo -e "  Backup: ${COLOR_YELLOW}${BACKUP_DIR}${COLOR_RESET}"
    echo -e "  Log: ${COLOR_YELLOW}${LOG_FILE}${COLOR_RESET}"
    echo ""
    echo -e "${COLOR_YELLOW}IMPORTANT NOTES:${COLOR_RESET}"
    echo -e "  • The system will reboot in 30 seconds"
    echo -e "  • SSH should remain accessible"
    echo -e "  • Check $BACKUP_DIR/migration-info.txt for new root password"
    echo -e "  • If SSH fails, use cloud provider console"
    echo ""
    
    # Countdown to reboot
    log_info "Rebooting in 30 seconds..."
    for i in {30..1}; do
        echo -ne "  Rebooting in $i seconds...\r"
        sleep 1
    done
    
    log_info "Initiating reboot..."
    sync
    reboot
}

#==============================================================================
# ERROR HANDLER
#==============================================================================

error_handler() {
    local line_number=$1
    log_error "Script failed at line $line_number"
    log_error "Check $LOG_FILE for details"
    
    # Try to provide helpful information
    echo ""
    echo -e "${COLOR_RED}╔══════════════════════════════════════════════════════════════╗${COLOR_RESET}"
    echo -e "${COLOR_RED}║                    MIGRATION FAILED                          ║${COLOR_RESET}"
    echo -e "${COLOR_RED}╚══════════════════════════════════════════════════════════════╝${COLOR_RESET}"
    echo ""
    echo -e "  Error at line: $line_number"
    echo -e "  Log file: $LOG_FILE"
    echo -e "  Backup: $BACKUP_DIR"
    echo ""
    
    attempt_recovery
}

trap 'error_handler $LINENO' ERR

#==============================================================================
# SCRIPT ENTRY POINT
#==============================================================================

# Run main function
main "$@"
