# GitHub Actions CI/CD Setup Guide

This guide will help you set up automated deployment from GitHub to AWS EC2 using GitHub Actions.

## 🚀 Quick Setup

### Step 1: Prepare Your Repository

1. **Push your code to GitHub**:
   ```bash
   git add .
   git commit -m "Add GitHub Actions CI/CD"
   git push origin main
   ```

2. **Create the `.github/workflows` directory**:
   ```bash
   mkdir -p .github/workflows
   ```

### Step 2: Add GitHub Secrets

Go to your GitHub repository → **Settings** → **Secrets and variables** → **Actions** and add the following secrets:

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

### Step 3: Create AWS IAM User

1. **Create IAM User**:
   ```bash
   aws iam create-user --user-name github-actions
   ```

2. **Create Access Keys**:
   ```bash
   aws iam create-access-key --user-name github-actions
   ```

3. **Attach Policies**:
   ```bash
   # Attach EC2 read permissions
   aws iam attach-user-policy \
     --user-name github-actions \
     --policy-arn arn:aws:iam::aws:policy/AmazonEC2ReadOnlyAccess
   
   # Attach ECR permissions (if using ECR)
   aws iam attach-user-policy \
     --user-name github-actions \
     --policy-arn arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryPowerUser
   ```

### Step 4: Prepare EC2 Instance

1. **Generate SSH Key Pair** (if you don't have one):
   ```bash
   ssh-keygen -t rsa -b 4096 -f ~/.ssh/github-actions
   ```

2. **Add Public Key to EC2**:
   ```bash
   ssh-copy-id -i ~/.ssh/github-actions.pub ubuntu@your-ec2-ip
   ```

3. **Get Private Key Content**:
   ```bash
   cat ~/.ssh/github-actions
   ```
   Copy this content to the `EC2_SSH_KEY` secret.

## 🔧 Workflow Configuration

### Workflow Files

The repository includes two workflow files:

1. **`.github/workflows/deploy.yml`** - Full-featured workflow with ECR and ECS support
2. **`.github/workflows/deploy-ec2.yml`** - Simple EC2-only deployment

### Workflow Triggers

The workflows trigger on:
- **Push to main/master branch**
- **Pull requests to main/master branch**
- **Manual workflow dispatch** (with environment selection)

### Environment Variables

The workflow automatically sets these environment variables:
- `ENVIRONMENT` - staging or production
- `GITHUB_SHA` - Commit SHA
- `DEPLOYED_AT` - Deployment timestamp
- `GITHUB_RUN_ID` - GitHub Actions run ID
- `GITHUB_RUN_NUMBER` - Run number

## 🛠️ Advanced Configuration

### Customizing the Workflow

1. **Modify Test Steps**:
   ```yaml
   - name: Run tests
     run: |
       # Add your custom test commands here
       python -m pytest tests/
       python -m flake8 .
   ```

2. **Add Pre-deployment Steps**:
   ```yaml
   - name: Security scan
     run: |
       # Add security scanning
       pip install bandit
       bandit -r .
   ```

3. **Custom Health Checks**:
   ```yaml
   # Health check with custom endpoint
   if curl -f http://localhost:5000/api/health > /dev/null 2>&1; then
     echo "✅ Health check passed"
   else
     echo "❌ Health check failed"
     exit 1
   fi
   ```

### Environment-Specific Configurations

1. **Staging Environment**:
   ```yaml
   - name: Deploy to Staging
     if: github.event.inputs.environment == 'staging'
     run: |
       # Staging-specific deployment steps
   ```

2. **Production Environment**:
   ```yaml
   - name: Deploy to Production
     if: github.event.inputs.environment == 'production'
     run: |
       # Production-specific deployment steps
   ```

## 🔒 Security Best Practices

### 1. IAM Permissions

Create a minimal IAM policy for GitHub Actions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "ec2:DescribeInstances",
        "ec2:DescribeSecurityGroups",
        "ecr:GetAuthorizationToken",
        "ecr:BatchCheckLayerAvailability",
        "ecr:GetDownloadUrlForLayer",
        "ecr:BatchGetImage"
      ],
      "Resource": "*"
    }
  ]
}
```

### 2. SSH Key Security

- Use dedicated SSH keys for CI/CD
- Rotate keys regularly
- Use key-based authentication only
- Disable password authentication on EC2

### 3. Secrets Management

- Never commit secrets to code
- Use GitHub Secrets for sensitive data
- Rotate secrets regularly
- Use least privilege principle

## 📊 Monitoring and Debugging

### Workflow Monitoring

1. **View Workflow Runs**:
   - Go to **Actions** tab in your repository
   - Click on the workflow name
   - View detailed logs for each step

2. **Debug Failed Deployments**:
   ```bash
   # SSH to EC2 and check logs
   ssh -i ~/.ssh/github-actions ubuntu@your-ec2-ip
   cd /home/ubuntu/fashion-pipeline
   docker-compose logs -f
   ```

3. **Check Application Status**:
   ```bash
   # Health check
   curl http://your-ec2-ip:5000/health
   
   # Check Docker containers
   docker ps -a
   ```

### Logging and Notifications

1. **Add Slack Notifications**:
   ```yaml
   - name: Notify Slack
     uses: 8398a7/action-slack@v3
     with:
       status: ${{ job.status }}
       webhook_url: ${{ secrets.SLACK_WEBHOOK_URL }}
   ```

2. **Add Email Notifications**:
   ```yaml
   - name: Send Email
     uses: dawidd6/action-send-mail@v3
     with:
       server_address: smtp.gmail.com
       server_port: 587
       username: ${{ secrets.EMAIL_USERNAME }}
       password: ${{ secrets.EMAIL_PASSWORD }}
       subject: "Deployment ${{ job.status }}"
       to: ${{ secrets.NOTIFICATION_EMAIL }}
   ```

## 🚨 Troubleshooting

### Common Issues

1. **SSH Connection Failed**:
   - Check EC2 security group (port 22)
   - Verify SSH key format
   - Check EC2 instance status

2. **Docker Build Failed**:
   - Check Dockerfile syntax
   - Verify all required files are present
   - Check Docker daemon status on EC2

3. **Application Won't Start**:
   - Check environment variables
   - Verify port availability
   - Check Docker logs

4. **Health Check Failed**:
   - Verify application is listening on port 5000
   - Check firewall settings
   - Review application logs

### Debug Commands

```bash
# Check EC2 instance status
aws ec2 describe-instances --instance-ids your-instance-id

# Check security group
aws ec2 describe-security-groups --group-ids your-security-group-id

# SSH to instance
ssh -i ~/.ssh/github-actions ubuntu@your-ec2-ip

# Check application logs
docker-compose logs -f

# Check system resources
htop
df -h
free -h
```

## 🔄 Rollback Strategy

The workflow includes automatic rollback:

1. **Backup Creation**: Before deployment, current version is backed up
2. **Health Check**: After deployment, application health is verified
3. **Automatic Rollback**: If health check fails, previous version is restored

### Manual Rollback

```bash
# SSH to EC2
ssh -i ~/.ssh/github-actions ubuntu@your-ec2-ip

# List backups
ls -la /home/ubuntu/fashion-pipeline.backup.*

# Restore from backup
cd /home/ubuntu
LATEST_BACKUP=$(ls -t fashion-pipeline.backup.* | head -1)
rm -rf fashion-pipeline
mv "$LATEST_BACKUP" fashion-pipeline
cd fashion-pipeline
docker-compose up -d
```

## 📈 Scaling and Optimization

### Performance Optimization

1. **Docker Layer Caching**:
   ```dockerfile
   # Optimize Dockerfile
   COPY requirements.txt .
   RUN pip install -r requirements.txt
   COPY . .
   ```

2. **Parallel Jobs**:
   ```yaml
   jobs:
     test:
       runs-on: ubuntu-latest
     security-scan:
       runs-on: ubuntu-latest
     deploy:
       needs: [test, security-scan]
   ```

3. **Caching Dependencies**:
   ```yaml
   - name: Cache pip dependencies
     uses: actions/cache@v3
     with:
       path: ~/.cache/pip
       key: ${{ runner.os }}-pip-${{ hashFiles('**/requirements.txt') }}
   ```

### Cost Optimization

1. **Use Spot Instances** for testing
2. **Schedule deployments** during off-peak hours
3. **Clean up unused resources** regularly
4. **Monitor AWS costs** with CloudWatch

## 🎯 Next Steps

After setting up GitHub Actions:

1. **Add More Tests**: Unit tests, integration tests, security scans
2. **Set Up Monitoring**: CloudWatch, application monitoring
3. **Add Staging Environment**: Separate staging deployment
4. **Implement Blue-Green Deployment**: Zero-downtime deployments
5. **Add Performance Testing**: Load testing, stress testing
6. **Set Up Alerts**: Failure notifications, performance alerts

## 📞 Support

For issues with the GitHub Actions workflow:

1. Check the **Actions** tab for detailed logs
2. Verify all secrets are properly configured
3. Test SSH connection manually
4. Review EC2 instance logs
5. Check Docker container status

The workflow is designed to be robust and includes automatic rollback, comprehensive logging, and detailed error reporting. 