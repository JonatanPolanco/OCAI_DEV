#!/bin/bash
# Script automatizado para desplegar infraestructura OCAI con Terraform
# Ejecutar después de reiniciar la terminal

set -e  # Exit on error

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  OCAI Medical - Despliegue con Terraform${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Verificar que estamos en el directorio correcto
if [ ! -f "terraform/main.tf" ]; then
    echo -e "${RED}Error: Este script debe ejecutarse desde la raíz del proyecto OCAI_DEV${NC}"
    echo "Navega a: cd \"C:\Users\JonatanDavidPolancoH\OneDrive - Perceptio S.A.S\Escritorio\OCAI_DEV\""
    exit 1
fi

# Verificar pre-requisitos
echo -e "${YELLOW}[1/8] Verificando pre-requisitos...${NC}"

# Verificar Terraform
if ! command -v terraform &> /dev/null; then
    echo -e "${RED}✗ Terraform no está instalado o no está en PATH${NC}"
    echo "Solución: Reinicia la terminal después de instalar Terraform"
    exit 1
fi
echo -e "${GREEN}✓ Terraform instalado: $(terraform --version | head -n1)${NC}"

# Verificar AWS CLI
if ! command -v aws &> /dev/null; then
    echo -e "${RED}✗ AWS CLI no está instalado${NC}"
    echo "Solución: winget install Amazon.AWSCLI"
    exit 1
fi
echo -e "${GREEN}✓ AWS CLI instalado: $(aws --version)${NC}"

# Verificar credenciales AWS
if ! aws sts get-caller-identity &> /dev/null; then
    echo -e "${RED}✗ AWS CLI no está configurado${NC}"
    echo "Solución: aws configure"
    exit 1
fi
echo -e "${GREEN}✓ AWS credenciales configuradas${NC}"

# Verificar SSH key
if [ ! -f ~/.ssh/id_rsa.pub ]; then
    echo -e "${RED}✗ SSH key no encontrado${NC}"
    echo "Solución: ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N \"\""
    exit 1
fi
echo -e "${GREEN}✓ SSH key encontrado${NC}"

# Verificar terraform.tfvars
if [ ! -f terraform/terraform.tfvars ]; then
    echo -e "${RED}✗ terraform.tfvars no encontrado${NC}"
    echo "Solución: cp terraform/terraform.tfvars.example terraform/terraform.tfvars"
    exit 1
fi

# Verificar que la contraseña fue cambiada
if grep -q "CAMBIAR-CONTRASEÑA-SEGURA-AQUI" terraform/terraform.tfvars; then
    echo -e "${RED}✗ Contraseña por defecto detectada en terraform.tfvars${NC}"
    echo "Solución: Editar terraform/terraform.tfvars y cambiar db_password"
    exit 1
fi
echo -e "${GREEN}✓ terraform.tfvars configurado${NC}"

echo ""
echo -e "${YELLOW}[2/8] Navegando a carpeta terraform...${NC}"
cd terraform
echo -e "${GREEN}✓ En: $(pwd)${NC}"

echo ""
echo -e "${YELLOW}[3/8] Inicializando Terraform...${NC}"
terraform init
echo -e "${GREEN}✓ Terraform inicializado${NC}"

echo ""
echo -e "${YELLOW}[4/8] Validando configuración...${NC}"
terraform validate
echo -e "${GREEN}✓ Configuración válida${NC}"

echo ""
echo -e "${YELLOW}[5/8] Mostrando plan de ejecución...${NC}"
echo -e "${BLUE}Terraform creará los siguientes recursos:${NC}"
echo ""
terraform plan -no-color | grep -E "Plan:|will be created" || terraform plan

echo ""
echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}  ¿Deseas crear la infraestructura?${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo -e "Esto creará en AWS:"
echo -e "  • 1 RDS PostgreSQL (db.t3.micro)"
echo -e "  • 1 EC2 Instance (t3.small)"
echo -e "  • 2 Security Groups"
echo -e "  • 1 Elastic IP"
echo -e "  • Configuración automática de Docker + n8n"
echo ""
echo -e "⏱️  Tiempo estimado: ${BLUE}10-15 minutos${NC}"
echo -e "💰 Costo mensual estimado: ${BLUE}\$40-50${NC}"
echo ""
echo -e "${YELLOW}Presiona Enter para continuar o Ctrl+C para cancelar...${NC}"
read -r

echo ""
echo -e "${YELLOW}[6/8] Aplicando configuración con Terraform...${NC}"
terraform apply -auto-approve

if [ $? -eq 0 ]; then
    echo ""
    echo -e "${GREEN}✓ Infraestructura creada exitosamente!${NC}"
else
    echo ""
    echo -e "${RED}✗ Error al crear infraestructura${NC}"
    echo "Revisa los mensajes de error arriba"
    exit 1
fi

echo ""
echo -e "${YELLOW}[7/8] Guardando outputs...${NC}"
terraform output > ../terraform-outputs.txt
echo -e "${GREEN}✓ Outputs guardados en: terraform-outputs.txt${NC}"

echo ""
echo -e "${YELLOW}[8/8] Mostrando información de conexión...${NC}"
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Infraestructura Desplegada${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

RDS_ENDPOINT=$(terraform output -raw rds_endpoint)
EC2_IP=$(terraform output -raw ec2_public_ip)
SSH_CMD=$(terraform output -raw ssh_command)

echo -e "${BLUE}RDS PostgreSQL:${NC}"
echo -e "  Endpoint: ${GREEN}$RDS_ENDPOINT${NC}"
echo -e "  Database: ${GREEN}n8n_db${NC}"
echo -e "  Username: ${GREEN}postgres${NC}"
echo -e "  Password: ${GREEN}[Ver terraform.tfvars]${NC}"
echo ""
echo -e "${BLUE}EC2 Instance:${NC}"
echo -e "  IP Pública: ${GREEN}$EC2_IP${NC}"
echo -e "  SSH: ${GREEN}$SSH_CMD${NC}"
echo ""
echo -e "${BLUE}n8n URL:${NC}"
echo -e "  ${GREEN}https://n8n.ocaihealth.com${NC}"
echo -e "  (Configurar DNS primero)${NC}"
echo ""

echo -e "${YELLOW}========================================${NC}"
echo -e "${YELLOW}  Próximos Pasos${NC}"
echo -e "${YELLOW}========================================${NC}"
echo ""
echo -e "1. ${BLUE}Aplicar scripts SQL a RDS:${NC}"
echo -e "   cd ../migration"
echo -e "   ./1-setup-rds.sh $RDS_ENDPOINT postgres n8n_db"
echo ""
echo -e "2. ${BLUE}Configurar DNS:${NC}"
echo -e "   n8n.ocaihealth.com → $EC2_IP"
echo ""
echo -e "3. ${BLUE}Conectar por SSH:${NC}"
echo -e "   $SSH_CMD"
echo ""
echo -e "4. ${BLUE}Acceder a n8n:${NC}"
echo -e "   https://n8n.ocaihealth.com (después de configurar DNS)"
echo ""
echo -e "${GREEN}✅ Despliegue completado exitosamente!${NC}"
echo ""
