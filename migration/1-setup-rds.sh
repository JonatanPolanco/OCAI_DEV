#!/bin/bash
# Script para aplicar todos los scripts SQL a RDS PostgreSQL en orden
# Uso: ./1-setup-rds.sh <rds-endpoint> <username> <database>
# Ejemplo: ./1-setup-rds.sh ocai-db.xxxxx.us-east-1.rds.amazonaws.com postgres n8n_db

set -e  # Exit on error

# Colores para output
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
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

echo -e "${YELLOW}=== Configuración de RDS PostgreSQL ===${NC}"
echo "Host: $RDS_HOST"
echo "User: $DB_USER"
echo "Database: $DB_NAME"
echo ""

# Verificar que psql está instalado
if ! command -v psql &> /dev/null; then
    echo -e "${RED}Error: psql no está instalado${NC}"
    echo "Instala PostgreSQL client:"
    echo "  Ubuntu/Debian: sudo apt-get install postgresql-client"
    echo "  MacOS: brew install postgresql"
    echo "  Windows: Descarga desde https://www.postgresql.org/download/"
    exit 1
fi

# Test de conexión
echo -e "${YELLOW}[1/6] Probando conexión a RDS...${NC}"
if psql -h "$RDS_HOST" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Conexión exitosa${NC}"
else
    echo -e "${RED}✗ No se pudo conectar a RDS${NC}"
    echo "Verifica:"
    echo "  - El endpoint es correcto"
    echo "  - El Security Group permite conexiones desde tu IP"
    echo "  - Las credenciales son correctas"
    exit 1
fi

# Aplicar DDL principal
echo -e "${YELLOW}[2/6] Aplicando ddl.sql (esquema principal)...${NC}"
psql -h "$RDS_HOST" -U "$DB_USER" -d "$DB_NAME" -f "../pipelines/ddl.sql"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ DDL aplicado exitosamente${NC}"
else
    echo -e "${RED}✗ Error aplicando DDL${NC}"
    exit 1
fi

# Aplicar tabla de onboarding
echo -e "${YELLOW}[3/6] Aplicando clinic_onboarding.sql...${NC}"
psql -h "$RDS_HOST" -U "$DB_USER" -d "$DB_NAME" -f "../pipelines/clinic_onboarding.sql"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Tabla clinic_onboarding creada${NC}"
else
    echo -e "${RED}✗ Error creando tabla clinic_onboarding${NC}"
    exit 1
fi

# Aplicar stored procedure de onboarding
echo -e "${YELLOW}[4/6] Aplicando clinic_onboarding_sp.sql...${NC}"
psql -h "$RDS_HOST" -U "$DB_USER" -d "$DB_NAME" -f "../pipelines/clinic_onboarding_sp.sql"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Stored procedure de onboarding creado${NC}"
else
    echo -e "${RED}✗ Error creando stored procedure${NC}"
    exit 1
fi

# Aplicar trigger de onboarding
echo -e "${YELLOW}[5/6] Aplicando clinic_onboarding_trigger.sql...${NC}"
psql -h "$RDS_HOST" -U "$DB_USER" -d "$DB_NAME" -f "../pipelines/clinic_onboarding_trigger.sql"
if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Trigger de onboarding creado${NC}"
else
    echo -e "${RED}✗ Error creando trigger${NC}"
    exit 1
fi

# Verificar instalación
echo -e "${YELLOW}[6/6] Verificando instalación...${NC}"
psql -h "$RDS_HOST" -U "$DB_USER" -d "$DB_NAME" <<EOF
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
echo -e "${GREEN}=== ✓ Migración de base de datos completada ===${NC}"
echo ""
echo "Siguiente paso: Insertar datos de prueba (opcional)"
echo "  psql -h $RDS_HOST -U $DB_USER -d $DB_NAME -f ../insert_test_data.sql"
echo ""
echo "O continuar con la configuración de EC2 para n8n"
