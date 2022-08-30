#!/bin/bash -e
systemctl stop puppet
systemctl stop slurmd &> /dev/null || true
systemctl stop consul &> /dev/null || true
systemctl disable puppet
systemctl disable slurmd &> /dev/null || true
systemctl disable consul &> /dev/null || true
/sbin/ipa-client-install -U --uninstall
rm -rf /etc/puppetlabs
grep nfs /etc/fstab | cut -f 2 | xargs umount
sed -i '/nfs/d' /etc/fstab
systemctl stop syslog
: > /var/log/messages
cloud-init clean --logs
halt -p