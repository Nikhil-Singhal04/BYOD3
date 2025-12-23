variable "region" {
  type    = string
  default = "us-east-1"
  description = "The AWS region to deploy to."
}

variable "instance_type" {
  type    = string
  default = "t2.micro"
  description = "The EC2 instance type."
}

variable "ssh_key_name" {
  type        = string
  description = "Name of an existing AWS EC2 Key Pair to attach for SSH (required for Ansible)."
}

variable "allowed_ssh_cidr" {
  type        = string
  default     = "0.0.0.0/0"
  description = "CIDR allowed to SSH to the instance (port 22). Use your public IP /32 for safety."
}

variable "allowed_grafana_cidr" {
  type        = string
  default     = "0.0.0.0/0"
  description = "CIDR allowed to access Grafana (port 3000). Use your public IP /32 for safety."
}