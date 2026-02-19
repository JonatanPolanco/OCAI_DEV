# PowerShell Script para desplegar infraestructura OCAI con Terraform
# Ejecutar en PowerShell
#
# Uso:
#   .\deploy-terraform.ps1                  # Usa credenciales por defecto
#   .\deploy-terraform.ps1 -Profile terraform  # Usa perfil específico

param(
    [string]$Profile = ""
)

$ErrorActionPreference = "Continue"

Write-Host "========================================" -ForegroundColor Blue
Write-Host "  OCAI Medical - Despliegue con Terraform" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""

# Configurar perfil de AWS si se especificó
if ($Profile -ne "") {
    Write-Host "Usando perfil de AWS: $Profile" -ForegroundColor Cyan
    $env:AWS_PROFILE = $Profile
}

# Verificar que estamos en el directorio correcto
if (-not (Test-Path "terraform\main.tf")) {
    Write-Host "Error: Este script debe ejecutarse desde la raíz del proyecto OCAI_DEV" -ForegroundColor Red
    Write-Host "Navega a: cd 'C:\Users\JonatanDavidPolancoH\OneDrive - Perceptio S.A.S\Escritorio\OCAI_DEV'" -ForegroundColor Yellow
    exit 1
}

# Verificar pre-requisitos
Write-Host "[1/8] Verificando pre-requisitos..." -ForegroundColor Yellow

# Verificar Terraform
$tfCheck = Get-Command terraform -ErrorAction SilentlyContinue
if (-not $tfCheck) {
    Write-Host "X Terraform no esta instalado o no esta en PATH" -ForegroundColor Red
    Write-Host "Solucion: Reinicia PowerShell despues de instalar Terraform" -ForegroundColor Yellow
    exit 1
}
$tfVersion = terraform --version 2>&1 | Select-Object -First 1
Write-Host "OK Terraform instalado: $tfVersion" -ForegroundColor Green

# Verificar AWS CLI
$awsCheck = Get-Command aws -ErrorAction SilentlyContinue
if (-not $awsCheck) {
    Write-Host "X AWS CLI no esta instalado" -ForegroundColor Red
    Write-Host "Solucion: winget install Amazon.AWSCLI" -ForegroundColor Yellow
    exit 1
}
$awsVersion = aws --version 2>&1
Write-Host "OK AWS CLI instalado: $awsVersion" -ForegroundColor Green

# Verificar credenciales AWS
$awsIdentity = aws sts get-caller-identity 2>&1 | ConvertFrom-Json
if ($LASTEXITCODE -ne 0) {
    Write-Host "X AWS CLI no esta configurado" -ForegroundColor Red
    Write-Host "Solucion: aws configure" -ForegroundColor Yellow
    exit 1
}
$awsUserArn = $awsIdentity.Arn
Write-Host "OK AWS credenciales configuradas" -ForegroundColor Green
Write-Host "   Usuario: $awsUserArn" -ForegroundColor Gray

# Advertir si se está usando usuario de Bedrock
if ($awsUserArn -match "BedrockAPIKey") {
    Write-Host ""
    Write-Host "ADVERTENCIA: Estas usando un usuario de Bedrock API" -ForegroundColor Yellow
    Write-Host "Este usuario probablemente NO tiene permisos para EC2/RDS" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Soluciones:" -ForegroundColor Cyan
    Write-Host "1. Crear usuario dedicado para Terraform (ver SOLUCION-PERMISOS-AWS.md)" -ForegroundColor White
    Write-Host "2. Ejecutar con perfil diferente:" -ForegroundColor White
    Write-Host "   .\deploy-terraform.ps1 -Profile terraform" -ForegroundColor Gray
    Write-Host ""
    $continue = Read-Host "Continuar de todos modos? (y/N)"
    if ($continue -ne "y" -and $continue -ne "Y") {
        Write-Host "Operacion cancelada" -ForegroundColor Yellow
        exit 0
    }
}

# Verificar SSH key
$sshKeyPath = "$env:USERPROFILE\.ssh\id_rsa.pub"
if (-not (Test-Path $sshKeyPath)) {
    Write-Host "X SSH key no encontrado en $sshKeyPath" -ForegroundColor Red
    Write-Host "Solucion: ssh-keygen -t rsa -b 4096 -f $env:USERPROFILE\.ssh\id_rsa" -ForegroundColor Yellow
    exit 1
}
Write-Host "OK SSH key encontrado" -ForegroundColor Green

# Verificar terraform.tfvars
if (-not (Test-Path "terraform\terraform.tfvars")) {
    Write-Host "X terraform.tfvars no encontrado" -ForegroundColor Red
    Write-Host "Solucion: cp terraform\terraform.tfvars.example terraform\terraform.tfvars" -ForegroundColor Yellow
    exit 1
}

# Verificar que la contraseña fue cambiada
$tfvarsContent = Get-Content "terraform\terraform.tfvars" -Raw
if ($tfvarsContent -match "CAMBIAR-CONTRASE") {
    Write-Host "X Contraseña por defecto detectada en terraform.tfvars" -ForegroundColor Red
    Write-Host "Solucion: Editar terraform\terraform.tfvars y cambiar db_password" -ForegroundColor Yellow
    exit 1
}
Write-Host "OK terraform.tfvars configurado" -ForegroundColor Green

Write-Host ""
Write-Host "[2/8] Navegando a carpeta terraform..." -ForegroundColor Yellow
Set-Location terraform
Write-Host "OK En: $(Get-Location)" -ForegroundColor Green

Write-Host ""
Write-Host "[3/8] Inicializando Terraform..." -ForegroundColor Yellow
terraform init
if ($LASTEXITCODE -ne 0) {
    Write-Host "X Error al inicializar Terraform" -ForegroundColor Red
    Set-Location ..
    exit 1
}
Write-Host "OK Terraform inicializado" -ForegroundColor Green

Write-Host ""
Write-Host "[4/8] Validando configuracion..." -ForegroundColor Yellow
terraform validate
if ($LASTEXITCODE -ne 0) {
    Write-Host "X Configuracion invalida" -ForegroundColor Red
    Set-Location ..
    exit 1
}
Write-Host "OK Configuracion valida" -ForegroundColor Green

Write-Host ""
Write-Host "[5/8] Mostrando plan de ejecucion..." -ForegroundColor Yellow
Write-Host "Terraform creara los siguientes recursos:" -ForegroundColor Blue
Write-Host ""
terraform plan

Write-Host ""
Write-Host "========================================" -ForegroundColor Yellow
Write-Host "  Deseas crear la infraestructura?" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "Esto creara en AWS:"
Write-Host "  - 1 RDS PostgreSQL (db.t3.micro)"
Write-Host "  - 1 EC2 Instance (t3.small)"
Write-Host "  - 2 Security Groups"
Write-Host "  - 1 Elastic IP"
Write-Host "  - Configuracion automatica de Docker + n8n"
Write-Host ""
Write-Host "Tiempo estimado: 10-15 minutos" -ForegroundColor Blue
Write-Host "Costo mensual estimado: 40-50 USD" -ForegroundColor Blue
Write-Host ""
$confirmation = Read-Host "Presiona Enter para continuar o Ctrl+C para cancelar"

Write-Host ""
Write-Host "[6/8] Aplicando configuracion con Terraform..." -ForegroundColor Yellow
terraform apply -auto-approve

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "OK Infraestructura creada exitosamente!" -ForegroundColor Green
}
else {
    Write-Host ""
    Write-Host "X Error al crear infraestructura" -ForegroundColor Red
    Write-Host "Revisa los mensajes de error arriba"
    Set-Location ..
    exit 1
}

Write-Host ""
Write-Host "[7/8] Guardando outputs..." -ForegroundColor Yellow
terraform output | Out-File -FilePath "..\terraform-outputs.txt" -Encoding UTF8
Write-Host "OK Outputs guardados en: terraform-outputs.txt" -ForegroundColor Green

Write-Host ""
Write-Host "[8/8] Mostrando informacion de conexion..." -ForegroundColor Yellow
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Infraestructura Desplegada" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

$rdsEndpoint = terraform output -raw rds_endpoint
$ec2Ip = terraform output -raw ec2_public_ip
$sshCommand = terraform output -raw ssh_command

Write-Host "RDS PostgreSQL:" -ForegroundColor Blue
Write-Host "  Endpoint: $rdsEndpoint" -ForegroundColor Green
Write-Host "  Database: n8n_db" -ForegroundColor Green
Write-Host "  Username: postgres" -ForegroundColor Green
Write-Host "  Password: [Ver terraform.tfvars]" -ForegroundColor Green
Write-Host ""
Write-Host "EC2 Instance:" -ForegroundColor Blue
Write-Host "  IP Publica: $ec2Ip" -ForegroundColor Green
Write-Host "  SSH: $sshCommand" -ForegroundColor Green
Write-Host ""
Write-Host "n8n URL:" -ForegroundColor Blue
Write-Host "  https://n8n.ocaihealth.com" -ForegroundColor Green
Write-Host "  (Configurar DNS primero)" -ForegroundColor Gray
Write-Host ""

Write-Host "========================================" -ForegroundColor Yellow
Write-Host "  Proximos Pasos" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Aplicar scripts SQL a RDS:" -ForegroundColor Blue
Write-Host "   cd ..\migration"
Write-Host "   bash 1-setup-rds.sh $rdsEndpoint postgres n8n_db"
Write-Host ""
Write-Host "2. Configurar DNS:" -ForegroundColor Blue
Write-Host "   n8n.ocaihealth.com -> $ec2Ip"
Write-Host ""
Write-Host "3. Conectar por SSH:" -ForegroundColor Blue
Write-Host "   $sshCommand"
Write-Host ""
Write-Host "4. Acceder a n8n:" -ForegroundColor Blue
Write-Host "   https://n8n.ocaihealth.com (despues de configurar DNS)"
Write-Host ""
Write-Host "OK Despliegue completado exitosamente!" -ForegroundColor Green
Write-Host ""

Set-Location ..
