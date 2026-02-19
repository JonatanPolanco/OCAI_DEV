#!/bin/bash
# Script para aplicar migraciones SQL a RDS usando Docker
# No requiere instalar PostgreSQL localmente
# Uso: ./2-setup-rds-docker.sh <rds-endpoint> <username> <database>
# Ejemplo: ./2-setup-rds-docker.sh ocai-db.xxxxx.us-east-1.rds.amazonaws.com postgres n8n_db

set -e

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Validar argumentos
if [ "$#" -ne 3 ]; then
    echo -e "${RED}Error: Número incorrecto de argumentos${NC}"
    echo "Uso: $0 <rds-endpoint> <username> <database>"
    echo "Ejemplo: $0 ocai-db.xxxxx.us-east-1.rds.amazonaws.com postgres n8n_db"
    exit 1
fi

RDS_HOST=$1
DB_USER=$2
DB_NAME=$3

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Configuración de RDS con Docker${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo -e "${YELLOW}Host:${NC} $RDS_HOST"
echo -e "${YELLOW}User:${NC} $DB_USER"
echo -e "${YELLOW}Database:${NC} $DB_NAME"
echo ""

# Verificar que Docker está instalado
echo -e "${YELLOW}[0/6] Verificando Docker...${NC}"
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker no está instalado${NC}"
    echo ""
    echo "Instala Docker Desktop para Windows:"
    echo "  https://www.docker.com/products/docker-desktop/"
    echo ""
    echo "O instala PostgreSQL client localmente:"
    echo "  Ver INSTALAR-POSTGRESQL-WINDOWS.md"
    exit 1
fi

# Verificar que Docker está corriendo
if ! docker info &> /dev/null; then
    echo -e "${RED}Error: Docker no está corriendo${NC}"
    echo ""
    echo "Inicia Docker Desktop y vuelve a intentar"
    exit 1
fi

echo -e "${GREEN}✓ Docker está instalado y corriendo${NC}"

# Solicitar contraseña
echo ""
read -sp "Ingresa password para $DB_USER: " DB_PASSWORD
echo ""
echo ""

# Verificar que los archivos SQL existen
SQL_FILES=(
    "../pipelines/ddl.sql"
    "../pipelines/clinic_onboarding.sql"
    "../pipelines/clinic_onboarding_sp.sql"
    "../pipelines/clinic_onboarding_trigger.sql"
)

for file in "${SQL_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        echo -e "${RED}Error: No se encuentra $file${NC}"
        exit 1
    fi
done

# Función para ejecutar psql en Docker
run_psql() {
    docker run --rm -i \
        -v "$(pwd)/../pipelines:/sql" \
        postgres:16-alpine \
        psql "postgresql://$DB_USER:$DB_PASSWORD@$RDS_HOST:5432/$DB_NAME" \
        "$@"
}

# Test de conexión
echo -e "${YELLOW}[1/6] Probando conexión a RDS...${NC}"
if run_psql -c "SELECT 1;" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Conexión exitosa${NC}"
else
    echo -e "${RED}✗ No se pudo conectar a RDS${NC}"
    echo ""
    echo "Verifica:"
    echo "  - El endpoint es correcto"
    echo "  - El Security Group permite conexiones desde tu IP"
    echo "  - Las credenciales son correctas"
    echo "  - La base de datos '$DB_NAME' existe"
    echo ""
    echo "Tu IP pública actual:"
    curl -s https://api.ipify.org
    echo ""
    echo ""
    echo "Agrega esta IP al Security Group de RDS en AWS Console"
    exit 1
fi

# Aplicar DDL principal
echo ""
echo -e "${YELLOW}[2/6] Aplicando ddl.sql (esquema principal)...${NC}"
run_psql -f /sql/ddl.sql
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ DDL aplicado exitosamente${NC}"
else
    echo -e "${RED}✗ Error aplicando DDL${NC}"
    exit 1
fi

# Aplicar tabla de onboarding
echo ""
echo -e "${YELLOW}[3/6] Aplicando clinic_onboarding.sql...${NC}"
run_psql -f /sql/clinic_onboarding.sql
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Tabla clinic_onboarding creada${NC}"
else
    echo -e "${RED}✗ Error creando tabla clinic_onboarding${NC}"
    exit 1
fi

# Aplicar stored procedure de onboarding
echo ""
echo -e "${YELLOW}[4/6] Aplicando clinic_onboarding_sp.sql...${NC}"
run_psql -f /sql/clinic_onboarding_sp.sql
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Stored procedure de onboarding creado${NC}"
else
    echo -e "${RED}✗ Error creando stored procedure${NC}"
    exit 1
fi

# Aplicar trigger de onboarding
echo ""
echo -e "${YELLOW}[5/6] Aplicando clinic_onboarding_trigger.sql...${NC}"
run_psql -f /sql/clinic_onboarding_trigger.sql
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Trigger de onboarding creado${NC}"
else
    echo -e "${RED}✗ Error creando trigger${NC}"
    exit 1
fi

# Verificar instalación
echo ""
echo -e "${YELLOW}[6/6] Verificando instalación...${NC}"
run_psql <<EOF
-- Verificar esquema
\echo '=== Esquemas ==='
\dn

-- Verificar tablas
\echo '\n=== Tablas en esquema medical ==='
\dt medical.*

-- Verificar stored procedures
\echo '\n=== Stored Procedures ==='
\df medical.mvp_create_patient_appointment_evaluation
\df medical.process_clinic_onboarding

-- Verificar trigger
\echo '\n=== Triggers ==='
SELECT tgname, tgrelid::regclass FROM pg_trigger WHERE tgname = 'trg_run_onboarding';

-- Contar tablas
\echo '\n=== Resumen ==='
SELECT 'Tablas creadas: ' || COUNT(*) FROM information_schema.tables WHERE table_schema = 'medical';
EOF

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  ✓ Migración completada exitosamente${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo -e "${BLUE}Siguiente paso (opcional): Insertar datos de prueba${NC}"
echo -e "${YELLOW}  docker run --rm -i -v \"\$(pwd)/../:/sql\" postgres:16-alpine psql \"postgresql://$DB_USER:$DB_PASSWORD@$RDS_HOST:5432/$DB_NAME\" -f /sql/insert_test_data.sql${NC}"
echo ""
