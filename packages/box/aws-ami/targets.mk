# AWS AMI deploy target — imports disk image as AMI

.PHONY: aws-ami-deploy aws-ami-status

# Default distro for EC2
EC2_DISTRO ?= enclave-dev
EC2_AMI_NAME ?= stagex-$(EC2_DISTRO)-$(shell date +%Y%m%d-%H%M%S)
EC2_REGION ?= us-east-2

# Built disk image path (extracted from the distro's -img subpackage)
EC2_DISK_IMG := $(CURDIR)/out/disk.img
# Built disk.img this extraction must track. Depends on the -img subpackage
# manifest (real mtime; the disk.img itself carries a deterministic epoch-1
# mtime from the OCI layout and would never compare "newer"). Re-extract
# whenever the distro build is newer, so a stale out/disk.img never reaches
# the AMI.
DISTRO_DISK_SRC := $(CURDIR)/out/rootfs/distro-$(EC2_DISTRO)-img/manifest.txt
# AMI tfvars file — produced by box-aws-ami, consumed by box-aws-ec2
EC2_AMI_TFVARS := $(CURDIR)/out/aws-ami.tfvars

# Validate AWS credentials
define check_aws_creds
	@if [ -z "$(AWS_ACCESS_KEY_ID)" ] || [ -z "$(AWS_SECRET_ACCESS_KEY)" ]; then \
		echo "ERROR: AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY required" >&2; \
		exit 1; \
	fi
endef

# Extract disk image from distro container
# Extract disk image from the distro's exported rootfs (the -img subpackage
# image is scratch + /disk.img with no command, so copy the local export
# instead of docker cp'ing from a container)
$(EC2_DISK_IMG): $(DISTRO_DISK_SRC)
	@echo "Extracting disk.img from distro-$(EC2_DISTRO)-img ..."
	@cp out/rootfs/distro-$(EC2_DISTRO)-img/linux_amd64/disk.img $(EC2_DISK_IMG)
	@echo "  disk.img: $$(ls -lh $(EC2_DISK_IMG) | awk '{print $$5}')"

# Import disk image as AMI via box-aws-ami, capture tfvars output
aws-ami-deploy: $(EC2_DISK_IMG)
	@$(check_aws_creds)
	@echo "Importing AMI from $(EC2_DISK_IMG) ..."
	@echo "  AMI name: $(EC2_AMI_NAME)"
	@echo "  Region: $(EC2_REGION)"
	@docker run --rm \
		-e AWS_ACCESS_KEY_ID="$(AWS_ACCESS_KEY_ID)" \
		-e AWS_SECRET_ACCESS_KEY="$(AWS_SECRET_ACCESS_KEY)" \
		-e AMI_NAME="$(EC2_AMI_NAME)" \
		-e AWS_REGION="$(EC2_REGION)" \
		-e DISK_IMAGE=/disk.img \
		-v $(EC2_DISK_IMG):/disk.img:ro \
		stagex/box-aws-ami:local /usr/bin/box \
		> $(EC2_AMI_TFVARS) && \
	AMI_ID=$$(grep '^ami_id' $(EC2_AMI_TFVARS) | cut -d'"' -f2) && \
	echo "" && \
	echo "=== AMI Created ===" && \
	echo "  ami_id:      $$AMI_ID" && \
	echo "  ami_arn:     $$(grep '^ami_arn' $(EC2_AMI_TFVARS) | cut -d'"' -f2)" && \
	echo "  snapshot_id: $$(grep '^snapshot_id' $(EC2_AMI_TFVARS) | cut -d'"' -f2)"

# Show current AMI status
aws-ami-status:
	@if [ ! -f "$(EC2_AMI_TFVARS)" ]; then \
		echo "No AMI tfvars found — run 'make aws-ami-deploy' first" >&2; exit 1; \
	fi
	@AMI_ID=$$(grep '^ami_id' $(EC2_AMI_TFVARS) | cut -d'"' -f2) && \
	echo "=== AMI ===" && \
	echo "  ami_id:      $$AMI_ID" && \
	echo "  state:       $$(aws ec2 describe-images --image-id $$AMI_ID --query 'Images[0].State' --output text 2>/dev/null || echo unknown)" && \
	echo "  tpm_support: $$(aws ec2 describe-images --image-id $$AMI_ID --query 'Images[0].TpmSupport' --output text 2>/dev/null || echo unknown)"
