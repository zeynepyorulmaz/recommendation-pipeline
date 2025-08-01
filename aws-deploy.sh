#!/bin/bash

# AWS EC2 Deployment Script for Fashion Recommendation Pipeline
# This script automates the deployment of the fashion pipeline to AWS EC2

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
EC2_USER="ubuntu"
EC2_IP=""
EC2_KEY_PATH=""
GEMINI_API_KEY=""
PROJECT_NAME="fashion-pipeline"

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to validate inputs
validate_inputs() {
    if [ -z "$EC2_IP" ]; then
        print_error "EC2_IP is required. Please set it in the script or pass as argument."
        exit 1
    fi
    
    if [ -z "$EC2_KEY_PATH" ]; then
        print_error "EC2_KEY_PATH is required. Please set it in the script or pass as argument."
        exit 1
    fi
    
    if [ -z "$GEMINI_API_KEY" ]; then
        print_error "GEMINI_API_KEY is required. Please set it in the script or pass as argument."
        exit 1
    fi
    
    if [ ! -f "$EC2_KEY_PATH" ]; then
        print_error "Key file not found: $EC2_KEY_PATH"
        exit 1
    fi
}

# Function to install Docker on EC2
install_docker() {
    print_status "Installing Docker on EC2 instance..."
    
    ssh -i "$EC2_KEY_PATH" -o StrictHostKeyChecking=no "$EC2_USER@$EC2_IP" << 'EOF'
        # Update system
        sudo apt-get update -y
        
        # Install required packages
        sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release
        
        # Add Docker's official GPG key
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
        
        # Add Docker repository
        echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        # Install Docker
        sudo apt-get update -y
        sudo apt-get install -y docker-ce docker-ce-cli containerd.io
        
        # Add user to docker group
        sudo usermod -aG docker $USER
        
        # Install Docker Compose
        sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
        sudo chmod +x /usr/local/bin/docker-compose
        
        # Start and enable Docker
        sudo systemctl start docker
        sudo systemctl enable docker
        
        # Verify installation
        docker --version
        docker-compose --version
EOF
    
    print_success "Docker installation completed"
}

# Function to upload project files
upload_project() {
    print_status "Uploading project files to EC2..."
    
    # Create a temporary directory with project files
    TEMP_DIR=$(mktemp -d)
    cp -r . "$TEMP_DIR/$PROJECT_NAME"
    
    # Create .env file
    echo "GEMINI_API_KEY=$GEMINI_API_KEY" > "$TEMP_DIR/$PROJECT_NAME/.env"
    
    # Upload to EC2
    scp -i "$EC2_KEY_PATH" -o StrictHostKeyChecking=no -r "$TEMP_DIR/$PROJECT_NAME" "$EC2_USER@$EC2_IP:/home/$EC2_USER/"
    
    # Clean up
    rm -rf "$TEMP_DIR"
    
    print_success "Project files uploaded successfully"
}

# Function to deploy the application
deploy_application() {
    print_status "Deploying the application on EC2..."
    
    ssh -i "$EC2_KEY_PATH" -o StrictHostKeyChecking=no "$EC2_USER@$EC2_IP" << EOF
        cd /home/$EC2_USER/$PROJECT_NAME
        
        # Build and start the application
        docker-compose up -d --build
        
        # Wait for the application to start
        sleep 30
        
        # Check if the application is running
        if curl -f http://localhost:5000/health > /dev/null 2>&1; then
            echo "Application is running successfully!"
        else
            echo "Application failed to start. Checking logs..."
            docker-compose logs
            exit 1
        fi
EOF
    
    print_success "Application deployed successfully"
}

# Function to configure firewall
configure_firewall() {
    print_status "Configuring firewall rules..."
    
    ssh -i "$EC2_KEY_PATH" -o StrictHostKeyChecking=no "$EC2_USER@$EC2_IP" << 'EOF'
        # Allow SSH
        sudo ufw allow 22/tcp
        
        # Allow HTTP
        sudo ufw allow 80/tcp
        
        # Allow HTTPS
        sudo ufw allow 443/tcp
        
        # Allow application port
        sudo ufw allow 5000/tcp
        
        # Enable firewall
        echo "y" | sudo ufw enable
        
        # Check status
        sudo ufw status
EOF
    
    print_success "Firewall configured successfully"
}

# Function to setup nginx reverse proxy (optional)
setup_nginx() {
    print_status "Setting up Nginx reverse proxy..."
    
    ssh -i "$EC2_KEY_PATH" -o StrictHostKeyChecking=no "$EC2_USER@$EC2_IP" << 'EOF'
        # Install nginx
        sudo apt-get update -y
        sudo apt-get install -y nginx
        
        # Create nginx configuration
        sudo tee /etc/nginx/sites-available/fashion-pipeline << 'NGINX_CONFIG'
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
NGINX_CONFIG
        
        # Enable the site
        sudo ln -sf /etc/nginx/sites-available/fashion-pipeline /etc/nginx/sites-enabled/
        sudo rm -f /etc/nginx/sites-enabled/default
        
        # Test nginx configuration
        sudo nginx -t
        
        # Restart nginx
        sudo systemctl restart nginx
        sudo systemctl enable nginx
EOF
    
    print_success "Nginx reverse proxy configured successfully"
}

# Function to setup SSL with Let's Encrypt (optional)
setup_ssl() {
    local DOMAIN="$1"
    
    if [ -z "$DOMAIN" ]; then
        print_warning "No domain provided. Skipping SSL setup."
        return
    fi
    
    print_status "Setting up SSL certificate for domain: $DOMAIN"
    
    ssh -i "$EC2_KEY_PATH" -o StrictHostKeyChecking=no "$EC2_USER@$EC2_IP" << EOF
        # Install certbot
        sudo apt-get update -y
        sudo apt-get install -y certbot python3-certbot-nginx
        
        # Get SSL certificate
        sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN
        
        # Setup auto-renewal
        sudo crontab -l 2>/dev/null | { cat; echo "0 12 * * * /usr/bin/certbot renew --quiet"; } | sudo crontab -
EOF
    
    print_success "SSL certificate configured successfully"
}

# Function to show deployment status
show_status() {
    print_status "Checking deployment status..."
    
    ssh -i "$EC2_KEY_PATH" -o StrictHostKeyChecking=no "$EC2_USER@$EC2_IP" << 'EOF'
        echo "=== Docker Status ==="
        docker ps
        
        echo -e "\n=== Application Health ==="
        curl -s http://localhost:5000/health || echo "Health check failed"
        
        echo -e "\n=== Docker Compose Status ==="
        docker-compose ps
        
        echo -e "\n=== Recent Logs ==="
        docker-compose logs --tail=20
EOF
    
    print_success "Deployment status checked"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --ec2-ip IP_ADDRESS        EC2 instance IP address"
    echo "  --key-path PATH            Path to EC2 key file (.pem)"
    echo "  --api-key KEY              Gemini API key"
    echo "  --domain DOMAIN            Domain name for SSL (optional)"
    echo "  --skip-docker              Skip Docker installation"
    echo "  --skip-nginx               Skip Nginx setup"
    echo "  --skip-ssl                 Skip SSL setup"
    echo "  --status                   Show deployment status only"
    echo "  --help                     Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 --ec2-ip 1.2.3.4 --key-path ~/.ssh/my-key.pem --api-key your-api-key"
}

# Main deployment function
main() {
    print_status "Starting AWS EC2 deployment..."
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --ec2-ip)
                EC2_IP="$2"
                shift 2
                ;;
            --key-path)
                EC2_KEY_PATH="$2"
                shift 2
                ;;
            --api-key)
                GEMINI_API_KEY="$2"
                shift 2
                ;;
            --domain)
                DOMAIN="$2"
                shift 2
                ;;
            --skip-docker)
                SKIP_DOCKER=true
                shift
                ;;
            --skip-nginx)
                SKIP_NGINX=true
                shift
                ;;
            --skip-ssl)
                SKIP_SSL=true
                shift
                ;;
            --status)
                show_status
                exit 0
                ;;
            --help)
                show_usage
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    # Validate inputs
    validate_inputs
    
    # Check if required tools are installed
    if ! command_exists ssh; then
        print_error "SSH client is not installed"
        exit 1
    fi
    
    if ! command_exists scp; then
        print_error "SCP client is not installed"
        exit 1
    fi
    
    # Set key file permissions
    chmod 400 "$EC2_KEY_PATH"
    
    # Install Docker (if not skipped)
    if [ "$SKIP_DOCKER" != "true" ]; then
        install_docker
    fi
    
    # Upload project files
    upload_project
    
    # Deploy application
    deploy_application
    
    # Configure firewall
    configure_firewall
    
    # Setup nginx (if not skipped)
    if [ "$SKIP_NGINX" != "true" ]; then
        setup_nginx
    fi
    
    # Setup SSL (if domain provided and not skipped)
    if [ -n "$DOMAIN" ] && [ "$SKIP_SSL" != "true" ]; then
        setup_ssl "$DOMAIN"
    fi
    
    # Show final status
    show_status
    
    print_success "Deployment completed successfully!"
    echo ""
    echo "Your application is now available at:"
    echo "  HTTP:  http://$EC2_IP"
    if [ -n "$DOMAIN" ]; then
        echo "  HTTPS: https://$DOMAIN"
    fi
    echo ""
    echo "To check logs: ssh -i $EC2_KEY_PATH $EC2_USER@$EC2_IP 'cd $PROJECT_NAME && docker-compose logs -f'"
    echo "To restart: ssh -i $EC2_KEY_PATH $EC2_USER@$EC2_IP 'cd $PROJECT_NAME && docker-compose restart'"
}

# Run main function with all arguments
main "$@" 