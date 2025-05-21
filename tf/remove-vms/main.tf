// ------------------------------------------------------------------
// Terraform module: remove-vms
// Author: Jesus Natividad Rodriguez A, MIT license
// Date: May 2025
// ------------------------------------------------------------------

terraform {
  required_version = ">= 1.0"
  required_providers {
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0"
    }
  }
}

# Check VMs running state or existence before removing
resource "null_resource" "check_and_remove_vms" {
  for_each = toset(var.vm_names)
  provisioner "local-exec" {
    command = <<EOT
      if virsh list --all | grep -wq ${each.key}; then
        echo "VM exists: ${each.key}"
        virsh destroy ${each.key} 2>/dev/null || true
        virsh undefine ${each.key} --remove-all-storage 2>/dev/null || true
      else
        echo "VM was removed: ${each.key}"
      fi
    EOT
  }
}

# Cleanup nginx symbolic links before removing nginx
resource "null_resource" "cleanup_symlinks_and_services" {
  provisioner "local-exec" {
    command = <<EOT
      # Remove nginx symlink if exists
      if [ -L /etc/nginx/sites-enabled/openshift-cluster ]; then
        sudo rm -f /etc/nginx/sites-enabled/openshift-cluster
      fi

      if [ -e "${var.nginx_config_path}" ]; then
        sudo rm -f "${var.nginx_config_path}"
      fi

      # Stop nginx if active
      if systemctl is-active --quiet nginx; then
        sudo systemctl stop nginx
        sudo systemctl disable nginx
      fi
    EOT
  }
}

# Removing VM entries from /etc/hosts file
resource "null_resource" "clean_hosts_file" {
  provisioner "local-exec" {
    command = <<EOT
      sudo cp /etc/hosts /etc/hosts.bak
      grep -Ev "${join("|", var.vm_names)}" /etc/hosts > ./hosts.cleaned || true
      sudo mv -f ./hosts.cleaned /etc/hosts
      echo "/etc/hosts was updated to remove entries for: ${join(", ", var.vm_names)}"

      # Remove lines starting with host_ip
      grep -Ev "^${var.host_ip}[[:space:]]" /etc/hosts > ./hosts.cleaned || true
      sudo mv -f ./hosts.cleaned /etc/hosts
      echo "/etc/hosts was successfully updated by replacing it with ./hosts.cleaned"
    EOT
  }
}

# Forcing DHCP IP release for removed VMs
resource "null_resource" "truncate_virbr0_status" {
  provisioner "local-exec" {
    command = "sudo truncate -s 0 /var/lib/libvirt/dnsmasq/virbr0.status"
  }
}
