#!/bin/bash
set -x
export DEBIAN_FRONTEND=noninteractive

# --- Swap FIRST, before any memory-heavy operations ---
if [ ! -f /swapfile ]; then
  fallocate -l 2G /swapfile || dd if=/dev/zero of=/swapfile bs=1M count=2048
  chmod 600 /swapfile
  mkswap /swapfile
  swapon /swapfile
  grep -q '/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

# --- Package updates, now with swap active as a safety net ---
apt-get update
apt-get dist-upgrade -y
apt-get autoremove -y

# --- Kubernetes networking prerequisites ---
modprobe br_netfilter
cat <<EOF > /etc/sysctl.d/99-kubernetes.conf
net.ipv4.ip_forward = 1
net.bridge.bridge-nf-call-iptables = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.conf.all.rp_filter = 2
net.ipv4.conf.default.rp_filter = 2
EOF
sysctl --system

# --- Disable netfilter-persistent AND clear whatever it already loaded ---
# (stopping/disabling the service alone doesn't remove rules already
#  active in the kernel from early boot — this is what bit us)
systemctl stop netfilter-persistent 2>/dev/null || true
systemctl disable netfilter-persistent 2>/dev/null || true

# Flush the default-deny baseline rules the hardened image ships with,
# but only if no Kubernetes rules exist yet (avoid wiping k3s's own
# rules on a re-run of this script post-cluster-install)
if ! iptables -L INPUT -n | grep -q "kubernetes"; then
  iptables -P INPUT ACCEPT
  iptables -P FORWARD ACCEPT
  iptables -P OUTPUT ACCEPT
  iptables -F INPUT
  iptables -F FORWARD
  # Re-add baseline sane rules (SSH, established, loopback, icmp)
  iptables -A INPUT -i lo -j ACCEPT
  iptables -A INPUT -m state --state RELATED,ESTABLISHED -j ACCEPT
  iptables -A INPUT -p icmp -j ACCEPT
  iptables -A INPUT -p tcp --dport 22 -j ACCEPT
fi

netfilter-persistent save 2>/dev/null || true

# --- Persistent MTU via netplan, not just runtime ip link ---
# Check your actual netplan filename with: ls /etc/netplan/
cat <<EOF > /etc/netplan/99-mtu.yaml
network:
  version: 2
  ethernets:
    ens3:
      mtu: 1400
EOF
netplan apply

# --- Auto-fix k3s's own firewall rules every time k3s starts ---
# k3s (specifically kube-router) inserts a default-deny REJECT rule into
# FORWARD on every start, even with --disable-network-policy. This service
# waits for k3s to start, then removes that rule and ensures the ports
# k3s/flannel need are explicitly accepted in INPUT. Runs on every boot
# and every k3s restart, whether k3s is installed manually later or via
# cloud-init in the future.
cat <<'EOF' > /etc/systemd/system/k3s-fw-fix.service
[Unit]
Description=Fix k3s iptables REJECT rules
After=k3s.service
Requires=k3s.service

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'iptables -D FORWARD -j REJECT --reject-with icmp-host-prohibited 2>/dev/null; iptables -C INPUT -p tcp --dport 6443 -j ACCEPT 2>/dev/null || iptables -I INPUT -p tcp --dport 6443 -j ACCEPT; iptables -C INPUT -p tcp --dport 10250 -j ACCEPT 2>/dev/null || iptables -I INPUT -p tcp --dport 10250 -j ACCEPT; iptables -C INPUT -p udp --dport 8472 -j ACCEPT 2>/dev/null || iptables -I INPUT -p udp --dport 8472 -j ACCEPT'
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable k3s-fw-fix.service