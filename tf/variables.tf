// ------------------------------------------------------------------
// Terraform variables for OpenShift KVM cluster deployment
// Author: Jesus Natividad Rodriguez A, MIT license
// Date: May 2025
// file name: variables.tf
// ------------------------------------------------------------------

// Cluster infra and VMs

variable "my_path" {
  default = "."
}

variable "host_ip" {
  description = "Host IP for services and load balancer"
  type        = string
  default     = "192.168.1.246"
}

variable "load_balancer_ip" {
  description = "Load balancer IP"
  type        = string
  default     = "192.168.1.246"
}

variable "host_name" {
  description = "Hostname for the KVM host"
  type        = string
  default     = "data-science"
}

variable "netmask" {
  type    = string
  default = "255.255.255.0"
}

variable "cluster_name" {
  type    = string
  default = "kvm-cluster"
}

variable "cluster_domain" {
  type    = string
  default = "home.com"
}

variable "network_name" {
  type    = string
  default = "openshift-network"
}

variable "bridge_name" {
  type    = string
  default = "virbr0"
}

variable "subnet_ip" {
  type    = string
  default = "192.168.122.0/24"
}

variable "ca_cert_path" {
  type    = string
  default = "/etc/ssl/certs/ocp-apps.crt"
}

variable "ca_cert_key" {
  type    = string
  default = "/etc/ssl/private/ocp-apps.key"
}

variable "ca_cert_name" {
  type    = string
  default = "registry-ca"
}

variable "username" {
  type    = string
  default = "devops"
}

variable "password" {
  type    = string
  default = ""
  sensitive = true
}

variable "nginx_config_path" {
  type    = string
  default = "/etc/nginx/sites-available/openshift-cluster"
}

variable "nginx_config_path_enabled" {
  type    = string
  default = "/etc/nginx/sites-enabled/openshift-cluster"
}

variable "nginx_conf_template" {
  type    = string
  default = "nginx.conf.j2"
}

variable "nginx_url" {
  type    = string
  default = "http://192.168.1.246"
}

variable "load_balancer_port" {
  type    = string
  default = "80"
}

variable "tag" {
  type    = string
  description = "Tag or version for deployment"
  default = ""
}

variable "catalog_source_namespace" {
  type    = string
  default = "openshift-marketplace"
}
variable "vm_nam" {
  type = string
}
variable "vm_names" {
  type    = list(string)
  default = ["vm1", "vm2", "vm3", "vm4"]
}

variable "expected_backends" {
  type    = list(string)
  default = ["vm1", "vm2", "vm3", "vm4"]
}

variable "ocp_hostname" {
  type    = list(string)
  default = ["master1", "master2", "master3", "bootstrap"]
}

variable "vm_user" {
  type    = string
  default = "core"
}

variable "vm_user_pwd" {
  type    = string
  default = "TrustN@1"
  sensitive = true
}

variable "openshift_api" {
  type    = string
  default = "https://192.168.1.246:6443"
}

variable "vm_master_memory" {
  type    = number
  default = 16384
}

variable "vm_master_vcpu" {
  type    = number
  default = 4
}

variable "vm_master_disk" {
  type    = string
  default = "300G"
}

variable "vm_base_os" {
  type    = string
  default = "rhel9.5"
}

variable "kickstart_path" { default = "." }

variable "kickstart_path_Old" {
  type    = string
  default = "/var/lib/libvirt/dvd"
}

variable "iso_image_path" {
  type    = string
  default = "/var/lib/libvirt/dvd/rhel-9.5-x86_64-dvd.iso"
}

variable "disk_dir" {
  type    = string
  default = "/var/lib/libvirt/images/"
}

variable "python_server" { default = "python3 -m http.server" }
variable python_port { default = "8000" }
variable "nginx_dest_path" { default = "" }

