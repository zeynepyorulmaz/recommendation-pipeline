# 🚀 Fashion Recommendation Pipeline - AWS EC2 Deployment

This guide will help you deploy your fashion recommendation pipeline to AWS EC2 with automated CI/CD using GitHub Actions.

## 📋 Repository Setup

Your repository: `https://github.com/aina-app/aina-server.git`

## 🎯 Quick Start

### Step 1: Clone and Setup Repository

```bash
# Clone your repository
git clone https://github.com/aina-app/aina-server.git
cd aina-server

# Copy the deployment files to your repository
cp -r /path/to/recommendation_pipeline/.github ./
cp /path/to/recommendation_pipeline/setup-*.sh ./
cp /path/to/recommendation_pipeline/cloudformation-template.yml ./
cp /path/to/recommendation_pipeline/aws-deploy.sh ./
```

### Step 2: Set up GitHub Secrets

Go to your GitHub repository → **Settings** → **Secrets and variables** → **Actions** and add:

#### Required Secrets:
- `AWS_ACCESS_KEY_ID` - Your AWS access key
- `AWS_SECRET_ACCESS_KEY` - Your AWS secret key  
- `EC2_HOST` - Your EC2 instance public IP
- `EC2_SSH_KEY` - Your EC2 private key content
- `GEMINI_API_KEY` - Your Google Gemini API key

#### Optional Secrets:
- `AWS_REGION` - AWS region (default: us-east-1)
- `EC2_USERNAME` - EC2 username (default: ubuntu)
- `EC2_PORT` - SSH port (default: 22)

### Step 3: Create AWS Infrastructure

#### Option A: Automated Setup
```bash
# Run the automated setup script
./setup-aws.sh
```

#### Option B: Manual CloudFormation
```bash
# Create key pair
aws ec2 create-key-pair --key-name aina-server-key --query 'KeyMaterial' --output text > aina-server-key.pem
chmod 400 aina-server-key.pem

# Deploy CloudFormation stack
aws cloudformation create-stack \
  --stack-name aina-server \
  --template-body file://cloudformation-template.yml \
  --parameters ParameterKey=KeyPairName,ParameterValue=aina-server-key \
  --capabilities CAPABILITY_NAMED_IAM
```

### Step 4: Deploy Application

#### Option A: Automated Deployment
```bash
# Get your EC2 IP from CloudFormation outputs
EC2_IP=$(aws cloudformation describe-stacks --stack-name aina-server --query 'Stacks[0].Outputs[?OutputKey==`PublicIP`].OutputValue' --output text)

# Deploy using the automated script
./aws-deploy.sh \
  --ec2-ip $EC2_IP \
  --key-path aina-server-key.pem \
  --api-key YOUR_GEMINI_API_KEY
```

#### Option B: Manual Deployment
```bash
# Upload files to EC2
scp -i aina-server-key.pem -r . ubuntu@$EC2_IP:/home/ubuntu/aina-server

# SSH to EC2 and deploy
ssh -i aina-server-key.pem ubuntu@$EC2_IP
cd aina-server
echo "GEMINI_API_KEY=your_api_key_here" > .env
docker-compose up -d --build
```

## 🔄 GitHub Actions CI/CD

### Automatic Deployment

Once set up, every push to `main` branch will automatically:

1. **Run Tests** - Validate code changes
2. **Build Package** - Create deployment package
3. **Deploy to EC2** - Upload and deploy to AWS
4. **Health Check** - Verify deployment success
5. **Rollback** - Automatic rollback on failure

### Manual Deployment

You can also trigger deployments manually:

1. Go to your GitHub repository
2. Click **Actions** tab
3. Select **Deploy to EC2** workflow
4. Click **Run workflow**
5. Choose environment (staging/production)
6. Click **Run workflow**

## 📊 Monitoring

### Health Checks
```bash
# Check application health
curl http://your-ec2-ip:5000/health

# Check Docker containers
docker ps -a

# View logs
docker-compose logs -f
```

### GitHub Actions Monitoring
- Go to **Actions** tab in your repository
- Click on workflow runs to view detailed logs
- Monitor deployment status and any failures

## 🛠️ Configuration

### Environment Variables

The application uses these environment variables:
```bash
GEMINI_API_KEY=your_google_gemini_api_key
ENVIRONMENT=production
GITHUB_SHA=commit_sha
DEPLOYED_AT=deployment_timestamp
```

### Docker Configuration

The deployment uses:
- **Docker Compose** for container orchestration
- **Port 5000** for the application
- **Health checks** for monitoring
- **Auto-restart** on failure

## 🔒 Security

### AWS Security
- **IAM User** with minimal permissions
- **Security Groups** with required ports only
- **SSH Key** authentication only
- **Firewall** configuration

### Application Security
- **Environment variables** for secrets
- **HTTPS** support (optional)
- **API key** rotation
- **Log monitoring**

## 🚨 Troubleshooting

### Common Issues

1. **SSH Connection Failed**
   ```bash
   # Check EC2 security group
   aws ec2 describe-security-groups --group-ids your-security-group-id
   
   # Verify SSH key
   ssh -i your-key.pem ubuntu@your-ec2-ip
   ```

2. **Application Won't Start**
   ```bash
   # Check Docker logs
   docker-compose logs
   
   # Check environment variables
   cat .env
   
   # Restart containers
   docker-compose restart
   ```

3. **Health Check Failed**
   ```bash
   # Check if port is open
   netstat -tulpn | grep :5000
   
   # Check application logs
   docker-compose logs -f
   ```

### Debug Commands

```bash
# Check EC2 status
aws ec2 describe-instances --instance-ids your-instance-id

# SSH to instance
ssh -i your-key.pem ubuntu@your-ec2-ip

# Check application status
cd /home/ubuntu/aina-server
docker-compose ps
docker-compose logs -f

# Check system resources
htop
df -h
free -h
```

## 📈 Scaling

### Vertical Scaling
- Increase EC2 instance type (t3.medium → t3.large)
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

### Cost Monitoring
- Set up AWS billing alerts
- Monitor CloudWatch metrics
- Use AWS Cost Explorer

## 🔄 Updates and Maintenance

### Application Updates
```bash
# Push changes to GitHub
git add .
git commit -m "Update application"
git push origin main

# GitHub Actions will automatically deploy
```

### System Updates
```bash
# SSH to EC2
ssh -i your-key.pem ubuntu@your-ec2-ip

# Update system
sudo apt-get update && sudo apt-get upgrade -y

# Restart services
sudo systemctl restart docker
docker-compose restart
```

## 📞 Support

For deployment issues:

1. **Check GitHub Actions logs** in the Actions tab
2. **Verify all secrets** are properly configured
3. **Test SSH connection** manually
4. **Review EC2 instance logs**
5. **Check Docker container status**

## 🎯 Next Steps

After successful deployment:

1. **Set up monitoring** with CloudWatch
2. **Configure alerts** for failures
3. **Add staging environment** for testing
4. **Implement blue-green deployment**
5. **Set up backup strategies**
6. **Add performance monitoring**

## 📝 Files Overview

### Deployment Files
- `.github/workflows/deploy-ec2.yml` - GitHub Actions workflow
- `aws-deploy.sh` - Automated deployment script
- `setup-aws.sh` - AWS infrastructure setup
- `cloudformation-template.yml` - AWS CloudFormation template
- `setup-github-secrets.sh` - GitHub secrets helper

### Documentation
- `DEPLOYMENT_SETUP.md` - This setup guide
- `AWS_DEPLOYMENT_GUIDE.md` - Detailed AWS guide
- `GITHUB_ACTIONS_SETUP.md` - GitHub Actions guide

Your fashion recommendation pipeline is now ready for automated deployment to AWS EC2 with full CI/CD capabilities! 