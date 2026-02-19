# Script PowerShell para deployar Lambda a AWS
$ErrorActionPreference = "Stop"

$LAMBDA_NAME = "ocai-appointment-store"
$REGION = "us-east-1"
$RUNTIME = "python3.11"
$HANDLER = "lambda_appointment_store.lambda_handler"
$TIMEOUT = 30
$MEMORY = 256

Write-Host "=== Deploying Lambda: $LAMBDA_NAME ===" -ForegroundColor Cyan
Write-Host ""

# Verificar AWS CLI
Write-Host "[1/6] Verificando AWS CLI..." -ForegroundColor Yellow
try {
    aws sts get-caller-identity | Out-Null
    Write-Host "✓ Credenciales OK" -ForegroundColor Green
} catch {
    Write-Host "Error: AWS CLI no está instalado o no hay credenciales configuradas" -ForegroundColor Red
    exit 1
}

# Crear directorio temporal
Write-Host "[2/6] Creando package..." -ForegroundColor Yellow
if (Test-Path package) { Remove-Item -Recurse -Force package }
if (Test-Path lambda_appointment_store.zip) { Remove-Item -Force lambda_appointment_store.zip }
New-Item -ItemType Directory -Path package | Out-Null

# Instalar dependencias
pip install -r requirements.txt -t package/ --quiet
Write-Host "✓ Dependencias instaladas" -ForegroundColor Green

# Copiar código
Copy-Item lambda_appointment_store.py package/
Write-Host "✓ Código copiado" -ForegroundColor Green

# Crear ZIP
Write-Host "[3/6] Creando ZIP..." -ForegroundColor Yellow
Compress-Archive -Path package\* -DestinationPath lambda_appointment_store.zip -Force
$zipSize = (Get-Item lambda_appointment_store.zip).Length / 1MB
Write-Host "✓ ZIP creado: lambda_appointment_store.zip ($([math]::Round($zipSize, 2)) MB)" -ForegroundColor Green

# Verificar si Lambda existe
Write-Host "[4/6] Verificando si Lambda existe..." -ForegroundColor Yellow
try {
    aws lambda get-function --function-name $LAMBDA_NAME --region $REGION 2>$null | Out-Null
    $lambdaExists = $true
} catch {
    $lambdaExists = $false
}

if ($lambdaExists) {
    Write-Host "Lambda existe, actualizando código..." -ForegroundColor Yellow

    $result = aws lambda update-function-code `
        --function-name $LAMBDA_NAME `
        --zip-file fileb://lambda_appointment_store.zip `
        --region $REGION `
        --output json | ConvertFrom-Json

    Write-Host "✓ Código actualizado" -ForegroundColor Green
    Write-Host "FunctionArn: $($result.FunctionArn)" -ForegroundColor Cyan
} else {
    Write-Host "Lambda no existe, creando nueva..." -ForegroundColor Yellow

    # Crear IAM role si no existe
    $ROLE_NAME = "${LAMBDA_NAME}-role"
    try {
        $roleArn = (aws iam get-role --role-name $ROLE_NAME --query 'Role.Arn' --output text 2>$null)
    } catch {
        Write-Host "Creando IAM role..." -ForegroundColor Yellow

        $trustPolicy = @{
            Version = "2012-10-17"
            Statement = @(
                @{
                    Effect = "Allow"
                    Principal = @{ Service = "lambda.amazonaws.com" }
                    Action = "sts:AssumeRole"
                }
            )
        } | ConvertTo-Json -Depth 10

        aws iam create-role `
            --role-name $ROLE_NAME `
            --assume-role-policy-document $trustPolicy | Out-Null

        aws iam attach-role-policy `
            --role-name $ROLE_NAME `
            --policy-arn arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole

        $roleArn = (aws iam get-role --role-name $ROLE_NAME --query 'Role.Arn' --output text)
        Write-Host "Esperando 10s para que el role se propague..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
    }

    $result = aws lambda create-function `
        --function-name $LAMBDA_NAME `
        --runtime $RUNTIME `
        --role $roleArn `
        --handler $HANDLER `
        --zip-file fileb://lambda_appointment_store.zip `
        --timeout $TIMEOUT `
        --memory-size $MEMORY `
        --region $REGION `
        --output json | ConvertFrom-Json

    Write-Host "✓ Lambda creada" -ForegroundColor Green
    Write-Host "FunctionArn: $($result.FunctionArn)" -ForegroundColor Cyan
}

# Configurar variables de entorno
Write-Host "[5/6] Configurando variables de entorno..." -ForegroundColor Yellow
Write-Host "⚠️  IMPORTANTE: Configurar manualmente en AWS Console:" -ForegroundColor Red
Write-Host "    DB_HOST, DB_PORT, DB_NAME, DB_USER, DB_PASSWORD" -ForegroundColor Yellow

# Limpiar
Write-Host "[6/6] Limpiando archivos temporales..." -ForegroundColor Yellow
Remove-Item -Recurse -Force package
Write-Host "✓ Limpieza completada" -ForegroundColor Green

Write-Host ""
Write-Host "=== ✓ Deployment completado ===" -ForegroundColor Green
Write-Host ""

$functionArn = aws lambda get-function --function-name $LAMBDA_NAME --region $REGION --query 'Configuration.FunctionArn' --output text
Write-Host "Lambda ARN: $functionArn" -ForegroundColor Cyan

Write-Host ""
Write-Host "Próximos pasos:" -ForegroundColor Yellow
Write-Host "1. Configurar variables de entorno en AWS Console"
Write-Host "2. Configurar VPC si RDS está en VPC privada"
Write-Host "3. Ajustar Security Group para permitir conexión a RDS"
Write-Host "4. Crear API Gateway para exponer la Lambda"
Write-Host "5. Probar con: aws lambda invoke --function-name $LAMBDA_NAME output.json"
