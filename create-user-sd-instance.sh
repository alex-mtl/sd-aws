#!/bin/bash
source helpers.sh
timestamp "Start: "
source config.sh

source reset-session.sh

if ! aws ec2 describe-key-pairs --key-names "$KEY_NAME" &> /dev/null; then
  # Key pair does not exist, create a new one
  # Create a new key pair
  aws ec2 create-key-pair --key-name "$KEY_NAME" --query 'KeyMaterial' --output text > ${KEY_FILE_PATH}

  echo "Key pair '$KEY_NAME' created."
  echo "The private key file 'KEY_FILE_PATH.pem' has been saved."

  mv ${KEY_FILE_PATH} ~/.ssh/${KEY_FILE_PATH}

  # Set appropriate permissions for the .pem file
  chmod 400 ~/.ssh/${KEY_FILE_PATH}
else
  echo "Key pair '$KEY_NAME' already exists."
fi

master_key_id=$(aws configure get aws_access_key_id)
master_secret_access_key=$(aws configure get aws_secret_access_key)

# Check if the user already exists
if ! aws iam get-user --user-name "$SD_AWS_USER" &> /dev/null; then
  # User does not exist, create a new one
  aws iam create-user --user-name "$SD_AWS_USER"
  echo "User '$SD_AWS_USER' created."
else
  echo "User '$SD_AWS_USER' already exists."
fi

ACCOUNT_ID=$(aws sts get-caller-identity --query 'Account' --output text)
echo "Account id: $ACCOUNT_ID"

# Create the IAM policy
# Check if the policy already exists
if ! aws iam get-policy --policy-arn "arn:aws:iam::$ACCOUNT_ID:policy/$POLICY_NAME" &> /dev/null; then
  # Policy does not exist, create a new one
  POLICY_ARN=$(aws iam create-policy --policy-name "$POLICY_NAME" --policy-document file://"$POLICY_FILE" --query 'Policy.Arn' --output text)
  echo "IAM policy $POLICY_NAME created with ARN: $POLICY_ARN"
else
  echo "Policy '$POLICY_NAME' already exists."
  # Retrieve the ARN of the policy
  POLICY_ARN=$(aws iam get-policy --policy-arn "arn:aws:iam::$ACCOUNT_ID:policy/$POLICY_NAME" --query 'Policy.Arn' --output text)
  echo "Policy ARN: $POLICY_ARN"
fi

#Attach security permissions policy to the user
aws iam attach-user-policy --user-name ${SD_AWS_USER} --policy-arn "$POLICY_ARN"
echo "$SD_AWS_USER permissions policy applied"

if [[ -z "${ACCESS_KEY_ID}" ]]; then
  ACCESS_KEY_ID=$(aws iam create-access-key --user-name ${SD_AWS_USER} --query 'AccessKey.AccessKeyId' --output text)
  SECRET_ACCESS_KEY=$(aws iam create-access-key --user-name ${SD_AWS_USER} --query 'AccessKey.SecretAccessKey' --output text)
fi

echo "Switch session to $SD_AWS_USER user"

#Switch session to new user
aws configure set aws_access_key_id "${ACCESS_KEY_ID}"
aws configure set aws_secret_access_key "${SECRET_ACCESS_KEY}"

echo "User $SD_AWS_USER has been created..."
# Use the access_key_id and secret_access_key variables in your script
echo "Access Key ID: $ACCESS_KEY_ID"
echo "Secret Access Key: $SECRET_ACCESS_KEY"

MESSAGE="$INSTANCE_NAME instance is ready."

# Create a new security group (if it doesn't exist)
if ! aws ec2 describe-security-groups --group-names "$SECURITY_GROUP_NAME" &> /dev/null; then
  SECURITY_GROUP_ID=$(aws ec2 create-security-group --group-name "$SECURITY_GROUP_NAME" --description "SD open ports: 22, 7860" --query 'GroupId' --output text)
  echo "Security group '$SECURITY_GROUP_NAME' created. ID: $SECURITY_GROUP_ID"

  # Authorize inbound SSH (port 22) and custom port (7860) access
  aws ec2 authorize-security-group-ingress --group-id "$SECURITY_GROUP_ID" --protocol tcp --port 22 --cidr 0.0.0.0/0
  aws ec2 authorize-security-group-ingress --group-id "$SECURITY_GROUP_ID" --protocol tcp --port 7860 --cidr 0.0.0.0/0
else
  SECURITY_GROUP_ID=$(aws ec2 describe-security-groups --group-names "$SECURITY_GROUP_NAME" --query 'SecurityGroups[0].GroupId' --output text)
  echo "Security group '$SECURITY_GROUP_NAME' already exists. ID: $SECURITY_GROUP_ID"
fi

# Create the instance
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$KEY_NAME" \
  --security-group-ids "$SECURITY_GROUP_ID" \
  --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=$INSTANCE_NAME}]" \
  --output text --query 'Instances[0].InstanceId')

echo "$INSTANCE_NAME instance ($INSTANCE_ID) is being created..."

# Wait for the instance to reach the running state
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
echo "$INSTANCE_NAME instance ($INSTANCE_ID) is now running."
PUBLIC_IP=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=${INSTANCE_NAME}" --region "${REGION}" --query "Reservations[].Instances[].PublicIpAddress" --output text)
echo -e "Public IP: '${C_GREEN}${PUBLIC_IP}${C_RESET}'"

# Wait for the instance to reach the STATUS OK
echo "Wait for the instance to reach the STATUS OK"
aws ec2 wait instance-status-ok --instance-ids "$INSTANCE_ID"
echo "All checks are ok"

echo "Connect to the instance to install Stable Diffusion WEB UI"
ssh -i ~/.ssh/${KEY_FILE_PATH} -o StrictHostKeyChecking=no ubuntu@${PUBLIC_IP}  'bash -s' < install-sd-a1111.sh

# Display the message when the instance is ready
echo "$MESSAGE"

echo "Switch session back to master account"

aws configure set aws_access_key_id "${master_key_id}"
aws configure set aws_secret_access_key "${master_secret_access_key}"

scp -i ~/.ssh/${KEY_FILE_PATH} start.webui.sh ubuntu@${PUBLIC_IP}:start.webui.sh

echo "Connect to the instance to start Stable Diffusion WEB UI"
ssh -i ~/.ssh/${KEY_FILE_PATH} -o StrictHostKeyChecking=no ubuntu@${PUBLIC_IP}  << EOF
  ./start.webui.sh -d
  exit
EOF

echo "Set tunnel for 7860 port"
ssh -i ~/.ssh/${KEY_FILE_PATH} -fN -L 7860:127.0.0.1:7860 ubuntu@${PUBLIC_IP}

echo -e "You can open Stable diffusion on ${C_GREEN} http://localhost:7860${C_RESET}"

timestamp "End: "
