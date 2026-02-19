# Script PowerShell para deployar n8n con SSL a EC2
param(
    [Parameter(Mandatory=$false)]
    [string]$KeyPath = "ocai-key-pair-aws.pem",

    [Parameter(Mandatory=$true)]
    [string]$EC2_IP
)

$EC2_USER = "ubuntu"

Write-Host "=== Deploying n8n to EC2 ===" -ForegroundColor Cyan
Write-Host "EC2 IP: $EC2_IP"
Write-Host "Key: $KeyPath"
Write-Host ""

# Verificar que existe el archivo de llave
if (-not (Test-Path $KeyPath)) {
    Write-Host "❌ Error: No se encuentra el archivo de llave: $KeyPath" -ForegroundColor Red
    exit 1
}

# Verificar conexión SSH
Write-Host "[1/7] Verificando conexión SSH..." -ForegroundColor Yellow
try {
    $testConnection = ssh -i $KeyPath -o ConnectTimeout=10 -o StrictHostKeyChecking=no "${EC2_USER}@${EC2_IP}" "echo 'test'" 2>&1
    Write-Host "✓ SSH funciona correctamente" -ForegroundColor Green
} catch {
    Write-Host "❌ Error: No se puede conectar a EC2" -ForegroundColor Red
    Write-Host "Verifica:"
    Write-Host "  - La IP es correcta"
    Write-Host "  - El Security Group permite SSH desde tu IP"
    exit 1
}

# Crear directorio en EC2
Write-Host "[2/7] Creando directorio en EC2..." -ForegroundColor Yellow
ssh -i $KeyPath "${EC2_USER}@${EC2_IP}" "mkdir -p ~/n8n/local-files"
Write-Host "✓ Directorio creado" -ForegroundColor Green

# Transferir archivos
Write-Host "[3/7] Transfiriendo archivos..." -ForegroundColor Yellow
scp -i $KeyPath docker-compose.yml "${EC2_USER}@${EC2_IP}:~/n8n/"
scp -i $KeyPath .env "${EC2_USER}@${EC2_IP}:~/n8n/"
Write-Host "✓ Archivos transferidos" -ForegroundColor Green

# Crear acme.json
Write-Host "[4/7] Creando acme.json..." -ForegroundColor Yellow
ssh -i $KeyPath "${EC2_USER}@${EC2_IP}" "cd ~/n8n && touch acme.json && chmod 600 acme.json"
Write-Host "✓ acme.json creado con permisos correctos" -ForegroundColor Green

# Verificar Docker instalado
Write-Host "[5/7] Verificando Docker..." -ForegroundColor Yellow
$dockerCheck = ssh -i $KeyPath "${EC2_USER}@${EC2_IP}" "docker --version 2>&1"
if ($LASTEXITCODE -eq 0) {
    Write-Host "✓ Docker ya instalado" -ForegroundColor Green
} else {
    Write-Host "⚠️  Docker no encontrado, instalando..." -ForegroundColor Yellow
    ssh -i $KeyPath "${EC2_USER}@${EC2_IP}" "sudo apt update && sudo apt install -y docker.io docker-compose && sudo usermod -aG docker ubuntu"
    Write-Host "✓ Docker instalado" -ForegroundColor Green
}

# Iniciar servicios
Write-Host "[6/7] Iniciando servicios Docker..." -ForegroundColor Yellow
ssh -i $KeyPath "${EC2_USER}@${EC2_IP}" "cd ~/n8n && docker-compose pull && docker-compose up -d"
Write-Host "✓ Servicios iniciados" -ForegroundColor Green

# Verificar estado
Write-Host "[7/7] Verificando estado..." -ForegroundColor Yellow
Start-Sleep -Seconds 3
ssh -i $KeyPath "${EC2_USER}@${EC2_IP}" "cd ~/n8n && docker-compose ps"

Write-Host ""
Write-Host "=== ✓ Deployment completado ===" -ForegroundColor Green
Write-Host ""
Write-Host "Próximos pasos:" -ForegroundColor Yellow
Write-Host ""
Write-Host "1. Configurar DNS:"
Write-Host "   - Tipo: A"
Write-Host "   - Nombre: n8n"
Write-Host "   - Valor: $EC2_IP"
Write-Host ""
Write-Host "2. Esperar propagación DNS (5-15 minutos)"
Write-Host ""
Write-Host "3. Verificar certificado SSL:"
Write-Host "   ssh -i $KeyPath ${EC2_USER}@${EC2_IP} 'cd ~/n8n && docker-compose logs traefik | grep certificate'"
Write-Host ""
Write-Host "4. Acceder a n8n:"
Write-Host "   https://n8n.ocaihealth.com" -ForegroundColor Cyan
Write-Host ""
Write-Host "Ver logs en tiempo real:"
Write-Host "   ssh -i $KeyPath ${EC2_USER}@${EC2_IP} 'cd ~/n8n && docker-compose logs -f'"
