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

// Check if each VM exists
resource "null_resource" "vm_check" {
  for_each = toset(var.vm_name)

  provisioner "local-exec" {
    command = "virsh list --all | grep -w ${each.key} && echo VM exists: ${each.key} || echo VM was removed: ${each.key}"
  }
}

// Destroy each VM silently if it exists
resource "null_resource" "destroy_vms" {
  for_each = toset(var.vm_name)

  provisioner "local-exec" {
    command = "virsh destroy ${each.key} 2>/dev/null || true"
  }
}

// Undefine and remove storage for each VM
resource "null_resource" "undefine_vms" {
  for_each = toset(var.vm_name)

  provisioner "local-exec" {
    command = "virsh undefine ${each.key} --remove-all-storage 2>/dev/null || true"
  }
  depends_on = [null_resource.destroy_vms]
}

// Final check
resource "null_resource" "final_check" {
  for_each = toset(var.vm_name)

  provisioner "local-exec" {
    command = "virsh list --all | grep -w ${each.key} && echo VM still exists: ${each.key} || echo VM has been removed: ${each.key}"
  }
  depends_on = [null_resource.undefine_vms]
}

output "vm_removal_status" {
  value = [for name in var.vm_name : "Checked: ${name}" ]
  description = "Basic confirmation loop for VM cleanup"
}

// Removing symlink for nginx
resource "null_resource" "remove_nginx_symlinks" {
  provisioner "local-exec" {
    command = <<EOT
      #!/bin/bash
      set -e

      SYMLINK="/etc/nginx/sites-enabled/openshift-cluster"
      CUSTOM_LINK="${var.nginx_config_path}"

      # Remove if SYMLINK exists and is a symbolic link
      if [ -L "$SYMLINK" ]; then
        echo "Removing broken or circular symlink: $SYMLINK"
        sudo rm -f "$SYMLINK"
      fi

      # Remove the custom site config path if it's a symlink or file
      if [ -e "$CUSTOM_LINK" ]; then
        echo "Removing NGINX config at: $CUSTOM_LINK"
        sudo rm -f "$CUSTOM_LINK"
      fi
    EOT
  }
}
