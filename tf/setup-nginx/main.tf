// ------------------------------------------------------------------
// Terraform module: manage_nginx_vms
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

# Creating nginx config from template:
resource "local_file" "nginx_config" {
  content = templatefile("${path.root}/templates/nginx.conf.tmpl", {
    vm_names        = var.vm_names
    cluster_name    = var.cluster_name
    cluster_domain  = var.cluster_domain
    ca_cert_path    = var.ca_cert_path
    ca_cert_key     = var.ca_cert_key
  })

  filename = var.nginx_config_path
}

# Installing nginx or upgrading nginx, creating resources for nginx conf, 
# certificates, and reloading nginx
resource "null_resource" "nginx_setup" {
  provisioner "local-exec" {
    command = <<EOT
    #!/bin/bash
    set -e

    # Remove existing certs if they exist
    [ -f ${var.ca_cert_path} ] && sudo rm -f ${var.ca_cert_path}
    [ -f ${var.ca_cert_key} ] && sudo rm -f ${var.ca_cert_key}

    # Generate new self-signed wildcard cert
    sudo openssl req -x509 -nodes -days 365 \
      -newkey rsa:2048 \
      -keyout ${var.ca_cert_key} \
      -out ${var.ca_cert_path} \
      -subj "/CN=*.apps.${var.cluster_name}.${var.cluster_domain}" \
      -addext "subjectAltName=DNS:*.apps.${var.cluster_name}.${var.cluster_domain}"

    # Install or upgrade nginx
    sudo apt update
    sudo apt install -y nginx

    # Create NGINX load balancer configuration file
    sudo cp ${var.nginx_conf_template} ${var.nginx_config_path}

    sudo ln -sf ${var.nginx_config_path} ${nginx_config_path_enabled}

    # Validate nginx config
    sudo nginx -t

    # Restart and reload nginx
    sudo systemctl restart nginx
    sudo systemctl reload nginx
    EOT
    interpreter = ["/bin/bash", "-c"]
  }
}

output "nginx_status" {
  value       = "NGINX load balancer setup completed"
  description = "Status after configuring NGINX as reverse proxy and load balancer"
}
