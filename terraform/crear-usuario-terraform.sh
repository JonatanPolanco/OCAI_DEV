#!/bin/bash
# Script para crear usuario IAM para Terraform
# Requiere permisos de administrador de IAM

set -e

echo "============================================"
echo "  Crear Usuario IAM para Terraform"
echo "============================================"
echo ""

# Colores
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
USERNAME="terraform-deployer"
POLICY_NAME="TerraformOCAIDeployPolicy"
POLICY_FILE="iam-policy-terraform.json"

echo -e "${BLUE}[1/5] Verificando permisos...${NC}"
# Verificar que tenemos permisos de IAM
if ! aws iam get-user --user-name $(aws sts get-caller-identity --query 'Arn' --output text | cut -d'/' -f2) &>/dev/null; then
    echo -e "${RED}Error: No tienes permisos de IAM${NC}"
    echo -e "${YELLOW}Este script requiere permisos de administrador de IAM${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Permisos verificados${NC}"

echo ""
echo -e "${BLUE}[2/5] Creando usuario IAM: $USERNAME...${NC}"
if aws iam get-user --user-name "$USERNAME" &>/dev/null; then
    echo -e "${YELLOW}⚠ Usuario ya existe${NC}"
else
    aws iam create-user --user-name "$USERNAME" --tags Key=Purpose,Value=Terraform Key=Project,Value=OCAI-Medical
    echo -e "${GREEN}✓ Usuario creado${NC}"
fi

echo ""
echo -e "${BLUE}[3/5] Creando política personalizada...${NC}"
if aws iam get-policy --policy-arn "arn:aws:iam::$(aws sts get-caller-identity --query 'Account' --output text):policy/$POLICY_NAME" &>/dev/null; then
    echo -e "${YELLOW}⚠ Política ya existe${NC}"
    POLICY_ARN="arn:aws:iam::$(aws sts get-caller-identity --query 'Account' --output text):policy/$POLICY_NAME"
else
    POLICY_ARN=$(aws iam create-policy \
        --policy-name "$POLICY_NAME" \
        --policy-document "file://$POLICY_FILE" \
        --description "Permisos minimos para desplegar infraestructura OCAI con Terraform" \
        --query 'Policy.Arn' \
        --output text)
    echo -e "${GREEN}✓ Política creada: $POLICY_ARN${NC}"
fi

echo ""
echo -e "${BLUE}[4/5] Asignando política al usuario...${NC}"
aws iam attach-user-policy \
    --user-name "$USERNAME" \
    --policy-arn "$POLICY_ARN"
echo -e "${GREEN}✓ Política asignada${NC}"

echo ""
echo -e "${BLUE}[5/5] Creando Access Keys...${NC}"
ACCESS_KEY_OUTPUT=$(aws iam create-access-key --user-name "$USERNAME")
ACCESS_KEY_ID=$(echo "$ACCESS_KEY_OUTPUT" | jq -r '.AccessKey.AccessKeyId')
SECRET_ACCESS_KEY=$(echo "$ACCESS_KEY_OUTPUT" | jq -r '.AccessKey.SecretAccessKey')

echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Usuario IAM Creado Exitosamente${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "${YELLOW}IMPORTANTE: Guarda estas credenciales de forma segura${NC}"
echo -e "${YELLOW}El Secret Access Key solo se muestra una vez${NC}"
echo ""
echo -e "${BLUE}Usuario:${NC} $USERNAME"
echo -e "${BLUE}Access Key ID:${NC} $ACCESS_KEY_ID"
echo -e "${BLUE}Secret Access Key:${NC} $SECRET_ACCESS_KEY"
echo ""

# Guardar en archivo temporal
CREDS_FILE="terraform-aws-credentials-$(date +%Y%m%d-%H%M%S).txt"
cat > "$CREDS_FILE" << EOF
# Credenciales AWS para Terraform - OCAI Medical
# Creado: $(date)
# MANTENER SEGURO - NO SUBIR A GIT

Usuario: $USERNAME
Access Key ID: $ACCESS_KEY_ID
Secret Access Key: $SECRET_ACCESS_KEY

# Configurar perfil AWS:
aws configure --profile terraform

# O agregar manualmente a ~/.aws/credentials:
[terraform]
aws_access_key_id = $ACCESS_KEY_ID
aws_secret_access_key = $SECRET_ACCESS_KEY
region = us-east-1

# Usar con deploy:
export AWS_PROFILE=terraform
./deploy-terraform.sh
EOF

echo -e "${GREEN}✓ Credenciales guardadas en: $CREDS_FILE${NC}"
echo ""
echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Próximos Pasos${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo "1. Configurar perfil AWS:"
echo -e "   ${GREEN}aws configure --profile terraform${NC}"
echo ""
echo "2. Usar el nuevo perfil con deploy:"
echo -e "   ${GREEN}export AWS_PROFILE=terraform${NC}"
echo -e "   ${GREEN}./deploy-terraform.sh${NC}"
echo ""
echo "3. O en PowerShell:"
echo -e "   ${GREEN}\$env:AWS_PROFILE = \"terraform\"${NC}"
echo -e "   ${GREEN}.\\deploy-terraform.ps1${NC}"
echo ""
echo -e "${YELLOW}Recuerda eliminar el archivo de credenciales después de configurar AWS CLI${NC}"
echo ""
