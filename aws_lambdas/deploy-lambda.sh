#!/bin/bash
# Script para deployar Lambda a AWS
set -e

LAMBDA_NAME="ocai-appointment-store"
REGION="us-east-1"
RUNTIME="python3.11"
HANDLER="lambda_appointment_store.lambda_handler"
TIMEOUT=30
MEMORY=256

echo "=== Deploying Lambda: $LAMBDA_NAME ==="
echo ""

# Verificar AWS CLI
if ! command -v aws &> /dev/null; then
    echo "Error: AWS CLI no está instalado"
    exit 1
fi

# Verificar credenciales
echo "[1/6] Verificando credenciales AWS..."
aws sts get-caller-identity > /dev/null 2>&1 || {
    echo "Error: No hay credenciales AWS configuradas"
    exit 1
}
echo "✓ Credenciales OK"

# Crear directorio temporal
echo "[2/6] Creando package..."
rm -rf package lambda_appointment_store.zip
mkdir -p package

# Instalar dependencias
pip install -r requirements.txt -t package/ --quiet
echo "✓ Dependencias instaladas"

# Copiar código
cp lambda_appointment_store.py package/
echo "✓ Código copiado"

# Crear ZIP
echo "[3/6] Creando ZIP..."
cd package
zip -r ../lambda_appointment_store.zip . -q
cd ..
echo "✓ ZIP creado: lambda_appointment_store.zip ($(du -h lambda_appointment_store.zip | cut -f1))"

# Verificar si Lambda existe
echo "[4/6] Verificando si Lambda existe..."
if aws lambda get-function --function-name $LAMBDA_NAME --region $REGION &> /dev/null; then
    echo "Lambda existe, actualizando código..."

    aws lambda update-function-code \
        --function-name $LAMBDA_NAME \
        --zip-file fileb://lambda_appointment_store.zip \
        --region $REGION \
        --output json | jq -r '.FunctionArn'

    echo "✓ Código actualizado"
else
    echo "Lambda no existe, creando nueva..."

    # Crear IAM role si no existe (simplificado)
    ROLE_NAME="${LAMBDA_NAME}-role"
    ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME --query 'Role.Arn' --output text 2>/dev/null || echo "")

    if [ -z "$ROLE_ARN" ]; then
        echo "Creando IAM role..."
        aws iam create-role \
            --role-name $ROLE_NAME \
            --assume-role-policy-document '{
                "Version": "2012-10-17",
                "Statement": [{
                    "Effect": "Allow",
                    "Principal": {"Service": "lambda.amazonaws.com"},
                    "Action": "sts:AssumeRole"
                }]
            }' > /dev/null

        aws iam attach-role-policy \
            --role-name $ROLE_NAME \
            --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

        ROLE_ARN=$(aws iam get-role --role-name $ROLE_NAME --query 'Role.Arn' --output text)
        echo "Esperando 10s para que el role se propague..."
        sleep 10
    fi

    aws lambda create-function \
        --function-name $LAMBDA_NAME \
        --runtime $RUNTIME \
        --role $ROLE_ARN \
        --handler $HANDLER \
        --zip-file fileb://lambda_appointment_store.zip \
        --timeout $TIMEOUT \
        --memory-size $MEMORY \
        --region $REGION \
        --output json | jq -r '.FunctionArn'

    echo "✓ Lambda creada"
fi

# Configurar variables de entorno
echo "[5/6] Configurando variables de entorno..."
echo "⚠️  IMPORTANTE: Configurar manualmente en AWS Console:"
echo "    DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD"

# Limpiar
echo "[6/6] Limpiando archivos temporales..."
rm -rf package
echo "✓ Limpieza completada"

echo ""
echo "=== ✓ Deployment completado ==="
echo ""
echo "Lambda ARN:"
aws lambda get-function --function-name $LAMBDA_NAME --region $REGION --query 'Configuration.FunctionArn' --output text

echo ""
echo "Próximos pasos:"
echo "1. Configurar variables de entorno en AWS Console"
echo "2. Configurar VPC si RDS está en VPC privada"
echo "3. Ajustar Security Group para permitir conexión a RDS"
echo "4. Crear API Gateway para exponer la Lambda"
echo "5. Probar con: aws lambda invoke --function-name $LAMBDA_NAME output.json"
