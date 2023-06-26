#!/bin/bash
source helpers.sh
timestamp "Start: "

source config.sh

INSTANCE_ID=$(aws ec2 describe-instances --filters "Name=tag:Name,Values=${INSTANCE_NAME}" --region "${REGION}" --query "Reservations[].Instances[].InstanceId" --output text)

if [ -z "${INSTANCE_ID}" ]; then
    echo "No instance found with the name '${INSTANCE_NAME}'."
    exit 1
fi

aws ec2 stop-instances --instance-ids "${INSTANCE_ID}" --output text

echo "Wait for the instance to reach STOPPED state..."

# Wait for the instance to reach STOPPED state
aws ec2 wait instance-stopped --instance-ids "$INSTANCE_ID"

echo "'${INSTANCE_NAME}' instance ($INSTANCE_ID) stopped"

timestamp "End: "
