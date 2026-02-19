# PowerShell Script para aplicar migraciones SQL a RDS PostgreSQL
# Uso: .\1-setup-rds.ps1 -Host <rds-endpoint> -User <username> -Database <database>
# Ejemplo: .\1-setup-rds.ps1 -Host ocai-medical-db.copmy0ewmif4.us-east-1.rds.amazonaws.com -User postgres -Database n8n_db

param(
    [Parameter(Mandatory=$true)]
    [string]$Host,

    [Parameter(Mandatory=$true)]
    [string]$User,

    [Parameter(Mandatory=$true)]
    [string]$Database,

    [string]$Password = $null
)

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Blue
Write-Host "  Configuración de RDS PostgreSQL" -ForegroundColor Blue
Write-Host "========================================" -ForegroundColor Blue
Write-Host ""
Write-Host "Host: $Host" -ForegroundColor Cyan
Write-Host "User: $User" -ForegroundColor Cyan
Write-Host "Database: $Database" -ForegroundColor Cyan
Write-Host ""

# Verificar que psql está instalado
Write-Host "[0/6] Verificando prerequisitos..." -ForegroundColor Yellow
$psqlCommand = Get-Command psql -ErrorAction SilentlyContinue
if (-not $psqlCommand) {
    Write-Host "X Error: psql no esta instalado" -ForegroundColor Red
    Write-Host ""
    Write-Host "Opciones de instalacion para Windows:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Opcion 1 - Winget (Recomendado):" -ForegroundColor Cyan
    Write-Host "  winget install PostgreSQL.PostgreSQL" -ForegroundColor White
    Write-Host "  Reinicia PowerShell despues de instalar" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Opcion 2 - Descargar instalador:" -ForegroundColor Cyan
    Write-Host "  https://www.enterprisedb.com/downloads/postgres-postgresql-downloads" -ForegroundColor White
    Write-Host "  Selecciona solo 'Command Line Tools' durante instalacion" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Opcion 3 - Chocolatey:" -ForegroundColor Cyan
    Write-Host "  choco install postgresql" -ForegroundColor White
    Write-Host ""
    exit 1
}
Write-Host "OK psql encontrado: $($psqlCommand.Source)" -ForegroundColor Green

# Solicitar contraseña si no fue provista
if (-not $Password) {
    $SecurePassword = Read-Host "Ingresa password para $User" -AsSecureString
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($SecurePassword)
    $Password = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
}

# Configurar variable de entorno para password
$env:PGPASSWORD = $Password

# Verificar archivos SQL
$sqlFiles = @(
    "..\pipelines\ddl.sql",
    "..\pipelines\clinic_onboarding.sql",
    "..\pipelines\clinic_onboarding_sp.sql",
    "..\pipelines\clinic_onboarding_trigger.sql"
)

foreach ($file in $sqlFiles) {
    if (-not (Test-Path $file)) {
        Write-Host "X Error: No se encuentra $file" -ForegroundColor Red
        exit 1
    }
}

# Test de conexión
Write-Host ""
Write-Host "[1/6] Probando conexion a RDS..." -ForegroundColor Yellow
try {
    $testResult = psql -h $Host -U $User -d $Database -c "SELECT 1;" 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "OK Conexion exitosa" -ForegroundColor Green
    } else {
        throw "Error de conexion"
    }
} catch {
    Write-Host "X No se pudo conectar a RDS" -ForegroundColor Red
    Write-Host ""
    Write-Host "Verifica:" -ForegroundColor Yellow
    Write-Host "  - El endpoint es correcto" -ForegroundColor White
    Write-Host "  - El Security Group permite conexiones desde tu IP" -ForegroundColor White
    Write-Host "  - Las credenciales son correctas" -ForegroundColor White
    Write-Host "  - La base de datos '$Database' existe" -ForegroundColor White
    Write-Host ""
    Write-Host "Tu IP publica actual:" -ForegroundColor Cyan
    try {
        $myIp = (Invoke-WebRequest -Uri "https://api.ipify.org" -UseBasicParsing).Content
        Write-Host "  $myIp" -ForegroundColor White
        Write-Host ""
        Write-Host "Agrega esta IP al Security Group de RDS en AWS Console" -ForegroundColor Yellow
    } catch {
        Write-Host "  No se pudo detectar" -ForegroundColor Red
    }
    exit 1
}

# Aplicar DDL principal
Write-Host ""
Write-Host "[2/6] Aplicando ddl.sql (esquema principal)..." -ForegroundColor Yellow
psql -h $Host -U $User -d $Database -f "..\pipelines\ddl.sql"
if ($LASTEXITCODE -eq 0) {
    Write-Host "OK DDL aplicado exitosamente" -ForegroundColor Green
} else {
    Write-Host "X Error aplicando DDL" -ForegroundColor Red
    exit 1
}

# Aplicar tabla de onboarding
Write-Host ""
Write-Host "[3/6] Aplicando clinic_onboarding.sql..." -ForegroundColor Yellow
psql -h $Host -U $User -d $Database -f "..\pipelines\clinic_onboarding.sql"
if ($LASTEXITCODE -eq 0) {
    Write-Host "OK Tabla clinic_onboarding creada" -ForegroundColor Green
} else {
    Write-Host "X Error creando tabla clinic_onboarding" -ForegroundColor Red
    exit 1
}

# Aplicar stored procedure de onboarding
Write-Host ""
Write-Host "[4/6] Aplicando clinic_onboarding_sp.sql..." -ForegroundColor Yellow
psql -h $Host -U $User -d $Database -f "..\pipelines\clinic_onboarding_sp.sql"
if ($LASTEXITCODE -eq 0) {
    Write-Host "OK Stored procedure de onboarding creado" -ForegroundColor Green
} else {
    Write-Host "X Error creando stored procedure" -ForegroundColor Red
    exit 1
}

# Aplicar trigger de onboarding
Write-Host ""
Write-Host "[5/6] Aplicando clinic_onboarding_trigger.sql..." -ForegroundColor Yellow
psql -h $Host -U $User -d $Database -f "..\pipelines\clinic_onboarding_trigger.sql"
if ($LASTEXITCODE -eq 0) {
    Write-Host "OK Trigger de onboarding creado" -ForegroundColor Green
} else {
    Write-Host "X Error creando trigger" -ForegroundColor Red
    exit 1
}

# Verificar instalación
Write-Host ""
Write-Host "[6/6] Verificando instalacion..." -ForegroundColor Yellow

$verifyQuery = @"
-- Verificar esquema
SELECT 'Esquemas:' as tipo, schema_name as nombre FROM information_schema.schemata WHERE schema_name = 'medical'
UNION ALL
-- Verificar tablas
SELECT 'Tabla' as tipo, table_name as nombre FROM information_schema.tables WHERE table_schema = 'medical'
UNION ALL
-- Verificar stored procedures
SELECT 'Stored Proc' as tipo, routine_name as nombre FROM information_schema.routines WHERE routine_schema = 'medical'
UNION ALL
-- Verificar trigger
SELECT 'Trigger' as tipo, trigger_name as nombre FROM information_schema.triggers WHERE trigger_name = 'trg_run_onboarding';
"@

psql -h $Host -U $User -d $Database -c $verifyQuery

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Green
    Write-Host "  Migracion completada exitosamente" -ForegroundColor Green
    Write-Host "========================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Siguiente paso (opcional): Insertar datos de prueba" -ForegroundColor Cyan
    Write-Host "  psql -h $Host -U $User -d $Database -f ..\insert_test_data.sql" -ForegroundColor Gray
    Write-Host ""
} else {
    Write-Host "X Error en verificacion" -ForegroundColor Red
    exit 1
}

# Limpiar variable de password
$env:PGPASSWORD = $null
