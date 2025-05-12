// ------------------------------------------------------------------
// Terraform module: ./modules/test-infra/main.tf
// Author: Jesus Natividad Rodriguez A, MIT license
// Date: May 2025
// To execute: 
// ------------------------------------------------------------------

terraform {
  required_version = ">= 1.1"
  required_providers {
    external = {
      source  = "hashicorp/external"
      version = ">= 2.1"
    }
  }
}

locals {
  bridge_operstate_file = "/sys/class/net/${var.bridge_name}/operstate"
  bridge_exists         = fileexists(local.bridge_operstate_file) && trimspace(chomp(file(local.bridge_operstate_file))) != ""
}

# Resolve IPs in-memory using external data source
data "external" "vm_ips" {
  for_each = toset(var.vm_name)

  program = [
    "bash", "-c", <<-EOF
      set -e
      ip=$(nslookup ${each.key} 2>/dev/null | awk '/^Address: / { print $2 }' | tail -n1)
      if [ -z "$ip" ]; then
        echo '{"ip":"unresolved"}'
      else
        printf '{"ip":"%s"}\n' "$ip"
      fi
    EOF
  ]
}

# Run curl to NGINX LB and capture response
data "external" "nginx_response" {
  program = [
    "bash", "-c", <<-EOF
      resp=$(curl -s --retry 3 --retry-delay 5 http://${var.load_balancer_ip}:${var.load_balancer_port})
      if [ -z "$resp" ]; then
        echo '{"response":"no response"}'
        exit 0
      fi
      # Encode response using base64 to safely handle newlines and quotes
      b64_resp=$(echo "$resp" | base64 -w 0)
      echo "{\"response_b64\":\"$b64_resp\"}"
    EOF
  ]
}

# Output map of VM name -> IP
output "vm_ip_map" {
  value = {
    for name in var.vm_name :
    name => data.external.vm_ips[name].result.ip
  }
}

# Output NGINX response
output "nginx_response" {
  value       = base64decode(data.external.nginx_response.result.response_b64)
  description = "Raw NGINX response body"
}


# Output bridge status
output "bridge_check_status" {
  value = local.bridge_exists ? "Bridge ${var.bridge_name} exists" : "Bridge ${var.bridge_name} does not exist"
}

# Output a combined formatted report
output "nginx_test_report" {
  value = <<EOT
# NGINX Load Balancer Test Report

Bridge status: ${local.bridge_exists ? "Bridge ${var.bridge_name} exists" : "Bridge ${var.bridge_name} does not exist"}

Resolved VM IPs:
%{ for name in var.vm_name ~}
- ${name}: ${data.external.vm_ips[name].result.ip}
%{ endfor ~}

NGINX Response:
${base64decode(data.external.nginx_response.result.response_b64)}
EOT
}

