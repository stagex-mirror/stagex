terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
    }
  }
}

variable "ami_id" {
  description = "AMI ID to launch (mutually exclusive with disk_image)"
  type        = string
  default     = null
}

variable "disk_image" {
  description = "Path to disk.img — creates AMI automatically if ami_id not given"
  type        = string
  default     = null
}

variable "ami_name" {
  description = "Name for auto-created AMI (ignored if ami_id provided)"
  type        = string
  default     = "stagex-ec2"
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "subnet_id" {
  description = "Subnet ID"
  type        = string
  default     = "subnet-0521e4b4404277d91"
}

variable "security_group_id" {
  description = "Security group ID"
  type        = string
  default     = "sg-00b5e3de841fbfe7a"
}

variable "key_name" {
  description = "EC2 key pair name"
  type        = string
  default     = "tpm-exploration-key"
}

variable "instance_type" {
  description = "EC2 instance type (c6a.* has TPM2 + SEV-SNP)"
  type        = string
  default     = "c6a.large"
}

variable "user_data" {
  description = "User data script (base64-encoded or plain text)"
  type        = string
  default     = null
}

variable "wait_for_ssh" {
  description = "Whether to wait for SSH port 22 before returning"
  type        = bool
  default     = true
}

variable "enable_sev_snp" {
  description = "Enable SEV-SNP confidential computing (requires c6a/c7a instance types)"
  type        = bool
  default     = true
}

# --- Provider ---
provider "aws" {
  region = var.region
}

# --- Local values ---
locals {
  effective_ami = var.ami_id != null ? var.ami_id : var.disk_image != null ? "ami-from-import" : "ami-id-or-disk-required"
}

# --- AMI from disk image (if needed) ---
# Note: disk→AMI import is handled by the box wrapper script, not Terraform itself
# When disk_image is provided, the box script calls box-aws-ami first, then passes the result as ami_id

resource "aws_instance" "this" {
  ami                    = var.ami_id
  instance_type          = var.instance_type
  subnet_id              = var.subnet_id
  vpc_security_group_ids = [var.security_group_id]
  key_name               = var.key_name
  user_data              = var.user_data

  confidential_computing {
    enabled = var.enable_sev_snp
  }

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  metadata_options {
    http_tokens = "optional"
  }

  tags = {
    Name      = var.ami_name
    ManagedBy = "stagex"
    Box       = "aws-ec2"
  }
}

# --- Outputs ---
output "instance_id" {
  description = "The EC2 instance ID"
  value       = aws_instance.this.id
}

output "public_ip" {
  description = "Public IP address of the instance"
  value       = aws_instance.this.public_ip
}

output "private_ip" {
  description = "Private IP address of the instance"
  value       = aws_instance.this.private_ip
}

output "ami_id" {
  description = "AMI ID used"
  value       = aws_instance.this.ami
}
