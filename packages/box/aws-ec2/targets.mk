# AWS EC2 deploy target — launches instance from AMI

.PHONY: aws-ec2-deploy aws-ec2-status

EC2_KEY_NAME ?= tpm-exploration-key
EC2_INSTANCE_TYPE ?= m5.large
EC2_SUBNET_ID ?= subnet-0521e4b4404277d91
EC2_SECURITY_GROUP ?= sg-00b5e3de841fbfe7a
EC2_SSH_KEY ?= ~/.ssh/tpm-exploration.pem
EC2_USER_DATA_FILE ?=

# AMI tfvars file — produced by aws-ami-deploy
EC2_AMI_TFVARS := $(CURDIR)/out/aws-ami.tfvars
# EC2 instance tfvars file — produced by aws-ec2-deploy
EC2_EC2_TFVARS := $(CURDIR)/out/aws-ec2.tfvars

# Validate AWS credentials
define check_aws_creds
	@if [ -z "$(AWS_ACCESS_KEY_ID)" ] || [ -z "$(AWS_SECRET_ACCESS_KEY)" ]; then \
		echo "ERROR: AWS_ACCESS_KEY_ID and AWS_SECRET_ACCESS_KEY required" >&2; \
		exit 1; \
	fi
endef

# Deploy EC2 instance from AMI
aws-ec2-deploy:
	@$(check_aws_creds)
	@if [ ! -f "$(EC2_AMI_TFVARS)" ]; then \
		echo "ERROR: No AMI tfvars found — run 'make aws-ami-deploy' first" >&2; exit 1; \
	fi
	@AMI_ID=$$(grep '^ami_id' $(EC2_AMI_TFVARS) | cut -d'"' -f2) && \
	echo "Deploying EC2 instance from AMI $$AMI_ID ..." && \
	USER_DATA="" && \
	if [ -n "$(EC2_USER_DATA_FILE)" ] && [ -f "$(EC2_USER_DATA_FILE)" ]; then \
		USER_DATA=$$(cat "$(EC2_USER_DATA_FILE)"); \
	elif [ -f ~/.ssh/tpm-exploration.pem ]; then \
		USER_DATA=$$(ssh-keygen -y -f ~/.ssh/tpm-exploration.pem); \
	elif [ -f ~/.ssh/id_rsa.pub ]; then \
		USER_DATA=$$(cat ~/.ssh/id_rsa.pub); \
	fi && \
	docker run --rm \
		-e AWS_ACCESS_KEY_ID="$(AWS_ACCESS_KEY_ID)" \
		-e AWS_SECRET_ACCESS_KEY="$(AWS_SECRET_ACCESS_KEY)" \
		-e REGION="$(EC2_REGION)" \
		-e KEY_NAME="$(EC2_KEY_NAME)" \
		-e INSTANCE_TYPE="$(EC2_INSTANCE_TYPE)" \
		-e SUBNET_ID="$(EC2_SUBNET_ID)" \
		-e SECURITY_GROUP="$(EC2_SECURITY_GROUP)" \
		-e USER_DATA="$$USER_DATA" \
		-e AMI_TFVARS=/input/aws-ami.tfvars \
		-v $(EC2_AMI_TFVARS):/input/aws-ami.tfvars:ro \
		stagex/box-aws-ec2:local /usr/bin/box 2>/dev/null \
		> $(EC2_EC2_TFVARS) && \
	PUBLIC_IP=$$(grep '^public_ip' $(EC2_EC2_TFVARS) | cut -d'"' -f2) && \
	INSTANCE_ID=$$(grep '^instance_id' $(EC2_EC2_TFVARS) | cut -d'"' -f2) && \
	echo "" && \
	echo "=== EC2 Instance ===" && \
	echo "  instance:   $$INSTANCE_ID" && \
	echo "  public-ip:  $$PUBLIC_IP" && \
	echo "  ami:        $$AMI_ID" && \
	echo "" && \
	echo "  ssh -i $(EC2_SSH_KEY) root@$$PUBLIC_IP"

# Show current EC2 instance status
aws-ec2-status:
	@if [ ! -f "$(EC2_EC2_TFVARS)" ]; then \
		echo "No EC2 instance deployed — run 'make aws-ec2-deploy'" >&2; exit 1; \
	fi
	@PUBLIC_IP=$$(grep '^public_ip' $(EC2_EC2_TFVARS) | cut -d'"' -f2) && \
	INSTANCE_ID=$$(grep '^instance_id' $(EC2_EC2_TFVARS) | cut -d'"' -f2) && \
	AMI_ID=$$(grep '^ami_id' $(EC2_AMI_TFVARS) | cut -d'"' -f2) && \
	echo "=== EC2 Instance ===" && \
	echo "  instance:   $$INSTANCE_ID" && \
	echo "  public-ip:  $$PUBLIC_IP" && \
	echo "  ami:        $$AMI_ID" && \
	echo "" && \
	echo "  ssh -i $(EC2_SSH_KEY) root@$$PUBLIC_IP"
