# Fashion Recommendation Pipeline

A Flask-based API that analyzes fashion images using segmentation and provides styling recommendations via Google's Gemini AI.

## 🚀 Quick Start (Local Development)

### Prerequisites
- Python 3.11+
- Docker Desktop
- Gemini API Key

### Setup
1. **Clone the repository**
2. **Create `.env` file**:
   ```
   GEMINI_API_KEY=your_actual_api_key_here
   ```
3. **Deploy with Docker**:
   ```bash
   # Windows
   deploy.bat
   
   # Linux/Mac
   ./deploy.sh
   ```

## ☁️ AWS Deployment Guide

### Option 1: AWS EC2 with Docker (Recommended)

#### Prerequisites
- AWS Account
- EC2 instance (t3.medium or larger recommended)
- Security group with ports 22 (SSH) and 80/443 (HTTP/HTTPS) open

#### Step-by-Step Deployment

1. **Connect to your EC2 instance**:
   ```bash
   ssh -i your-key.pem ubuntu@your-ec2-ip
   ```

2. **Install Docker and Docker Compose**:
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
   
   # Logout and login again for group changes
   exit
   # SSH back in
   ```

3. **Upload your project files**:
   ```bash
   # From your local machine
   scp -i your-key.pem -r . ubuntu@your-ec2-ip:/home/ubuntu/fashion-pipeline
   ```

4. **SSH back to EC2 and navigate to project**:
   ```bash
   ssh -i your-key.pem ubuntu@your-ec2-ip
   cd fashion-pipeline
   ```

5. **Create .env file**:
   ```bash
   nano .env
   ```
   Add your Gemini API key:
   ```
   GEMINI_API_KEY=your_actual_api_key_here
   ```

6. **Deploy the application**:
   ```bash
   # Build and start
   docker-compose up -d
   
   # Check logs
   docker-compose logs -f
   ```

7. **Test the deployment**:
   ```bash
   curl http://localhost:5000/health
   ```

### Option 2: AWS ECS (Elastic Container Service)

#### Prerequisites
- AWS CLI configured
- ECR repository
- ECS cluster

#### Deployment Steps

1. **Create ECR repository**:
   ```bash
   aws ecr create-repository --repository-name fashion-pipeline
   ```

2. **Build and push Docker image**:
   ```bash
   # Get ECR login token
   aws ecr get-login-password --region your-region | docker login --username AWS --password-stdin your-account-id.dkr.ecr.your-region.amazonaws.com
   
   # Build image
   docker build -t fashion-pipeline .
   
   # Tag image
   docker tag fashion-pipeline:latest your-account-id.dkr.ecr.your-region.amazonaws.com/fashion-pipeline:latest
   
   # Push image
   docker push your-account-id.dkr.ecr.your-region.amazonaws.com/fashion-pipeline:latest
   ```

3. **Create ECS task definition** (save as `task-definition.json`):
   ```json
   {
     "family": "fashion-pipeline",
     "networkMode": "awsvpc",
     "requiresCompatibilities": ["FARGATE"],
     "cpu": "512",
     "memory": "1024",
     "executionRoleArn": "arn:aws:iam::your-account-id:role/ecsTaskExecutionRole",
     "containerDefinitions": [
       {
         "name": "fashion-pipeline",
         "image": "your-account-id.dkr.ecr.your-region.amazonaws.com/fashion-pipeline:latest",
         "portMappings": [
           {
             "containerPort": 5000,
             "protocol": "tcp"
           }
         ],
         "environment": [
           {
             "name": "GEMINI_API_KEY",
             "value": "your-actual-api-key"
           }
         ],
         "logConfiguration": {
           "logDriver": "awslogs",
           "options": {
             "awslogs-group": "/ecs/fashion-pipeline",
             "awslogs-region": "your-region",
             "awslogs-stream-prefix": "ecs"
           }
         }
       }
     ]
   }
   ```

4. **Register task definition**:
   ```bash
   aws ecs register-task-definition --cli-input-json file://task-definition.json
   ```

5. **Create ECS service**:
   ```bash
   aws ecs create-service \
     --cluster your-cluster-name \
     --service-name fashion-pipeline \
     --task-definition fashion-pipeline:1 \
     --desired-count 1 \
     --launch-type FARGATE \
     --network-configuration "awsvpcConfiguration={subnets=[subnet-12345],securityGroups=[sg-12345],assignPublicIp=ENABLED}"
   ```

### Option 3: AWS App Runner (Simplest)

1. **Push code to GitHub**
2. **Connect GitHub to App Runner**
3. **Configure environment variables**:
   - `GEMINI_API_KEY`: your-api-key
4. **Deploy**

## 🔧 Configuration

### Environment Variables
- `GEMINI_API_KEY`: Your Google Gemini API key (required)

### Port Configuration
- Default: 5000
- Change in `docker-compose.yml` or Dockerfile

## 📡 API Endpoints

### Health Check
```bash
GET http://your-domain/health
```

### Evaluate Fashion Image
```bash
POST http://your-domain/evaluate
Content-Type: application/json

{
  "input_path": "https://example.com/fashion-image.jpg"
}
```

### Example Response
```json
{
  "2": {
    "type": "top, t-shirt, sweatshirt",
    "bbox": [137, 313, 398, 603],
    "recommendations": [
      "This simple top is a perfect base for layering...",
      "The neutral color of this t-shirt makes it incredibly versatile...",
      "Don't be afraid to experiment with accessories..."
    ]
  },
  "7": {
    "type": "pants",
    "bbox": [181, 559, 337, 859],
    "recommendations": [...]
  },
  "overall_outfit": {
    "type": "Complete Outfit",
    "recommendations": [...]
  },
  "annotated_image": "annotated.png"
}
```

## 🛠️ Management Commands

### Docker Commands
```bash
# Start services
docker-compose up -d

# View logs
docker-compose logs -f

# Stop services
docker-compose down

# Restart services
docker-compose restart

# Check status
docker-compose ps
```

### AWS EC2 Commands
```bash
# Check if Docker is running
sudo systemctl status docker

# Start Docker if not running
sudo systemctl start docker

# Enable Docker on boot
sudo systemctl enable docker
```

## 🔒 Security Considerations

1. **API Key Security**:
   - Never commit `.env` files to version control
   - Use AWS Secrets Manager for production
   - Rotate API keys regularly

2. **Network Security**:
   - Use HTTPS in production
   - Configure proper security groups
   - Consider using AWS WAF

3. **Container Security**:
   - Keep base images updated
   - Scan for vulnerabilities
   - Use non-root user in container

## 📊 Monitoring

### Health Checks
- Endpoint: `/health`
- Docker health check configured
- ECS health checks available

### Logs
- Application logs via Docker
- CloudWatch logs for ECS
- Structured logging for debugging

## 🚨 Troubleshooting

### Common Issues

1. **Container won't start**:
   ```bash
   docker-compose logs
   ```

2. **API key issues**:
   - Check `.env` file exists
   - Verify API key is valid
   - Check environment variable loading

3. **Port conflicts**:
   - Change port in `docker-compose.yml`
   - Check if port is already in use

4. **Memory issues**:
   - Increase container memory
   - Monitor resource usage

### Debug Commands
```bash
# Check container status
docker ps -a

# View container logs
docker logs container-name

# Execute commands in container
docker exec -it container-name bash

# Check resource usage
docker stats
```

## 📞 Support

For issues or questions:
1. Check the logs: `docker-compose logs -f`
2. Verify environment variables
3. Test health endpoint
4. Check network connectivity

## 📝 License

This project is for educational and personal use. 