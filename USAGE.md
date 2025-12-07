# Distro Migrator - Usage Examples

This document provides practical examples and use cases for the Linux Distribution Migration Script.

## Table of Contents
- [Basic Usage](#basic-usage)
- [Common Migration Scenarios](#common-migration-scenarios)
- [Cloud Provider Examples](#cloud-provider-examples)
- [Emergency Recovery](#emergency-recovery)
- [Best Practices](#best-practices)

## Basic Usage

### Quick Start

```bash
# 1. Download the script
wget https://raw.githubusercontent.com/Toton-dhibar/Changeos/main/distro-migrator.sh

# 2. Make it executable
chmod +x distro-migrator.sh

# 3. Run as root
sudo ./distro-migrator.sh
```

### Expected Output

```
╔══════════════════════════════════════════════════════════════════╗
║                                                                  ║
║        Linux Distribution Migration Script v1.0.0               ║
║                                                                  ║
║        DANGER: This will COMPLETELY REPLACE your OS             ║
║                                                                  ║
╚══════════════════════════════════════════════════════════════════╝

[INFO] Performing pre-flight checks...
[✓] Running as root
[✓] Not running in container
[✓] Sufficient disk space: 50GB available
[✓] Network connectivity verified
[✓] All dependencies satisfied
[INFO] Detecting cloud provider...
[✓] Detected AWS
```

## Common Migration Scenarios

### Scenario 1: Ubuntu LTS Upgrade on AWS

**Use Case**: Upgrade from Ubuntu 20.04 to Ubuntu 22.04 on AWS EC2

```bash
sudo ./distro-migrator.sh

# Menu selections:
# 1. Select distribution: 1 (Ubuntu)
# 2. Select version: 2 (22.04)
# 3. Confirm: Type "DESTROY-AND-REPLACE"
```

**Result**:
- Fresh Ubuntu 22.04 installation
- Same IP address preserved
- SSH keys intact
- Ready to use in ~15 minutes

### Scenario 2: CentOS 7 to AlmaLinux 8 Migration

**Use Case**: Migrate from EOL CentOS 7 to AlmaLinux 8 on Azure

```bash
sudo ./distro-migrator.sh

# Menu selections:
# 1. Select distribution: 3 (AlmaLinux)
# 2. Select version: 2 (8)
# 3. Confirm: Type "DESTROY-AND-REPLACE"
```

**Result**:
- Modern AlmaLinux 8 system
- Network configuration preserved
- No downtime in SSH access after reboot

### Scenario 3: Debian to Ubuntu Migration

**Use Case**: Switch from Debian 11 to Ubuntu 22.04 on Google Cloud

```bash
sudo ./distro-migrator.sh

# Menu selections:
# 1. Select distribution: 1 (Ubuntu)
# 2. Select version: 2 (22.04)
# 3. Confirm: Type "DESTROY-AND-REPLACE"
```

**Why?**
- Need Ubuntu-specific packages
- Better commercial support
- Specific version requirements

### Scenario 4: Fedora to Rocky Linux

**Use Case**: Move from Fedora (rapid release) to Rocky Linux (stable) on Oracle Cloud

```bash
sudo ./distro-migrator.sh

# Menu selections:
# 1. Select distribution: 4 (Rocky Linux)
# 2. Select version: 1 (9)
# 3. Confirm: Type "DESTROY-AND-REPLACE"
```

**Benefit**:
- Long-term stability
- Enterprise support
- Longer maintenance cycles

## Cloud Provider Examples

### AWS EC2 Example

```bash
# On AWS EC2 instance (Ubuntu 20.04 → Ubuntu 22.04)

# 1. Connect to instance
ssh ubuntu@ec2-xx-xx-xx-xx.compute.amazonaws.com

# 2. Switch to root
sudo su -

# 3. Download script
wget https://raw.githubusercontent.com/Toton-dhibar/Changeos/main/distro-migrator.sh
chmod +x distro-migrator.sh

# 4. Run migration
./distro-migrator.sh

# 5. After reboot (automatic), reconnect
ssh ubuntu@ec2-xx-xx-xx-xx.compute.amazonaws.com

# 6. Verify new distribution
cat /etc/os-release
```

**Detection Output**:
```
[INFO] Detecting cloud provider...
[✓] Detected AWS
[INFO] Primary interface: eth0
[INFO] Current IP: 172.31.xx.xx
[INFO] Current gateway: 172.31.0.1
```

### Azure VM Example

```bash
# On Azure VM (CentOS 7 → AlmaLinux 8)

# 1. Connect via Azure Portal or SSH
ssh azureuser@xx-xx-xx-xx.cloudapp.azure.com

# 2. Become root
sudo su -

# 3. Run migration
wget https://raw.githubusercontent.com/Toton-dhibar/Changeos/main/distro-migrator.sh
chmod +x distro-migrator.sh
./distro-migrator.sh

# Select AlmaLinux → Version 8 → Confirm

# 4. Wait for automatic reboot (~20 minutes)

# 5. Reconnect and verify
ssh azureuser@xx-xx-xx-xx.cloudapp.azure.com
cat /etc/os-release
```

**Detection Output**:
```
[INFO] Detecting cloud provider...
[✓] Detected Azure
[INFO] Primary interface: eth0
[INFO] Current IP: 10.0.xx.xx
```

### Google Cloud Platform Example

```bash
# On GCP Compute Engine (Debian 11 → Ubuntu 22.04)

# 1. SSH via gcloud or console
gcloud compute ssh instance-name --zone=us-central1-a

# 2. Run as root
sudo su -

# 3. Execute migration
curl -O https://raw.githubusercontent.com/Toton-dhibar/Changeos/main/distro-migrator.sh
chmod +x distro-migrator.sh
./distro-migrator.sh

# Select Ubuntu → 22.04 → Confirm

# 4. After reboot, verify
gcloud compute ssh instance-name --zone=us-central1-a
lsb_release -a
```

**Detection Output**:
```
[INFO] Detecting cloud provider...
[✓] Detected Google Cloud Platform
[INFO] Primary interface: ens4
[INFO] Current IP: 10.128.0.xx
```

### Oracle Cloud Example

```bash
# On Oracle Cloud (Fedora 38 → Rocky Linux 9)

# 1. Connect via SSH
ssh opc@xxx.xxx.xxx.xxx

# 2. Switch to root
sudo su -

# 3. Download and run
wget https://raw.githubusercontent.com/Toton-dhibar/Changeos/main/distro-migrator.sh
chmod +x distro-migrator.sh
./distro-migrator.sh

# Select Rocky Linux → 9 → Confirm
```

**Detection Output**:
```
[INFO] Detecting cloud provider...
[✓] Detected Oracle Cloud
[INFO] Primary interface: ens3
```

## Emergency Recovery

### Scenario: Migration Failed - SSH Still Works

If migration fails but you still have SSH access:

```bash
# 1. Check logs
tail -100 /var/log/distro-migration.log

# 2. Check backup
ls -la /tmp/distro-migration-backup/

# 3. Review error
grep ERROR /var/log/distro-migration.log

# 4. Attempt manual recovery or reinstall from cloud console
```

### Scenario: Lost SSH Access

If you lose SSH access after migration:

**Option 1: Cloud Console Access**
```bash
# AWS: Use EC2 Instance Connect or Session Manager
# Azure: Use Serial Console
# GCP: Use Serial Console
# Oracle: Use Cloud Shell

# Once connected:
systemctl status sshd
systemctl start sshd
ip addr show
```

**Option 2: Cloud Provider Recovery Mode**
```bash
# Most providers offer rescue/recovery mode
# Boot into rescue mode
# Mount the root filesystem
# Check/fix network configuration
# Reinstall SSH if needed
```

### Scenario: Boot Failure

If system doesn't boot after migration:

```bash
# 1. Access via cloud console
# 2. Boot into rescue mode
# 3. Mount root partition
mount /dev/xvda1 /mnt

# 4. Fix bootloader
chroot /mnt
grub-install /dev/xvda
update-grub
exit

# 5. Reboot
reboot
```

## Best Practices

### Pre-Migration Checklist

```bash
# 1. Verify you have console access
# AWS: EC2 Instance Connect enabled
# Azure: Serial Console enabled
# GCP: Serial Console enabled
# Oracle: Cloud Shell available

# 2. Note current configuration
ip addr show > /tmp/current-network.txt
cat /etc/os-release > /tmp/current-os.txt
df -h > /tmp/current-disk.txt

# 3. Backup critical data externally
# (Script backup is in /tmp and may be lost)

# 4. Test SSH keys work
ssh-copy-id root@your-server

# 5. Verify network connectivity
ping -c 5 8.8.8.8
curl -I https://ubuntu.com
```

### Post-Migration Checklist

```bash
# 1. Verify distribution
cat /etc/os-release
uname -a

# 2. Check network
ip addr show
ip route show
ping -c 5 8.8.8.8

# 3. Verify SSH
systemctl status sshd
ss -tlnp | grep :22

# 4. Check disk
df -h
mount | grep " / "

# 5. Update system
# Ubuntu/Debian:
apt update && apt upgrade -y

# RHEL/Rocky/Alma:
dnf update -y

# Arch:
pacman -Syu
```

### Safety Recommendations

1. **Test Environment First**
   ```bash
   # Create a test VM with same configuration
   # Run migration on test VM first
   # Verify everything works
   # Then proceed with production
   ```

2. **Timing**
   ```bash
   # Run during maintenance window
   # Avoid peak hours
   # Have rollback plan ready
   ```

3. **Documentation**
   ```bash
   # Document current state
   # Document migration steps
   # Document any issues encountered
   # Update runbooks
   ```

4. **Monitoring**
   ```bash
   # Monitor during migration
   # Watch logs in real-time:
   tail -f /var/log/distro-migration.log
   
   # Check for errors:
   grep -i error /var/log/distro-migration.log
   ```

## Advanced Use Cases

### Automated Migration (Scripted)

```bash
#!/bin/bash
# Automated migration with predetermined choices

# Download script
wget -q https://raw.githubusercontent.com/Toton-dhibar/Changeos/main/distro-migrator.sh
chmod +x distro-migrator.sh

# Note: Script requires interactive input
# For automation, you would need to modify the script
# or use tools like 'expect' to automate responses

# Example with expect (not recommended for production):
# expect << EOF
# spawn ./distro-migrator.sh
# expect "Enter your choice"
# send "1\r"
# expect "Enter your choice"  
# send "2\r"
# expect "Type 'DESTROY-AND-REPLACE'"
# send "DESTROY-AND-REPLACE\r"
# expect eof
# EOF
```

### Migration with Custom Backup

```bash
# Create external backup before migration
tar -czf /backup/system-backup-$(date +%Y%m%d).tar.gz \
  /etc \
  /home \
  /root \
  /var/www

# Upload to S3/Azure Storage/GCS
aws s3 cp /backup/system-backup-*.tar.gz s3://my-bucket/

# Then run migration
./distro-migrator.sh
```

### Migration Validation Script

```bash
#!/bin/bash
# Post-migration validation

echo "=== Distribution ==="
cat /etc/os-release | grep PRETTY_NAME

echo -e "\n=== Network ==="
ip addr show | grep "inet "
ip route show | grep default

echo -e "\n=== SSH ==="
systemctl status sshd | grep Active

echo -e "\n=== Disk ==="
df -h /

echo -e "\n=== Services ==="
systemctl list-units --type=service --state=running | head -10

echo -e "\n=== Kernel ==="
uname -a
```

## Troubleshooting Examples

### Network Not Working After Reboot

```bash
# Check interface status
ip link show

# Check if interface is up
ip link set eth0 up

# Check network configuration
cat /etc/netplan/01-netcfg.yaml  # Ubuntu/Debian
cat /etc/sysconfig/network-scripts/ifcfg-eth0  # RHEL

# Restart networking
systemctl restart networking  # Debian
systemctl restart NetworkManager  # RHEL/Arch
netplan apply  # Ubuntu
```

### SSH Not Starting

```bash
# Check SSH status
systemctl status sshd

# Check SSH config
sshd -t

# Check logs
journalctl -u sshd -n 50

# Restart SSH
systemctl restart sshd
```

### Different Interface Name

```bash
# If interface name changed (eth0 → ens3)
ip link show

# Update network config with new interface name
# Edit appropriate config file for your distro
```

## Summary

The distro-migrator.sh script provides a powerful way to completely replace your Linux distribution while maintaining connectivity. Always:

1. Have backup access (cloud console)
2. Test in non-production first
3. Backup critical data externally
4. Plan for potential issues
5. Document everything

**Remember: This is a destructive operation. Plan carefully and test thoroughly!**
