terraform {
  required_providers {
    aws = {
      # Explicit registry.terraform.io host: an unprefixed "hashicorp/aws"
      # resolves to registry.opentofu.org (OpenTofu's default) and the
      # filesystem_mirror in the box script only covers registry.terraform.io,
      # so the unprefixed form falls to the network. With the explicit host
      # tofu resolves the provider from the baked mirror offline (proven
      # in-image, Oct 1). Pinned to the version baked into the image (see
      # Containerfile mirror layout); bump both together.
      source  = "registry.terraform.io/hashicorp/aws"
      version = "6.57.1"
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
  default     = "subnet-0d2a9fba54fb287f3"
}

variable "security_group_id" {
  description = "Security group ID"
  type        = string
  default     = "sg-0ef827fb6200b34a1"
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

variable "data_volume_size" {
  description = "Size in GiB of an extra gp3 data volume (0 = no data volume)"
  type        = number
  default     = 0
}

variable "data_volume_delete_on_termination" {
  description = "Delete the data volume when the instance terminates"
  type        = bool
  default     = true
}

variable "iam_instance_profile" {
  description = "Optional IAM instance profile name to attach (e.g. for a scoped S3 role; null = none)"
  type        = string
  default     = null
}

# --- ACME prerequisites (the bastiond http-01 path) ---
# The bastiond ACME flow (http-01) needs two out-of-band prerequisites that
# the deploy previously did NOT manage: (1) a DNS A record for the bastion
# domain -> the instance's public IP (the DNS poll gates the ACME thread on
# the domain PointsToSelf — A record == lease IP or public IP), and (2) the
# security group's ingress :80 (the ACME validator) + :443 (the HTTPS face).
# Both are now additive + conditional: null zone/domain = no Route53 record
# (back-compat: an existing deploy with no zone is unchanged); the SG rules
# are unconditional (idempotent — a pre-existing rule is not a conflict, the
# provider's fingerprint-based ID only removes rules it created on destroy).

variable "route53_zone_id" {
  description = "Route53 hosted-zone ID for the bastion domain (null = no A record managed; the deploy stays back-compat)"
  type        = string
  default     = null
}

variable "route53_domain" {
  description = "The bastion domain to point at the instance's public IP (null = no A record managed; e.g. acme-test.cautionos.dev)"
  type        = string
  default     = null
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

  root_block_device {
    volume_size = 20
    volume_type = "gp3"
  }

  dynamic "ebs_block_device" {
    for_each = var.data_volume_size > 0 ? [1] : []
    content {
      device_name                    = "/dev/sdf"
      volume_size                    = var.data_volume_size
      volume_type                    = "gp3"
      delete_on_termination          = var.data_volume_delete_on_termination
    }
  }

  metadata_options {
    http_tokens = "optional"
  }

  # null (the default) = no profile; the provider treats a null string as unset
  iam_instance_profile = var.iam_instance_profile

  dynamic "cpu_options" {
    for_each = var.enable_sev_snp ? [1] : []
    content {
      amd_sev_snp = "enabled"
    }
  }

  tags = {
    Name      = var.ami_name
    ManagedBy = "stagex"
    Box       = "aws-ec2"
  }
}

# --- ACME prerequisite (1): the security group's ingress :80 + :443 ---
# The bastiond http-01 validator reaches the guest's :80 challenge face and
# the HTTPS face is :443; both must be open from the world. This is
# ADDITIVE + idempotent: it adds to the pre-existing SG (var.security_group_id)
# without restructuring it. The provider's fingerprint-based ID means a
# pre-existing identical rule is not a conflict, and on destroy only the rules
# this config created are removed (the SG itself is left alone — it is
# pre-existing, not managed here).

resource "aws_security_group_rule" "acme_http80" {
  type              = "ingress"
  from_port         = 80
  to_port           = 80
  protocol          = "tcp"
  security_group_id = var.security_group_id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "ACME http-01 validator (the bastiond :80 challenge face)"
  depends_on        = [aws_instance.this]
}

resource "aws_security_group_rule" "acme_https443" {
  type              = "ingress"
  from_port         = 443
  to_port           = 443
  protocol          = "tcp"
  security_group_id = var.security_group_id
  cidr_blocks       = ["0.0.0.0/0"]
  description       = "HTTPS face (the bastiond :443 vhost)"
  depends_on        = [aws_instance.this]
}

# --- ACME prerequisite (2): the Route53 A record (domain -> public IP) ---
# The DNS poll gates the ACME thread on the domain PointsToSelf (A record ==
# lease IP or public IP). The A record points at the instance's public IP
# (aws_instance.this.public_ip). Conditional: null zone/domain = no record
# (back-compat — an existing deploy with no zone is unchanged). The 60 s TTL
# means a new record is visible within one DNS-poll cycle (the poll re-runs
# every 30 s) after propagation.
resource "aws_route53_record" "acme_a" {
  count = (var.route53_zone_id != null && var.route53_domain != null) ? 1 : 0

  zone_id = var.route53_zone_id
  name    = var.route53_domain
  type    = "A"
  ttl     = 60
  records = [aws_instance.this.public_ip]
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
