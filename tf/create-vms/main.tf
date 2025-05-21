// ------------------------------------------------------------------
// Terraform module: create_kvm_vms
// Author: Jesus Natividad Rodriguez A, MIT license
// Date: May 2025
// ------------------------------------------------------------------

terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = ">= 0.7.1"
    }
    null = {
      source  = "hashicorp/null"
      version = ">= 3.2.0"
    }
    local = {
      source  = "hashicorp/local"
      version = ">= 2.0.0"
    }
    external = {
      source  = "hashicorp/external"
      version = ">= 2.1.0"
    }
  }

  required_version = ">= 1.1.0"
}
variable "kickstart_host" {
  default = "192.168.1.246:8000"
}
# Create kickstart cfg files:
resource "local_file" "kickstart_cfg" {
  for_each = toset(var.vm_names)
  content  = templatefile("${path.root}/templates/ks.cfg.tmpl", {
    vm_name       = each.key,
    vm_user       = var.vm_user,
    vm_user_pwd   = var.vm_user_pwd
  })
  filename = "${var.kickstart_path}/ks_${each.key}.cfg"
}

# Generate deterministic MACs using 52:54:00:XX:YY:ZZ
locals {
  vm_mac_map = {
    for idx, name in var.vm_names :
    name => format("52:54:00:%02x:%02x:%02x", 0, 0, idx + 1)
  }
}

# ------------------
# Cleanup virbr0.status before provisioning
# ------------------
#resource "null_resource" "clear_status" {
#  provisioner "local-exec" {
#    command = "sudo truncate -s 0 /var/lib/libvirt/dnsmasq/${var.bridge_name}.status"
#  }
#}
#-----------------------------------------------------------------
# Install and run python http server to render kickstart cfg files
#-----------------------------------------------------------------
resource "null_resource" "create_cfg" {
  for_each = toset(var.vm_names)
  provisioner "local-exec" {
    command = <<EOT
    #!/bin/bash

    # Ensure kickstart directory exists
    # sudo mkdir -p ${var.kickstart_path}

    # Allow firewall port for kickstart HTTP server
    sudo ufw allow ${var.python_port}/tcp || true

    # Create systemd service to serve ks files
    sudo tee /etc/systemd/system/ks_http_server.service > /dev/null <<SERVICE
    [Unit]
    Description=Kickstart file HTTP server on port ${var.python_port}
    After=network.target

    [Service]
    WorkingDirectory=${var.kickstart_path}
    ExecStart=nohup /usr/bin/python3 -m http.server ${var.python_port} --directory ${var.kickstart_path} > ${var.kickstart_path}/kickstart_server.log 2>&1 &
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
    fi
    EOT
  }
}

# ------------------
# Create VMs
# ------------------
resource "null_resource" "create_vms" {
  for_each = toset(var.vm_names)

  depends_on = [null_resource.create_cfg]

  provisioner "local-exec" {
    command = <<EOT
      echo "Creating VM ${each.key}"
      sudo virt-install \
        --name ${each.key} \
        --ram ${var.vm_master_memory} \
        --vcpus ${var.vm_master_vcpu} \
        --disk path=${var.disk_dir}/${each.key}.qcow2,size=20,bus=virtio \
        --os-variant ${var.vm_base_os} \
        --network bridge=${var.bridge_name},mac=${local.vm_mac_map[each.key]} \
        --graphics none \
        --console pty,target_type=serial \
        --location ${var.iso_image_path} \
        --extra-args "inst.text console=ttyS0,115200n8 inst.ks=http://${var.kickstart_host}/ks_${each.key}.cfg" \
        --noautoconsole

      echo "Waiting for DHCP lease for ${each.key}..."
      sleep 60

      echo "--- virbr0.status after ${each.key} ---"
      cat /var/lib/libvirt/dnsmasq/${var.bridge_name}.status
    EOT
  }
}

# ------------------
# Extract IP using MAC match from virbr0.status
# ------------------
data "external" "vm_network_info" {
  for_each = toset(var.vm_names)

  depends_on = [null_resource.create_vms]

  program = [
    "bash", "-c", <<-EOF
      mac="${local.vm_mac_map[each.key]}"
      ip=$(jq -r --arg mac "$mac" '.[] | select(."mac-address" == $mac) | ."ip-address"' /var/lib/libvirt/dnsmasq/${var.bridge_name}.status)
      echo "{\"ip\": \"$ip\", \"mac\": \"$mac\"}"
    EOF
  ]
}

# Extracts VM IP and hostname from /var/lib/libvirt/dnsmasq/virbr0.status
# Replaces any existing line in /etc/hosts that matches the hostname
# Appends it if no existing line is found
resource "null_resource" "update_hosts" {
  for_each = toset(var.vm_names)
  provisioner "local-exec" {
    command = <<EOT
      echo "Extracting IP for ${each.key}..."
                                                                  
      ip=$(cat /var/lib/libvirt/dnsmasq/${var.bridge_name}.status | jq -r '.[] | select(.hostname == "${each.key}") | .["ip-address"]')
      ip_clean=$(echo "$ip" | tr -d '\r\n ')

      if [ -n "$ip_clean" ]; then
        echo "Updating /etc/hosts with $ip_clean ${each.key}"
        sudo sed -i.bak "/[[:space:]]${each.key}\\b/d" /etc/hosts
        echo "$ip_clean ${each.key}" | sudo tee -a /etc/hosts > /dev/null
      else
        echo "No IP found using jq/tail for ${each.key}"
      fi
    EOT
  }
}

# ------------------
# VM created
# ------------------
output "vm_network_table" {
  value = concat(
    [
      "VM Name",
      "--------"
    ],
    [
      for name in var.vm_names : name
    ]
  )
}
