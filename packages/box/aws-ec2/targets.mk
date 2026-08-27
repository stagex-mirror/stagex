# AWS EC2 deploy target — launches instance from AMI

.PHONY: aws-ec2-deploy aws-ec2-status aws-ec2-logs aws-keylime-test aws-destroy

EC2_KEY_NAME ?= tpm-exploration-key
EC2_INSTANCE_TYPE ?= c6a.large
EC2_SUBNET_ID ?= subnet-0d2a9fba54fb287f3
EC2_SECURITY_GROUP ?= sg-0ef827fb6200b34a1
EC2_ENABLE_SEV_SNP ?= true
EC2_DATA_VOLUME_SIZE ?= 0
EC2_DATA_DELETE_ON_TERM ?= true
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

# Deploy EC2 instance from AMI. Depends on aws-ami-deploy (defined in
# packages/box/aws-ami/targets.mk, included into the same make) so a
# single `make aws-ec2-deploy` chains: fresh distro -> AMI import -> launch.
aws-ec2-deploy: aws-ami-deploy
	@$(check_aws_creds)
	@if [ ! -f "$(EC2_AMI_TFVARS)" ]; then \
		echo "ERROR: No AMI tfvars found — aws-ami-deploy did not complete" >&2; exit 1; \
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
		-e ENABLE_SEV_SNP="$(EC2_ENABLE_SEV_SNP)" \
		-e DATA_VOLUME_SIZE="$(EC2_DATA_VOLUME_SIZE)" \
		-e DATA_DELETE_ON_TERM="$(EC2_DATA_DELETE_ON_TERM)" \
		-e USER_DATA="$$USER_DATA" \
		-e AMI_TFVARS=/input/aws-ami.tfvars \
		-v $(EC2_AMI_TFVARS):/input/aws-ami.tfvars:ro \
		stagex/box-aws-ec2:local /usr/bin/box \
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

# Show EC2 instance console output
aws-ec2-logs:
	@if [ ! -f "$(EC2_EC2_TFVARS)" ]; then \
		echo "No EC2 instance deployed — run 'make aws-ec2-deploy'" >&2; exit 1; \
	fi
	@INSTANCE_ID=$$(grep '^instance_id' $(EC2_EC2_TFVARS) | cut -d'"' -f2) && \
	aws ec2 get-console-output --instance-id "$$INSTANCE_ID" --region "$(EC2_REGION)" --query 'Output' --output text 2>/dev/null | base64 -d 2>/dev/null || echo "No console output available yet"

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

# Test keylime agent on deployed EC2 instance (standalone mode)
aws-keylime-test:
	@if [ ! -f "$(EC2_EC2_TFVARS)" ]; then \
		echo "No EC2 instance deployed — run 'make aws-ec2-deploy' first" >&2; exit 1; \
	fi
	@$(check_aws_creds)
	@PUBLIC_IP=$$(grep '^public_ip' $(EC2_EC2_TFVARS) | cut -d'"' -f2) && \
	echo "Testing keylime-agent on $$PUBLIC_IP ..." && \
	SSH_READY=0 && \
	for i in $$(seq 30); do \
		if ssh -o StrictHostKeyChecking=no -o ConnectTimeout=3 -i $(EC2_SSH_KEY) root@$$PUBLIC_IP 'echo ready' >/dev/null 2>&1; then \
			SSH_READY=1; break; \
		fi; \
		echo "  Waiting for SSH... ($$i/30)"; sleep 3; \
	done && \
	if [ "$$SSH_READY" = "0" ]; then \
		echo "ERROR: SSH not ready after 90s" >&2; exit 1; \
	fi && \
	echo "=== Keylime Test ===" && \
	echo "" && \
	echo "[1/4] Checking keylime-agent binary ..." && \
	ssh -o StrictHostKeyChecking=no -i $(EC2_SSH_KEY) root@$$PUBLIC_IP 'ls -lh /usr/bin/keylime_agent' && \
	echo "" && \
	echo "[2/4] Checking TPM2 ..." && \
	ssh -o StrictHostKeyChecking=no -i $(EC2_SSH_KEY) root@$$PUBLIC_IP 'tpm2_getcap handles-persistent 2>/dev/null' && \
	echo "" && \
	echo "[3/4] Reading PCR 7 ..." && \
	ssh -o StrictHostKeyChecking=no -i $(EC2_SSH_KEY) root@$$PUBLIC_IP 'tpm2_pcrread sha256:7' && \
	echo "" && \
	echo "[4/4] Starting keylime-agent (standalone, no registrar) ..." && \
	ssh -o StrictHostKeyChecking=no -i $(EC2_SSH_KEY) root@$$PUBLIC_IP 'pkill -9 keylime_agent 2>/dev/null; sleep 2; rm -f /run/keylime/agent_data.json; mkdir -p /run/keylime/secure /var/log/keylime; nohup /usr/bin/keylime_agent >> /var/log/keylime/keylime-agent.log 2>&1 &' && \
	sleep 15 && \
	echo "Checking agent status ..." && \
	ssh -o StrictHostKeyChecking=no -i $(EC2_SSH_KEY) root@$$PUBLIC_IP 'ps aux | grep keylime_agent | grep -v grep && curl -s --connect-timeout 3 http://localhost:9002/ && echo "" || echo "Agent not yet responding on HTTP"' && \
	echo "" && \
	echo "=== Keylime test complete ===" && \
	echo "" && \
	echo "Agent is running in standalone mode (skip_registration=true)" && \
	echo "API available at http://$$PUBLIC_IP:9002" && \
	echo "" && \
	echo "For remote attestation, clients can query:" && \
	echo "  curl http://$$PUBLIC_IP:9002/quotes" && \
	echo "  curl http://$$PUBLIC_IP:9002/allowlisting-policies"
