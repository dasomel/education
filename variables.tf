# Variables for Kakao Cloud Terraform Configuration
variable "vm_image" { type = string }
variable "vm_network_cidr" { type = string }

variable "was_vm_name" { default = "was-vm" }
variable "web_vm_name" { default = "web-vm" }
variable "was_vm_flavor" { default = "t1i.medium" }
variable "web_vm_flavor" { default = "t1i.medium" }
variable "instance_keypair" { type = string }

variable "vm_network_name" { type = string }
variable "floating_network_name" { type = string }
variable "vm_subnet_name" { type = string }