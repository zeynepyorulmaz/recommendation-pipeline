#!/bin/bash
set -e

echo "🚀 Setting up EC2 instance for Fashion Pipeline..."

# Update system
sudo apt-get update -y

# Install Python and dependencies
sudo apt-get install -y python3 python3-pip python3-venv git curl

# Install Docker (optional, for containerized deployment)
sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Add ubuntu user to docker group
sudo usermod -aG docker ubuntu

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Start and enable Docker
sudo systemctl start docker
sudo systemctl enable docker

# Create application directory
mkdir -p /home/ubuntu/fashion-pipeline
chown ubuntu:ubuntu /home/ubuntu/fashion-pipeline

echo "✅ EC2 instance setup completed!" 