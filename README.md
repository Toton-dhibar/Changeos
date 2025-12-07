# ChangeOS - Linux Distribution Migration Script

Complete automated Linux distribution migration tool for cloud VPS environments.

## 🚀 Overview

`distro-migrator.sh` is a comprehensive, single-file bash script that automates complete Linux distribution migration on cloud VPS machines. It replaces the entire operating system while preserving critical configurations like SSH access and network settings.

## ⚠️ CRITICAL WARNING

**THIS SCRIPT WILL COMPLETELY DESTROY YOUR CURRENT OPERATING SYSTEM!**

- Formats the root partition
- Deletes all existing data
- Replaces the entire OS

**Only the following are preserved:**
- Network configuration (IP, DNS, gateway)
- SSH keys and authorized_keys
- Hostname
- Cloud provider settings

**USE WITH EXTREME CAUTION - This is a destructive operation!**

## ✨ Features

### Core Capabilities
- **Single File Architecture**: One self-contained script with zero external dependencies
- **Complete OS Replacement**: Total migration between different Linux distributions
- **Network Preservation**: Maintains exact IP, DNS, and gateway configuration
- **SSH Access Preservation**: Keeps all SSH keys and authorized_keys intact
- **Automatic Bootloader**: Reinstalls and configures GRUB2 automatically
- **Cloud Provider Detection**: Auto-detects AWS, Azure, Google Cloud, Oracle Cloud

### Supported Distributions
- **Ubuntu**: 24.04 LTS, 22.04 LTS, 20.04 LTS, 18.04 LTS
- **Debian**: 12 (Bookworm), 11 (Bullseye), 10 (Buster)
- **AlmaLinux**: 9, 8
- **Rocky Linux**: 9, 8
- **CentOS**: 9 Stream, 8 Stream, 7
- **Fedora**: 39, 38, 37
- **Arch Linux**: Latest

### Migration Examples
- Ubuntu 20.04 → Ubuntu 22.04
- CentOS 7 → AlmaLinux 8
- Debian 11 → Ubuntu 22.04
- Fedora 38 → Rocky Linux 9
- Any supported distro → Any other supported distro

## 📋 Prerequisites

### System Requirements
- Root access
- Minimum 10GB free disk space
- Active network connectivity
- Running on a physical or virtual machine (not containers)

### Supported Environments
- AWS EC2
- Microsoft Azure
- Google Cloud Platform
- Oracle Cloud Infrastructure
- Generic VPS/Bare Metal

## 🔧 Installation

Simply download the script:

```bash
wget https://raw.githubusercontent.com/Toton-dhibar/Changeos/main/distro-migrator.sh
chmod +x distro-migrator.sh
```

Or use curl:

```bash
curl -O https://raw.githubusercontent.com/Toton-dhibar/Changeos/main/distro-migrator.sh
chmod +x distro-migrator.sh
```

## 🎯 Usage

### Basic Usage

Run as root:

```bash
sudo ./distro-migrator.sh
```

### Interactive Workflow

1. **Pre-flight Checks**: The script automatically verifies:
   - Root privileges
   - Disk space availability
   - Network connectivity
   - Required dependencies
   - Environment compatibility

2. **Environment Detection**: Auto-detects:
   - Cloud provider (AWS, Azure, GCP, Oracle, or generic)
   - Current network configuration
   - Current distribution

3. **Distribution Selection**: Interactive menu:
   - Choose target distribution
   - Select specific version

4. **Confirmation**: Requires typing `DESTROY-AND-REPLACE` to proceed

5. **Migration Process**:
   - Creates comprehensive backup
   - Formats root partition
   - Installs new distribution
   - Restores network configuration
   - Restores SSH access
   - Installs bootloader
   - Configures system

6. **Automatic Reboot**: System reboots into new distribution

## 📊 What Gets Preserved

### ✅ Preserved
- IP address and network configuration
- Network gateway and routes
- DNS servers
- SSH daemon configuration
- SSH host keys
- Root's authorized_keys
- Hostname
- /etc/hosts entries
- Cloud-init configurations

### ❌ Not Preserved
- User data and files
- Installed packages
- Application configurations
- User accounts (except root)
- Databases
- Custom system configurations

## 🛡️ Safety Features

### Pre-Migration Checks
- Root permission verification
- Disk space validation (minimum 10GB)
- Container detection (prevents running in Docker/LXC)
- Network connectivity test
- Dependency verification

### Backup System
All critical files are backed up to `/var/backups/distro-migration-backup/`:
- Network configurations
- SSH keys and configs
- hostname and hosts
- resolv.conf
- fstab
- Cloud-init configs

### Error Recovery
- Detailed logging to `/var/log/distro-migration.log`
- Error trapping and handler
- Backup preservation for manual recovery
- Clear error messages

## 📝 Logs and Debugging

### Log Location
```bash
/var/log/distro-migration.log
```

### Backup Location
```bash
/var/backups/distro-migration-backup/
```

### View Logs
```bash
tail -f /var/log/distro-migration.log
```

## 🔍 Post-Migration

### Verification Steps

After reboot, verify:

1. **SSH Access**:
   ```bash
   ssh root@your-server-ip
   ```

2. **Distribution**:
   ```bash
   cat /etc/os-release
   ```

3. **Network**:
   ```bash
   ip addr show
   ip route show
   cat /etc/resolv.conf
   ```

4. **Services**:
   ```bash
   systemctl status sshd
   ```

### New Root Password

The script generates a random root password. Find it in:
```bash
/var/backups/distro-migration-backup/migration-info.txt
```

## ⚙️ Advanced Configuration

### Cloud-Specific Network Templates

The script automatically configures networking based on detected cloud provider:

- **AWS**: eth0 with DHCP
- **Azure**: eth0/ensX with DHCP
- **Google Cloud**: ens4 with DHCP
- **Oracle Cloud**: ens3 with network-scripts
- **Generic**: Attempts to preserve existing configuration

### Distribution-Specific Methods

- **Ubuntu/Debian**: Uses debootstrap
- **RHEL/Fedora families**: Uses dnf/yum with --installroot
- **Arch Linux**: Uses pacstrap

## 🐛 Troubleshooting

### SSH Access Lost

If you lose SSH access after migration:

1. Use cloud provider's console/serial access
2. Check network configuration:
   ```bash
   ip addr show
   systemctl status NetworkManager
   systemctl status networking
   ```
3. Restore from backup:
   ```bash
   /var/backups/distro-migration-backup/
   ```

### Boot Failure

If system doesn't boot:

1. Use cloud provider's rescue mode
2. Mount root partition
3. Check GRUB installation:
   ```bash
   mount /dev/xvda1 /mnt
   chroot /mnt
   grub-install /dev/xvda
   update-grub
   ```

### Network Not Working

1. Check interface name:
   ```bash
   ip link show
   ```
2. Check network configuration files:
   - Ubuntu/Debian: `/etc/netplan/`
   - RHEL: `/etc/sysconfig/network-scripts/`
   - Arch: `/etc/NetworkManager/system-connections/`

## 🧪 Testing

### Test Scenarios Validated

1. Ubuntu 20.04 → Ubuntu 22.04 (AWS)
2. CentOS 7 → AlmaLinux 8 (Azure)
3. Debian 11 → Ubuntu 22.04 (Google Cloud)
4. Fedora 38 → Rocky Linux 9 (Oracle Cloud)

### Manual Testing

**⚠️ WARNING: Only test on non-production systems!**

```bash
# Dry-run syntax check
bash -n distro-migrator.sh

# Check with shellcheck
shellcheck distro-migrator.sh
```

## 📚 Technical Details

### Script Architecture

The script is organized into functional sections:
1. Global configuration and variables
2. Color definitions for output
3. Logging functions
4. Banner and UI functions
5. Pre-flight checks
6. Cloud provider detection
7. Network detection and preservation
8. Backup functions
9. Interactive menu system
10. Disk preparation
11. Distribution-specific installation
12. Network restoration
13. SSH restoration
14. Bootloader installation
15. Post-installation configuration
16. Verification
17. Error handling and recovery

### Execution Flow

```
main()
├── Pre-flight checks
├── Environment detection
├── Interactive menus
├── Backup creation
├── perform_migration()
│   ├── Disk preparation
│   ├── Distribution installation
│   ├── Network restoration
│   ├── SSH restoration
│   ├── Bootloader installation
│   └── Post-config
├── Verification
└── Reboot
```

## 🤝 Contributing

Contributions are welcome! Please:

1. Test thoroughly on non-production systems
2. Document any changes
3. Follow existing code style
4. Add error handling
5. Update README if needed

## 📄 License

MIT License - See LICENSE file for details

## ⚡ Quick Start Example

```bash
# Download script
wget https://raw.githubusercontent.com/Toton-dhibar/Changeos/main/distro-migrator.sh

# Make executable
chmod +x distro-migrator.sh

# Run as root
sudo ./distro-migrator.sh

# Follow interactive prompts
# 1. Select distribution (e.g., Ubuntu)
# 2. Select version (e.g., 22.04)
# 3. Type "DESTROY-AND-REPLACE" to confirm
# 4. Wait for migration to complete
# 5. System will automatically reboot
```

## 🆘 Support

For issues, questions, or contributions:
- GitHub Issues: https://github.com/Toton-dhibar/Changeos/issues

## 📌 Important Notes

1. **Backup Externally**: The script creates a backup in `/var/backups/`, which persists across reboots. However, it's still recommended to back up critical data externally before migration.

2. **Test First**: Always test on a non-production system first.

3. **Cloud Console Access**: Ensure you have cloud provider console/serial access as a backup.

4. **Recovery Plan**: Have a recovery plan in case migration fails.

5. **Network Dependency**: Script requires internet access to download distribution packages.

6. **Time Required**: Migration typically takes 10-30 minutes depending on:
   - Network speed
   - Distribution size
   - Server specifications

---

**Remember: This script performs destructive operations. Use at your own risk!**