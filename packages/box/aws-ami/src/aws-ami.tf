terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    time = {
      source  = "hashicorp/time"
      version = "~> 0.9"
    }
  }
}

variable "ami_name" {
  description = "Name for the resulting AMI"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "disk_image" {
  description = "Path to the disk image to import"
  type        = string
  default     = "/disk.img"
}

# --- Provider ---
provider "aws" {
  region = var.region
}

# --- S3 bucket for image upload ---
resource "aws_s3_bucket" "images" {
  bucket = "stagex-ami-${replace(var.ami_name, "/", "-")}-${formatdate("YYYYMMDDhhmmss", timestamp())}"

  tags = {
    Name      = var.ami_name
    ManagedBy = "stagex"
    Box       = "aws-ami"
  }
}

resource "aws_s3_bucket_public_access_block" "images" {
  bucket = aws_s3_bucket.images.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# --- Use existing VM Import role ---
data "aws_iam_role" "vmimport" {
  name = "vmimport"
}

# --- Add policy to VM Import role for this bucket ---
resource "aws_iam_role_policy" "vmimport" {
  name = "vmimport-s3-policy-${formatdate("YYYYMMDDhhmmss", timestamp())}"
  role = data.aws_iam_role.vmimport.id

  policy = <<POLICY
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:*"
      ],
      "Resource": "*"
    },
    {
      "Effect": "Allow",
      "Action": [
        "ec2:*"
      ],
      "Resource": "*"
    }
  ]
}
POLICY
}

# --- Upload disk image to S3 ---
resource "aws_s3_object" "disk" {
  bucket = aws_s3_bucket.images.id
  key    = "disk.img"
  source = var.disk_image

  tags = {
    ManagedBy = "stagex"
    Box       = "aws-ami"
  }
}

# --- Wait for IAM policy propagation ---
resource "time_sleep" "wait_for_iam" {
  depends_on = [aws_iam_role_policy.vmimport]
  create_duration = "60s"
}

# --- Import snapshot from S3 ---
resource "aws_ebs_snapshot_import" "disk" {
  depends_on = [aws_s3_object.disk, time_sleep.wait_for_iam]

  description = var.ami_name

  role_name = data.aws_iam_role.vmimport.name

  tags = {
    Name      = "${var.ami_name}-snapshot"
    ManagedBy = "stagex"
    Box       = "aws-ami"
  }

  disk_container {
    format = "RAW"
    user_bucket {
      s3_bucket = aws_s3_bucket.images.id
      s3_key    = aws_s3_object.disk.id
    }
  }
}

# --- Register AMI from snapshot ---
resource "aws_ami" "this" {
  name        = var.ami_name
  description = "StageX distro AMI"

  ebs_block_device {
    snapshot_id = aws_ebs_snapshot_import.disk.id
    device_name = "/dev/xvda"
    volume_size = 20
    volume_type = "gp3"
  }

  root_device_name    = "/dev/xvda"
  virtualization_type = "hvm"
  architecture        = "x86_64"
  ena_support         = true

  tags = {
    Name      = var.ami_name
    ManagedBy = "stagex"
    Box       = "aws-ami"
  }
}

# --- Outputs ---
output "ami_id" {
  description = "The AMI ID"
  value       = aws_ami.this.id
}

output "ami_arn" {
  description = "The AMI ARN"
  value       = "arn:aws:ec2:${var.region}::image/${aws_ami.this.id}"
}

output "snapshot_id" {
  description = "The EC2 snapshot ID"
  value       = aws_ebs_snapshot_import.disk.id
}
