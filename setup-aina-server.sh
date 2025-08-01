#!/bin/bash

# Aina Server Setup Script
# Bu script AWS'de aina-server için gerekli kaynakları oluşturur

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
        print_error "AWS CLI yüklü değil. Lütfen önce yükleyin."
        echo "Yükleme: https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html"
        exit 1
    fi
    
    if ! aws sts get-caller-identity >/dev/null 2>&1; then
        print_error "AWS CLI yapılandırılmamış. Lütfen 'aws configure' çalıştırın."
        exit 1
    fi
    
    print_success "AWS CLI düzgün yapılandırılmış"
}

# Function to create EC2 key pair
create_key_pair() {
    local KEY_NAME="$1"
    
    if [ -z "$KEY_NAME" ]; then
        KEY_NAME="aina-server-key"
    fi
    
    print_status "EC2 key pair oluşturuluyor: $KEY_NAME"
    
    # Check if key pair already exists
    if aws ec2 describe-key-pairs --key-names "$KEY_NAME" >/dev/null 2>&1; then
        print_warning "Key pair '$KEY_NAME' zaten mevcut"
        return
    fi
    
    # Create key pair
    aws ec2 create-key-pair \
        --key-name "$KEY_NAME" \
        --query 'KeyMaterial' \
        --output text > "${KEY_NAME}.pem"
    
    # Set proper permissions
    chmod 400 "${KEY_NAME}.pem"
    
    print_success "Key pair oluşturuldu: ${KEY_NAME}.pem"
}

# Function to deploy CloudFormation stack
deploy_stack() {
    local STACK_NAME="$1"
    local KEY_NAME="$2"
    
    if [ -z "$STACK_NAME" ]; then
        STACK_NAME="aina-server"
    fi
    
    if [ -z "$KEY_NAME" ]; then
        KEY_NAME="aina-server-key"
    fi
    
    print_status "CloudFormation stack dağıtılıyor: $STACK_NAME"
    
    # Check if stack already exists
    if aws cloudformation describe-stacks --stack-name "$STACK_NAME" >/dev/null 2>&1; then
        print_warning "Stack '$STACK_NAME' zaten mevcut"
        return
    fi
    
    # Deploy stack
    aws cloudformation create-stack \
        --stack-name "$STACK_NAME" \
        --template-body file://simple-cloudformation-template.yml \
        --parameters ParameterKey=KeyPairName,ParameterValue="$KEY_NAME"
    
    print_success "CloudFormation stack dağıtımı başladı"
    print_status "İlerlemeyi takip edebilirsiniz:"
    echo "  aws cloudformation describe-stacks --stack-name $STACK_NAME --query 'Stacks[0].StackStatus'"
}

# Function to get stack outputs
get_stack_outputs() {
    local STACK_NAME="$1"
    
    if [ -z "$STACK_NAME" ]; then
        STACK_NAME="aina-server"
    fi
    
    print_status "Stack çıktıları alınıyor: $STACK_NAME"
    
    # Wait for stack to complete
    print_status "Stack tamamlanması bekleniyor..."
    aws cloudformation wait stack-create-complete --stack-name "$STACK_NAME"
    
    # Get outputs
    OUTPUTS=$(aws cloudformation describe-stacks --stack-name "$STACK_NAME" --query 'Stacks[0].Outputs')
    
    print_success "Stack dağıtımı tamamlandı!"
    echo ""
    echo "Stack Çıktıları:"
    echo "$OUTPUTS" | jq -r '.[] | "\(.OutputKey): \(.OutputValue)"'
    
    # Extract important values
    EC2_IP=$(echo "$OUTPUTS" | jq -r '.[] | select(.OutputKey=="PublicIP") | .OutputValue')
    KEY_NAME="aina-server-key"
    
    echo ""
    echo "Sonraki adımlar:"
    echo "1. Uygulamanızı dağıtın:"
    echo "   ./aws-deploy.sh --ec2-ip $EC2_IP --key-path ${KEY_NAME}.pem --api-key YOUR_GEMINI_API_KEY"
    echo ""
    echo "2. Veya instance'a bağlanın:"
    echo "   ssh -i ${KEY_NAME}.pem ubuntu@$EC2_IP"
}

# Function to show usage
show_usage() {
    echo "Kullanım: $0 [SEÇENEKLER]"
    echo ""
    echo "Seçenekler:"
    echo "  --key-name NAME        EC2 key pair adı (varsayılan: aina-server-key)"
    echo "  --stack-name NAME      CloudFormation stack adı (varsayılan: aina-server)"
    echo "  --skip-key-creation    Key pair oluşturmayı atla"
    echo "  --skip-stack-deploy    CloudFormation stack dağıtımını atla"
    echo "  --help                 Bu yardım mesajını göster"
    echo ""
    echo "Örnek:"
    echo "  $0 --key-name my-key --stack-name my-aina-server"
}

# Main function
main() {
    local KEY_NAME="aina-server-key"
    local STACK_NAME="aina-server"
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
                print_error "Bilinmeyen seçenek: $1"
                show_usage
                exit 1
                ;;
        esac
    done
    
    print_status "Aina Server AWS kurulumu başlatılıyor..."
    
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
    
    print_success "AWS kurulumu tamamlandı!"
    echo ""
    echo "Oluşturulan dosyalar:"
    echo "  - ${KEY_NAME}.pem (EC2 key pair)"
    echo "  - simple-cloudformation-template.yml (CloudFormation template)"
    echo "  - aws-deploy.sh (Dağıtım script'i)"
    echo ""
    echo "Sonraki adımlar:"
    echo "1. Google AI Studio'dan Gemini API key'inizi alın"
    echo "2. Uygulamanızı dağıtım script'i ile dağıtın"
    echo "3. Uygulama loglarını takip edin"
}

# Run main function with all arguments
main "$@" 