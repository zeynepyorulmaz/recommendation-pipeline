#!/bin/bash

# AWS Setup Script for Fashion Recommendation Pipeline
# This script helps set up AWS CLI and create necessary resources

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Function to check AWS CLI configuration
check_aws_config() {
    if ! command_exists aws; then
        print_error "AWS CLI is not installed. Please install it first."
        echo "Installation guide: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        exit 1
    fi
    
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        print_error "AWS CLI is not configured. Please run 'aws configure' first."
        exit 1
    fi
    
    print_success "AWS CLI is properly configured"
}

# Function to create EC2 key pair
create_key_pair() {
    local KEY_NAME="$1"
    
    if [ -z "$KEY_NAME" ]; then
        KEY_NAME="fashion-pipeline-key"
    fi
    
    print_status "Creating EC2 key pair: $KEY_NAME"
    
    # Check if key pair already exists
    if aws ec2 describe-key-pairs --key-names "$KEY_NAME" >/dev/null 2>&1; then
        print_warning "Key pair '$KEY_NAME' already exists"
        return
    fi
    
    # Create key pair
    aws ec2 create-key-pair \
        --key-name "$KEY_NAME" \
        --query 'KeyMaterial' \
        --output text > "${KEY_NAME}.pem"
    
    # Set proper permissions
    chmod 400 "${KEY_NAME}.pem"
    
    print_success "Key pair created: ${KEY_NAME}.pem"
}

# Function to deploy CloudFormation stack
deploy_stack() {
    local STACK_NAME="$1"
    local KEY_NAME="$2"
    
    if [ -z "$STACK_NAME" ]; then
        STACK_NAME="fashion-pipeline"
    fi
    
    if [ -z "$KEY_NAME" ]; then
        KEY_NAME="fashion-pipeline-key"
    fi
    
    print_status "Deploying CloudFormation stack: $STACK_NAME"
    
    # Check if stack already exists
    if aws cloudformation describe-stacks --stack-name "$STACK_NAME" >/dev/null 2>&1; then
        print_warning "Stack '$STACK_NAME' already exists"
        return
    fi
    
    # Deploy stack
    aws cloudformation create-stack \
        --stack-name "$STACK_NAME" \
        --template-body file://cloudformation-template.yml \
        --parameters ParameterKey=KeyPairName,ParameterValue="$KEY_NAME" \
        --capabilities CAPABILITY_NAMED_IAM
    
    print_success "CloudFormation stack deployment started"
    print_status "You can monitor the progress with:"
    echo "  aws cloudformation describe-stacks --stack-name $STACK_NAME --query 'Stacks[0].StackStatus'"
}

# Function to get stack outputs
get_stack_outputs() {
    local STACK_NAME="$1"
    
    if [ -z "$STACK_NAME" ]; then
        STACK_NAME="fashion-pipeline"
    fi
    
    print_status "Getting stack outputs for: $STACK_NAME"
    
    # Wait for stack to complete
    print_status "Waiting for stack to complete..."
    aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME"
    
    # Get outputs
    OUTPUTS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query 'Stacks[0].Outputs')
    
    print_success "Stack deployment completed!"
    echo ""
    echo "Stack Outputs:"
    echo "$OUTPUTS" | jq -r '.[] | "\(.OutputKey): \(.OutputValue)"'
    
    # Extract important values
    EC2_IP=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="PublicIP") | .OutputValue')
    KEY_NAME="fashion-pipeline-key"
    
    echo ""
    echo "Next steps:"
    echo "1. Deploy your application:"
    echo "   ./aws-deploy.sh --ec2-ip $EC2_IP --key-path ${KEY_NAME}.pem --api-key YOUR_GEMINI_API_KEY"
    echo ""
    echo "2. Or connect to your instance:"
    echo "   ssh -i ${KEY_NAME}.pem ubuntu@$EC2_IP"
}

# Function to show usage
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --key-name NAME        Name for the EC2 key pair (default: fashion-pipeline-key)"
    echo "  --stack-name NAME      Name for the CloudFormation stack (default: fashion-pipeline)"
    echo "  --skip-key-creation    Skip key pair creation"
    echo "  --skip-stack-deploy    Skip CloudFormation stack deployment"
    echo "  --help                 Show this help message"
    echo ""
    echo "Example:"
    echo "  $0 --key-name my-key --stack-name my-pipeline"
}

# Main function
main() {
    local KEY_NAME="fashion-pipeline-key"
    local STACK_NAME="fashion-pipeline"
    local SKIP_KEY_CREATION=false
    local SKIP_STACK_DEPLOY=false
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --key-name)
                KEY_NAME="$2"
                shift 2
                ;;
            --stack-name)
                STACK_NAME="$2"
                shift 2
                ;;
            --skip-key-creation)
                SKIP_KEY_CREATION=true
                shift
                ;;
            --skip-stack-deploy)
                SKIP_STACK_DEPLOY=true
                shift
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
    
    print_status "Starting AWS setup for Fashion Recommendation Pipeline..."
    
    # Check AWS CLI configuration
    check_aws_config
    
    # Create key pair (if not skipped)
    if [ "$SKIP_KEY_CREATION" != "true" ]; then
        create_key_pair "$KEY_NAME"
    fi
    
    # Deploy CloudFormation stack (if not skipped)
    if [ "$SKIP_STACK_DEPLOY" != "true" ]; then
        deploy_stack "$STACK_NAME" "$KEY_NAME"
        get_stack_outputs "$STACK_NAME"
    fi
    
    print_success "AWS setup completed!"
    echo ""
    echo "Files created:"
    echo "  - ${KEY_NAME}.pem (EC2 key pair)"
    echo "  - cloudformation-template.yml (CloudFormation template)"
    echo "  - aws-deploy.sh (Deployment script)"
    echo ""
    echo "Next steps:"
    echo "1. Get your Gemini API key from Google AI Studio"
    echo "2. Deploy your application using the deployment script"
    echo "3. Monitor your application logs"
}

# Run main function with all arguments
main "$@" 