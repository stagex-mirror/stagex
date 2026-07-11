variable "ami_name" {
  description = "Name for the resulting AMI"
  type        = string
}

variable "region" {
  description = "AWS region"
  type        = string
}

variable "image_path" {
  description = "Path to the disk image on the local filesystem"
  type        = string
  default     = "/system.img"
}

variable "bucket_name" {
  description = "S3 bucket name (will be created if needed)"
  type        = string
}

locals {
  timestamp = regex_replace(timestamp(), "[- TZ:]", "")
}

# --- S3 bucket for the image ---
resource "aws_s3_bucket" "images" {
  bucket = "${var.bucket_name}-${local.timestamp}"

  tags = {
    Name      = "stagex-images-${local.timestamp}"
    ManagedBy = "stagex"
    Box       = "aws-ami"
  }
}

resource "aws_s3_bucket_versioning" "images" {
  bucket = aws_s3_bucket.images.id
  versioning_configuration {
    status = "Disabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "images" {
  bucket = aws_s3_bucket.images.id
  rule {
    id     = "cleanup"
    status = "Enabled"
    expiration {
      days = 1
    }
  }
}

# --- Upload local image to S3 ---
resource "aws_s3_object" "image" {
  bucket = aws_s3_bucket.images.id
  key    = basename(var.image_path)
  source = var.image_path

  tags = {
    ManagedBy = "stagex"
    Box       = "aws-ami"
  }
}

# --- Import image from S3 to EC2 ---
resource "aws_ec2_import_image" "this" {
  depends_on = [aws_s3_object.image]

  platform = "Linux"

  s3_volume {
    s3_bucket = aws_s3_bucket.images.id
    s3_key    = aws_s3_object.image.id
    format    = "raw"
  }

  tag_specifications {
    resource_type = "image"
    tags = {
      Name      = var.ami_name
      ManagedBy = "stagex"
      Box       = "aws-ami"
      Timestamp = local.timestamp
    }
  }
}

# --- Outputs ---
output "ami_id" {
  description = "The AMI ID"
  value       = aws_ec2_import_image.this.image_id
}

output "ami_arn" {
  description = "The AMI ARN"
  value       = "arn:aws:ec2:${var.region}::image/${aws_ec2_import_image.this.image_id}"
}

output "s3_bucket" {
  description = "S3 bucket used for the upload (auto-deletes after 1 day)"
  value       = aws_s3_bucket.images.id
}
