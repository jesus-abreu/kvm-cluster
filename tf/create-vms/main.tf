// ------------------------------------------------------------------
// Terraform module: create_kvm_vms
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

resource "local_file" "kickstart_cfg" {
  for_each = toset(var.vm_name)
  content  = templatefile(var.kickstart_template, {
    vm_name       = each.key,
    host_ip       = var.host_ip,
    bridge_name   = var.bridge_name,
    disk_dir      = var.disk_dir,
    install_repo  = var.iso_image_path
  })
  filename = "${var.kickstart_path}/ks_${each.key}.cfg"
}

resource "null_resource" "create_vms" {
  for_each = toset(var.vm_name)

  provisioner "local-exec" {
    command = <<EOT
#!/bin/bash

# Ensure kickstart directory exists
sudo mkdir -p ${var.kickstart_path}

# Allow firewall port for kickstart HTTP server
sudo ufw allow ${var.python_port}/tcp || true

# Create systemd service to serve ks files
sudo tee /etc/systemd/system/ks_http_server.service > /dev/null <<SERVICE
[Unit]
Description=Kickstart file HTTP server on port ${var.python_port}
After=network.target

[Service]
WorkingDirectory=${var.kickstart_path}
ExecStart=/usr/bin/python3 -m http.server ${var.python_port}
Restart=always

[Install]
WantedBy=multi-user.target
SERVICE

sudo systemctl daemon-reexec
sudo systemctl enable ks_http_server
sudo systemctl start ks_http_server

# Create disk image if not already exists
[ -f ${var.disk_dir}/${each.key}.qcow2 ] || \
qemu-img create -f qcow2 ${var.disk_dir}/${each.key}.qcow2 ${var.vm_master_disk}

# Create the VM
sudo virt-install \
  --name ${each.key} \
  --ram ${var.vm_master_memory} \
  --vcpus ${var.vm_master_vcpu} \
  --disk path=${var.disk_dir}/${each.key}.qcow2,size=300,bus=virtio \
  --os-variant ${var.vm_base_os} \
  --network bridge=${var.bridge_name} \
  --graphics none \
  --console pty,target_type=serial \
  --location ${var.iso_image_path} \
  --extra-args "inst.text console=ttyS0,115200n8 inst.ks=http://${var.host_ip}:${var.python_port}/ks_${each.key}.cfg" \
  --noautoconsole
EOT
    interpreter = ["/bin/bash", "-c"]
  }
  depends_on = [local_file.kickstart_cfg]
}

resource "null_resource" "add_hosts_entries" {
  depends_on = [null_resource.create_vms]
  for_each = toset(var.vm_name)

  provisioner "local-exec" {
    command = <<EOT
IP=$(nslookup ${each.key} | awk '/^Address: / { print $2 }' | tail -n1)
[ -n "$IP" ] && echo "$IP    ${each.key}" | sudo tee -a /etc/hosts > /dev/null || echo "No IP found for ${each.key}"
EOT
    interpreter = ["/bin/bash", "-c"]
  }
}

output "vm_provision_status" {
  value       = "VM provisioning and network registration completed"
  description = "Indicates that the VMs were created and registered"
}
