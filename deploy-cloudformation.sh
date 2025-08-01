#!/bin/bash
set -e

echo "🚀 CloudFormation Deployment Script"

# Configuration
STACK_NAME="fashion-pipeline-stack"
TEMPLATE_FILE="simple-ec2-template.yml"
REGION="us-east-1"

echo "📦 Creating deployment package..."
./deploy-robust.sh

echo "📋 Deploying CloudFormation stack..."
aws cloudformation deploy \
    --template-file "$TEMPLATE_FILE" \
    --stack-name "$STACK_NAME" \
    --parameter-overrides \
        KeyPairName=your-key-name \
        InstanceType=t3.micro \
    --capabilities CAPABILITY_IAM \
    --region "$REGION"

echo "⏳ Waiting for stack to complete..."
aws cloudformation wait stack-create-complete \
    --stack-name "$STACK_NAME" \
    --region "$REGION"

echo "✅ Stack deployed successfully!"

# Get stack outputs
echo "📊 Getting stack outputs..."
STACK_OUTPUTS=$(aws cloudformation describe-stacks \
    --stack-name "$STACK_NAME" \
    --query 'Stacks[0].Outputs' \
    --region "$REGION" \
    --output json)

echo "🌍 Stack outputs:"
echo "$STACK_OUTPUTS"

echo "🎉 CloudFormation deployment completed!"
echo "📋 Stack name: $STACK_NAME"
echo "🌐 Check AWS Console for instance details" 