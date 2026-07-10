variable "bucket" {
  type = string
}

variable "key" {
  type = string
}

variable "region" {
  type = string
}

variable "ami_name" {
  type = string
}

variable "image_size_bytes" {
  type = number
}

resource "aws_ami" "this" {
  name               = var.ami_name
  virtualization_type = "hvm"

  # Import from S3 using the EC2 Import Image API
  # Requires a role with permissions to import
  # See: https://docs.aws.amazon.com/vm-import/latest/userguide/required-permissions.html

  tags = {
    Name        = var.ami_name
    ManagedBy   = "stagex"
    Box         = "aws-ami"
  }
}

# Create the S3 bucket if it doesn't exist
resource "aws_s3_bucket" "images" {
  bucket = var.bucket
}

# Import the image from S3 to create the AMI
resource "aws_ec2_import_image" "this" {
  platform = "Linux"

  s3_volume {
    s3_bucket = var.bucket
    s3_key    = var.key
    format    = "raw"
  }
}

resource "aws_ami_from_image" "imported" {
  name               = var.ami_name
  source_image_id    = aws_ec2_import_image.this.image_id
  virtualization_type = "hvm"

  tags = {
    Name      = var.ami_name
    ManagedBy = "stagex"
    Box       = "aws-ami"
  }
}

output "ami_id" {
  value = aws_ami_from_image.imported.id
}

output "ami_arn" {
  value = aws_ami_from_image.imported.arn
}

output "s3_bucket" {
  value = aws_s3_bucket_images.bucket
}

output "s3_key" {
  value = var.key
}
