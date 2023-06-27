#!/bin/bash
source helpers.sh
timestamp "Start: "

source config.sh

INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=${INSTANCE_NAME}" --region "${REGION}" --query "Reservations[].Instances[].InstanceId" --output text)

if [ -z "${INSTANCE_ID}" ]; then
    echo "No instance found with the name '${INSTANCE_NAME}'."
    exit 1
fi

aws ec2 start-instances --instance-ids "${INSTANCE_ID}"
echo "'${INSTANCE_NAME}' instance ($INSTANCE_ID) started..."
echo "Wait for the instance to reach the running state..."

# Wait for the instance to reach the running state
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID"
echo "'${INSTANCE_NAME}' instance ($INSTANCE_ID) is now running."

PUBLIC_IP=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=${INSTANCE_NAME}" --region "${REGION}" --query "Reservations[].Instances[].PublicIpAddress" --output text)
echo -e "Public IP: '${C_GREEN}${PUBLIC_IP}${C_RESET}'"

# Wait for the instance to reach the STATUS OK
echo "Wait for the instance to reach the STATUS OK"
aws ec2 wait instance-status-ok --instance-ids "$INSTANCE_ID"
echo "All checks are ok"

echo "Connect to the instance to start Stable Diffusion WEB UI"
ssh -i ~/.ssh/${KEY_FILE_PATH} -o StrictHostKeyChecking=no ubuntu@${PUBLIC_IP}  << EOF
  ./start.webui.sh -d
  exit
EOF

echo "Set tunnel for 7860 port"
ssh -i ~/.ssh/${KEY_FILE_PATH} -fN -L 7860:127.0.0.1:7860 ubuntu@${PUBLIC_IP}

timestamp "End: "

