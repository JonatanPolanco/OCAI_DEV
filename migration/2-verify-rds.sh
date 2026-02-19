#!/bin/bash
# Script para verificar que RDS PostgreSQL está configurado correctamente
# Uso: ./2-verify-rds.sh <rds-endpoint> <username> <database>

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

if [ "$#" -ne 3 ]; then
    echo -e "${RED}Error: Número incorrecto de argumentos${NC}"
    echo "Uso: $0 <rds-endpoint> <username> <database>"
    exit 1
fi

RDS_HOST=$1
DB_USER=$2
DB_NAME=$3

echo -e "${YELLOW}=== Verificación de RDS PostgreSQL ===${NC}"
echo "Host: $RDS_HOST"
echo "Database: $DB_NAME"
echo ""

# Test conexión
echo -e "${YELLOW}[1/7] Probando conexión...${NC}"
if psql -h "$RDS_HOST" -U "$DB_USER" -d "$DB_NAME" -c "SELECT 1;" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Conexión exitosa${NC}"
else
    echo -e "${RED}✗ Conexión fallida${NC}"
    exit 1
fi

# Verificar esquema
echo -e "${YELLOW}[2/7] Verificando esquema 'medical'...${NC}"
SCHEMA_COUNT=$(psql -h "$RDS_HOST" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM information_schema.schemata WHERE schema_name = 'medical';")
if [ "$SCHEMA_COUNT" -eq 1 ]; then
    echo -e "${GREEN}✓ Esquema 'medical' existe${NC}"
else
    echo -e "${RED}✗ Esquema 'medical' NO existe${NC}"
    exit 1
fi

# Verificar tablas
echo -e "${YELLOW}[3/7] Verificando tablas...${NC}"
TABLE_COUNT=$(psql -h "$RDS_HOST" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'medical';")
echo "Tablas encontradas: $TABLE_COUNT"
if [ "$TABLE_COUNT" -ge 15 ]; then
    echo -e "${GREEN}✓ Tablas principales creadas ($TABLE_COUNT tablas)${NC}"
else
    echo -e "${RED}✗ Número insuficiente de tablas ($TABLE_COUNT < 15)${NC}"
    exit 1
fi

# Verificar stored procedures
echo -e "${YELLOW}[4/7] Verificando stored procedures...${NC}"

echo -n "  - mvp_create_patient_appointment_evaluation: "
MVP_SP=$(psql -h "$RDS_HOST" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM pg_proc WHERE proname = 'mvp_create_patient_appointment_evaluation';")
if [ "$MVP_SP" -eq 1 ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi

echo -n "  - process_clinic_onboarding: "
ONBOARD_SP=$(psql -h "$RDS_HOST" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM pg_proc WHERE proname = 'process_clinic_onboarding';")
if [ "$ONBOARD_SP" -eq 1 ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi

echo -n "  - upsert_patient: "
UPSERT_PAT=$(psql -h "$RDS_HOST" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM pg_proc WHERE proname = 'upsert_patient';")
if [ "$UPSERT_PAT" -eq 1 ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi

# Verificar triggers
echo -e "${YELLOW}[5/7] Verificando triggers...${NC}"
echo -n "  - trg_run_onboarding: "
TRIGGER=$(psql -h "$RDS_HOST" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM pg_trigger WHERE tgname = 'trg_run_onboarding';")
if [ "$TRIGGER" -eq 1 ]; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗${NC}"
fi

# Probar stored procedure MVP
echo -e "${YELLOW}[6/7] Probando stored procedure MVP...${NC}"
psql -h "$RDS_HOST" -U "$DB_USER" -d "$DB_NAME" <<EOF > /dev/null 2>&1
SELECT medical.mvp_create_patient_appointment_evaluation(
    'Test',
    'Patient',
    '+571234567890',
    '1990-01-01',
    '2026-06-01 10:00:00',
    'Consulta de prueba',
    1, 1, NULL, 'test-session', 'verification-script'
);
EOF

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Stored procedure MVP ejecutado exitosamente${NC}"

    # Verificar que se insertó el paciente
    PATIENT_COUNT=$(psql -h "$RDS_HOST" -U "$DB_USER" -d "$DB_NAME" -t -c "SELECT COUNT(*) FROM medical.patient WHERE phone_number_str = '+571234567890';")
    if [ "$PATIENT_COUNT" -ge 1 ]; then
        echo -e "${GREEN}✓ Paciente de prueba insertado correctamente${NC}"
    fi
else
    echo -e "${RED}✗ Error ejecutando stored procedure MVP${NC}"
fi

# Resumen
echo -e "${YELLOW}[7/7] Resumen de verificación...${NC}"
echo ""
psql -h "$RDS_HOST" -U "$DB_USER" -d "$DB_NAME" <<EOF
SELECT 'Esquemas: ' || COUNT(*) FROM information_schema.schemata WHERE schema_name = 'medical'
UNION ALL
SELECT 'Tablas: ' || COUNT(*) FROM information_schema.tables WHERE table_schema = 'medical'
UNION ALL
SELECT 'Stored Procedures: ' || COUNT(*) FROM pg_proc p JOIN pg_namespace n ON p.pronamespace = n.oid WHERE n.nspname = 'medical'
UNION ALL
SELECT 'Triggers: ' || COUNT(*) FROM pg_trigger t JOIN pg_class c ON t.tgrelid = c.oid JOIN pg_namespace n ON c.relnamespace = n.oid WHERE n.nspname = 'medical'
UNION ALL
SELECT 'Pacientes: ' || COUNT(*) FROM medical.patient
UNION ALL
SELECT 'Citas: ' || COUNT(*) FROM medical.appointment
UNION ALL
SELECT 'Clínicas: ' || COUNT(*) FROM medical.clinic;
EOF

echo ""
echo -e "${GREEN}=== ✓ Verificación completada ===${NC}"
echo ""
echo "Tu base de datos RDS está lista para usar."
echo ""
echo "Siguiente paso:"
echo "  - Configurar instancia EC2 para n8n"
echo "  - Ver guía: migration/AWS-EC2-SETUP-GUIDE.md"
