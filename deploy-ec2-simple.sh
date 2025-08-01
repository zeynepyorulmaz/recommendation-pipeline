#!/bin/bash
set -e

echo "🚀 AWS EC2 Deployment Script"

# Configuration
INSTANCE_TYPE="t3.micro"
KEY_NAME="your-key-name"
SECURITY_GROUP_NAME="fashion-pipeline-sg"
AMI_ID="ami-0c02fb55956c7d316"  # Ubuntu 22.04 LTS

echo "📦 Creating deployment package..."
./deploy-robust.sh

echo "🔑 Creating security group..."
aws ec2 create-security-group \
    --group-name "$SECURITY_GROUP_NAME" \
    --description "Security group for Fashion Pipeline" \
    --region us-east-1 || echo "Security group already exists"

echo "🔓 Adding security group rules..."
aws ec2 authorize-security-group-ingress \
    --group-name "$SECURITY_GROUP_NAME" \
    --protocol tcp \
    --port 22 \
    --cidr 0.0.0.0/0 \
    --region us-east-1 || echo "SSH rule already exists"

aws ec2 authorize-security-group-ingress \
    --group-name "$SECURITY_GROUP_NAME" \
    --protocol tcp \
    --port 5000 \
    --cidr 0.0.0.0/0 \
    --region us-east-1 || echo "App port rule already exists"

echo "🖥️  Creating EC2 instance..."
INSTANCE_ID=$(aws ec2 run-instances \
    --image-id "$AMI_ID" \
    --instance-type "$INSTANCE_TYPE" \
    --key-name "$KEY_NAME" \
    --security-groups "$SECURITY_GROUP_NAME" \
    --user-data file://setup-ec2.sh \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=Fashion-Pipeline}]' \
    --query 'Instances[0].InstanceId' \
    --output text \
    --region us-east-1)

echo "✅ Instance created: $INSTANCE_ID"

echo "⏳ Waiting for instance to be running..."
aws ec2 wait instance-running --instance-ids "$INSTANCE_ID" --region us-east-1

echo "🌐 Getting public IP..."
PUBLIC_IP=$(aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text \
    --region us-east-1)

echo "✅ Instance is ready!"
echo "🌍 Public IP: $PUBLIC_IP"
echo "🔗 Application URL: http://$PUBLIC_IP:5000"
echo "📝 SSH Command: ssh -i your-key.pem ubuntu@$PUBLIC_IP"

echo "📦 Uploading deployment package..."
scp -i your-key.pem deployment-package.tar.gz ubuntu@$PUBLIC_IP:~/

echo "🚀 Deploying application..."
ssh -i your-key.pem ubuntu@$PUBLIC_IP << 'EOF'
    # Extract deployment package
    tar -xzf deployment-package.tar.gz
    
    # Install Python and dependencies
    sudo apt-get update -y
    sudo apt-get install -y python3 python3-pip python3-venv
    
    # Create virtual environment
    python3 -m venv venv
    source venv/bin/activate
    
    # Install requirements
    pip install -r requirements.txt
    
    # Start the application
    nohup python direct_pipeline.py > app.log 2>&1 &
    
    echo "✅ Application deployed successfully!"
    echo "📊 Check logs: tail -f app.log"
EOF

echo "🎉 Deployment completed!"
echo "🌍 Your application is running at: http://$PUBLIC_IP:5000" 