# AWS EC2 Deployment Guide for Fashion Recommendation Pipeline

This guide will help you deploy your fashion recommendation pipeline to AWS EC2 using either CloudFormation or manual deployment.

## 🚀 Quick Deployment Options

### Option 1: Automated Deployment (Recommended)

#### Prerequisites
- AWS CLI configured
- AWS account with EC2 permissions
- EC2 Key Pair created

#### Step 1: Create EC2 Instance with CloudFormation

1. **Create a key pair** (if you don't have one):
   ```bash
   aws ec2 create-key-pair --key-name fashion-pipeline-key --query 'KeyMaterial' --output text > fashion-pipeline-key.pem
   chmod 400 fashion-pipeline-key.pem
   ```

2. **Deploy CloudFormation stack**:
   ```bash
   aws cloudformation create-stack \
     --stack-name fashion-pipeline \
     --template-body file://cloudformation-template.yml \
     --parameters ParameterKey=KeyPairName,ParameterValue=fashion-pipeline-key \
     --capabilities CAPABILITY_NAMED_IAM
   ```

3. **Wait for stack creation** (check status):
   ```bash
   aws cloudformation describe-stacks --stack-name fashion-pipeline --query 'Stacks[0].StackStatus'
   ```

4. **Get the instance details**:
   ```bash
   aws cloudformation describe-stacks --stack-name fashion-pipeline --query 'Stacks[0].Outputs'
   ```

#### Step 2: Deploy Application

1. **Use the automated deployment script**:
   ```bash
   chmod +x aws-deploy.sh
   ./aws-deploy.sh \
     --ec2-ip YOUR_EC2_IP \
     --key-path fashion-pipeline-key.pem \
     --api-key YOUR_GEMINI_API_KEY
   ```

### Option 2: Manual Deployment

#### Step 1: Create EC2 Instance

1. **Launch EC2 instance**:
   - AMI: Ubuntu 22.04 LTS
   - Instance Type: t3.medium (recommended)
   - Storage: 20GB GP2
   - Security Group: Allow ports 22, 80, 443, 5000

2. **Connect to instance**:
   ```bash
   ssh -i your-key.pem ubuntu@your-ec2-ip
   ```

#### Step 2: Install Dependencies

```bash
# Update system
sudo apt-get update -y

# Install Docker
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io

# Add user to docker group
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Logout and login again
exit
# SSH back in
```

#### Step 3: Upload and Deploy

1. **Upload project files** (from your local machine):
   ```bash
   scp -i your-key.pem -r . ubuntu@your-ec2-ip:/home/ubuntu/fashion-pipeline
   ```

2. **SSH to instance and deploy**:
   ```bash
   ssh -i your-key.pem ubuntu@your-ec2-ip
   cd fashion-pipeline
   
   # Create .env file
   echo "GEMINI_API_KEY=your_actual_api_key_here" > .env
   
   # Deploy
   docker-compose up -d --build
   ```

## 🔧 Configuration Options

### Environment Variables

Create a `.env` file on your EC2 instance:
```bash
GEMINI_API_KEY=your_actual_api_key_here
```

### SSL/HTTPS Setup (Optional)

If you have a domain name, you can set up SSL:

```bash
# Install certbot
sudo apt-get install -y certbot python3-certbot-nginx

# Get SSL certificate
sudo certbot --nginx -d your-domain.com

# Setup auto-renewal
sudo crontab -l 2>/dev/null | { cat; echo "0 12 * * * /usr/bin/certbot renew --quiet"; } | sudo crontab -
```

### Nginx Reverse Proxy (Optional)

```bash
# Install nginx
sudo apt-get install -y nginx

# Create configuration
sudo tee /etc/nginx/sites-available/fashion-pipeline << 'EOF'
server {
    listen 80;
    server_name _;
    
    location / {
        proxy_pass http://localhost:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
EOF

# Enable site
sudo ln -sf /etc/nginx/sites-available/fashion-pipeline /etc/nginx/sites-enabled/
sudo rm -f /etc/nginx/sites-enabled/default
sudo nginx -t
sudo systemctl restart nginx
```

## 📊 Monitoring and Management

### Health Checks

The application includes health check endpoints:
```bash
curl http://your-ec2-ip:5000/health
```

### Logs

View application logs:
```bash
# Docker logs
docker-compose logs -f

# System logs
sudo journalctl -u docker.service -f
```

### Restart Services

```bash
# Restart application
docker-compose restart

# Restart Docker
sudo systemctl restart docker

# Restart nginx (if installed)
sudo systemctl restart nginx
```

## 🔒 Security Best Practices

### 1. Firewall Configuration

```bash
# Configure UFW firewall
sudo ufw allow 22/tcp    # SSH
sudo ufw allow 80/tcp    # HTTP
sudo ufw allow 443/tcp   # HTTPS
sudo ufw allow 5000/tcp  # Application
sudo ufw enable
```

### 2. API Key Security

- Store API keys in environment variables
- Use AWS Secrets Manager for production
- Rotate keys regularly

### 3. Network Security

- Use security groups to restrict access
- Consider using AWS WAF
- Enable VPC flow logs

## 🚨 Troubleshooting

### Common Issues

1. **Container won't start**:
   ```bash
   docker-compose logs
   docker system prune -a
   ```

2. **Port already in use**:
   ```bash
   sudo netstat -tulpn | grep :5000
   sudo lsof -i :5000
   ```

3. **Permission issues**:
   ```bash
   sudo chown -R ubuntu:ubuntu /home/ubuntu/fashion-pipeline
   chmod 400 your-key.pem
   ```

4. **Memory issues**:
   ```bash
   # Check memory usage
   free -h
   docker system df
   
   # Clean up Docker
   docker system prune -a
   ```

### Debug Commands

```bash
# Check Docker status
sudo systemctl status docker

# Check application status
docker ps -a

# Check logs
docker-compose logs --tail=50

# Check disk space
df -h

# Check memory
free -h

# Check network
netstat -tulpn
```

## 📈 Scaling Options

### Vertical Scaling
- Increase instance type (t3.medium → t3.large)
- Add more memory/CPU

### Horizontal Scaling
- Use AWS ECS for container orchestration
- Use AWS EKS for Kubernetes
- Use AWS App Runner for serverless

### Load Balancing
- Use AWS Application Load Balancer
- Use AWS CloudFront for CDN

## 💰 Cost Optimization

### Instance Types
- **Development**: t3.micro ($8-10/month)
- **Production**: t3.medium ($30-35/month)
- **High Performance**: t3.large ($60-70/month)

### Storage
- Use GP2 volumes for better performance
- Consider EBS optimization for larger instances

### Monitoring
- Use CloudWatch for monitoring
- Set up billing alerts

## 🔄 Updates and Maintenance

### Application Updates

1. **Upload new code**:
   ```bash
   scp -i your-key.pem -r . ubuntu@your-ec2-ip:/home/ubuntu/fashion-pipeline
   ```

2. **Redeploy**:
   ```bash
   ssh -i your-key.pem ubuntu@your-ec2-ip
   cd fashion-pipeline
   docker-compose down
   docker-compose up -d --build
   ```

### System Updates

```bash
# Update system packages
sudo apt-get update && sudo apt-get upgrade -y

# Update Docker
sudo apt-get install docker-ce docker-ce-cli containerd.io

# Restart services
sudo systemctl restart docker
docker-compose restart
```

## 📞 Support

For issues or questions:
1. Check the logs: `docker-compose logs -f`
2. Verify environment variables
3. Test health endpoint
4. Check network connectivity
5. Review security group settings

## 🎯 Next Steps

After successful deployment:
1. Set up monitoring and alerting
2. Configure backup strategies
3. Implement CI/CD pipeline
4. Set up domain and SSL
5. Configure auto-scaling
6. Set up logging and analytics 