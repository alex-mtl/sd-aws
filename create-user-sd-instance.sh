#!/bin/bash
source helpers.sh
timestamp "Start: "

source config.sh

# Create a new key pair
aws ec2 create-key-pair --key-name "$KEY_NAME" --key-type ed25519 --query 'KeyMaterial' --output text > ${KEY_FILE_PATH}

# Set appropriate permissions for the .pem file
chmod 400 ${KEY_FILE_PATH}


master_key_id=$(aws configure get aws_access_key_id)
master_secret_access_key=$(aws configure get aws_secret_access_key)

aws iam create-user --user-name ${SD_AWS_USER}

echo "User $SD_AWS_USER has been created..."

# Create the IAM policy
POLICY_ARN=$(aws iam create-policy --policy-name "$POLICY_NAME" --policy-document file://"$POLICY_FILE" --query 'Policy.Arn' --output text)

echo "IAM policy created with ARN: $POLICY_ARN"

#Attach security permissions policy to the user
aws iam attach-user-policy --user-name ${SD_AWS_USER} --policy-arn "$POLICY_ARN"
echo "$SD_AWS_USER permissions policy applied"


access_key_id=$(aws iam create-access-key --user-name ${SD_AWS_USER} --query 'AccessKey.AccessKeyId' --output text)
secret_access_key=$(aws iam create-access-key --user-name ${SD_AWS_USER} --query 'AccessKey.SecretAccessKey' --output text)

echo "Switch session to $SD_AWS_USER user"

#Switch session to new user
aws configure set aws_access_key_id "${access_key_id}"
aws configure set aws_secret_access_key "${secret_access_key}"

echo "User $SD_AWS_USER has been created..."
# Use the access_key_id and secret_access_key variables in your script
echo "Access Key ID: $access_key_id"
echo "Secret Access Key: $secret_access_key"

MESSAGE="$INSTANCE_NAME instance is ready."

# Create the instance
INSTANCE_ID=$(aws ec2 run-instances \
  --image-id "$AMI_ID" \
  --instance-type "$INSTANCE_TYPE" \
  --key-name "$AWS_KEY_NAME" \
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

# Display the message when the instance is ready
echo "$MESSAGE"

echo "Switch session back to master account"

aws configure set aws_access_key_id "${master_key_id}"
aws configure set aws_secret_access_key "${master_secret_access_key}"

echo "Done!"
