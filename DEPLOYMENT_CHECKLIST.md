# 🚀 AWS Deployment Checklist

## Before You Start
- [ ] AWS Account with EC2 access
- [ ] Gemini API Key from Google AI Studio
- [ ] SSH key pair for EC2 access
- [ ] Basic knowledge of AWS EC2

## Quick Deployment (EC2 + Docker)

### 1. Launch EC2 Instance
- [ ] Launch Ubuntu 22.04 LTS instance
- [ ] Choose t3.medium or larger (2GB RAM minimum)
- [ ] Configure security group:
  - [ ] Port 22 (SSH) - Your IP
  - [ ] Port 80 (HTTP) - 0.0.0.0/0
  - [ ] Port 443 (HTTPS) - 0.0.0.0/0
- [ ] Download your .pem key file

### 2. Connect to EC2
```bash
ssh -i your-key.pem ubuntu@your-ec2-ip
```

### 3. Install Docker
```bash
# Update system
sudo apt-get update

# Install Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Logout and login again
exit
ssh -i your-key.pem ubuntu@your-ec2-ip
```

### 4. Upload Project Files
From your local machine:
```bash
scp -i your-key.pem -r . ubuntu@your-ec2-ip:/home/ubuntu/fashion-pipeline
```

### 5. Deploy Application
```bash
# SSH to EC2
ssh -i your-key.pem ubuntu@your-ec2-ip

# Navigate to project
cd fashion-pipeline

# Create .env file
nano .env
# Add: GEMINI_API_KEY=your_actual_api_key_here

# Deploy
docker-compose up -d

# Check logs
docker-compose logs -f
```

### 6. Test Deployment
```bash
# Health check
curl http://localhost:5000/health

# Test API
curl -X POST http://localhost:5000/evaluate \
  -H "Content-Type: application/json" \
  -d '{"input_path": "https://images.unsplash.com/photo-1445205170230-053b83016050?w=500"}'
```

## ✅ Success Indicators
- [ ] Docker container is running
- [ ] Health endpoint returns 200
- [ ] Evaluate endpoint processes images
- [ ] No errors in logs

## 🔧 Common Issues & Solutions

### Container won't start
```bash
docker-compose logs
# Check for missing .env file or invalid API key
```

### Port already in use
```bash
# Check what's using port 5000
sudo netstat -tulpn | grep :5000
# Kill process or change port in docker-compose.yml
```

### Memory issues
```bash
# Check memory usage
free -h
# Consider upgrading to larger instance
```

### API key issues
```bash
# Verify .env file exists and has correct format
cat .env
# Should show: GEMINI_API_KEY=your_key_here
```

## 📞 Need Help?
1. Check logs: `docker-compose logs -f`
2. Verify .env file exists and has API key
3. Test health endpoint
4. Check EC2 security group settings

## 🎯 Your API is Ready When:
- Health endpoint: `http://your-ec2-ip/health` returns 200
- Evaluate endpoint: `http://your-ec2-ip/evaluate` accepts POST requests
- No errors in Docker logs 