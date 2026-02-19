# PowerShell Script para subir archivos SQL a EC2 y ejecutar migración desde ahí
# No requiere instalar PostgreSQL localmente
# Uso: .\upload-and-run-from-ec2.ps1

param(
    [string]$EC2_IP = "",
    [string]$KeyPath = "$env:USERPROFILE\.ssh\id_rsa",
    [string]$RDS_Host = "ocai-medical-db.copmy0ewmif4.us-east-1.rds.amazonaws.com",
    [string]$DB_User = "postgres",
    [string]$DB_Name = "n8n_db"
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Blue
Write-Host "  Migración RDS desde EC2" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""

# Si no se especificó IP de EC2, obtenerla de Terraform
if ($EC2_IP -eq "") {
    Write-Host "[1/5] Obteniendo IP de EC2 desde Terraform..." -ForegroundColor Yellow
    Push-Location ..\terraform
    $EC2_IP = terraform output -raw ec2_public_ip 2>$null
    Pop-Location

    if (-not $EC2_IP -or $EC2_IP -eq "") {
        Write-Host "X No se pudo obtener IP de EC2 desde Terraform" -ForegroundColor Red
        Write-Host ""
        Write-Host "Opciones:" -ForegroundColor Yellow
        Write-Host "1. Ejecuta este script con -EC2_IP:" -ForegroundColor White
        Write-Host "   .\upload-and-run-from-ec2.ps1 -EC2_IP 12.34.56.78" -ForegroundColor Gray
        Write-Host ""
        Write-Host "2. O busca la IP en AWS Console → EC2 → Instances" -ForegroundColor White
        Write-Host ""
        exit 1
    }
}

Write-Host "OK IP de EC2: $EC2_IP" -ForegroundColor Green

# Verificar que existe la key SSH
if (-not (Test-Path $KeyPath)) {
    Write-Host "X SSH key no encontrado en: $KeyPath" -ForegroundColor Red
    Write-Host ""
    Write-Host "Especifica la ruta correcta:" -ForegroundColor Yellow
    Write-Host "  .\upload-and-run-from-ec2.ps1 -KeyPath 'C:\ruta\a\tu\key.pem'" -ForegroundColor Gray
    exit 1
}

# Verificar archivos SQL
$sqlFiles = @(
    "..\pipelines\ddl.sql",
    "..\pipelines\clinic_onboarding.sql",
    "..\pipelines\clinic_onboarding_sp.sql",
    "..\pipelines\clinic_onboarding_trigger.sql"
)

foreach ($file in $sqlFiles) {
    if (-not (Test-Path $file)) {
        Write-Host "X Archivo no encontrado: $file" -ForegroundColor Red
        exit 1
    }
}

Write-Host ""
Write-Host "[2/5] Verificando conexión SSH a EC2..." -ForegroundColor Yellow
$sshTest = ssh -i $KeyPath -o StrictHostKeyChecking=no -o ConnectTimeout=10 ubuntu@$EC2_IP "echo OK" 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "X No se pudo conectar a EC2" -ForegroundColor Red
    Write-Host ""
    Write-Host "Verifica:" -ForegroundColor Yellow
    Write-Host "  - La IP es correcta: $EC2_IP" -ForegroundColor White
    Write-Host "  - El Security Group permite SSH desde tu IP" -ForegroundColor White
    Write-Host "  - La key SSH es correcta: $KeyPath" -ForegroundColor White
    Write-Host ""
    Write-Host "Tu IP pública actual:" -ForegroundColor Cyan
    $myIp = (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing).Content
    Write-Host "  $myIp" -ForegroundColor White
    Write-Host ""
    exit 1
}
Write-Host "OK Conexión SSH exitosa" -ForegroundColor Green

Write-Host ""
Write-Host "[3/5] Subiendo archivos SQL a EC2..." -ForegroundColor Yellow

# Crear directorio en EC2
ssh -i $KeyPath ubuntu@$EC2_IP "mkdir -p ~/pipelines"

# Subir cada archivo SQL
foreach ($file in $sqlFiles) {
    $fileName = Split-Path $file -Leaf
    Write-Host "  Subiendo $fileName..." -ForegroundColor Gray
    scp -i $KeyPath -o StrictHostKeyChecking=no $file ubuntu@${EC2_IP}:~/pipelines/
    if ($LASTEXITCODE -ne 0) {
        Write-Host "X Error subiendo $fileName" -ForegroundColor Red
        exit 1
    }
}

# Subir el script de migración
Write-Host "  Subiendo script de migración..." -ForegroundColor Gray
scp -i $KeyPath -o StrictHostKeyChecking=no "1-setup-rds.sh" ubuntu@${EC2_IP}:~/

Write-Host "OK Archivos subidos exitosamente" -ForegroundColor Green

Write-Host ""
Write-Host "[4/5] Instalando PostgreSQL client en EC2 (si es necesario)..." -ForegroundColor Yellow
ssh -i $KeyPath ubuntu@$EC2_IP @"
if ! command -v psql &> /dev/null; then
    echo 'Instalando postgresql-client...'
    sudo apt-get update -qq
    sudo apt-get install -y postgresql-client > /dev/null 2>&1
    echo 'OK PostgreSQL client instalado'
else
    echo 'OK PostgreSQL client ya instalado'
fi
"@

Write-Host ""
Write-Host "[5/5] Ejecutando migración desde EC2..." -ForegroundColor Yellow
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Conectando a RDS..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Ejecutar el script de migración en EC2
ssh -i $KeyPath -t ubuntu@$EC2_IP "bash ~/1-setup-rds.sh $RDS_Host $DB_User $DB_Name"

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Migración completada exitosamente" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Los scripts SQL están ahora en la EC2 en: ~/pipelines/" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Para futuras migraciones, puedes conectarte directamente:" -ForegroundColor Yellow
    Write-Host "  ssh -i $KeyPath ubuntu@$EC2_IP" -ForegroundColor Gray
    Write-Host "  psql -h $RDS_Host -U $DB_User -d $DB_Name" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "X Error durante la migración" -ForegroundColor Red
    Write-Host "Revisa los mensajes de error arriba" -ForegroundColor Yellow
    exit 1
}
