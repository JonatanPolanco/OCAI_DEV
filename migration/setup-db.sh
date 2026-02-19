#!/bin/bash
# Script simplificado para ejecutar en WSL
set -e

# Variables de conexión
export PGHOST="ocai-medical-db.copmy0ewmif4.us-east-1.rds.amazonaws.com"
export PGPORT="5432"
export PGDATABASE="n8n_db"
export PGUSER="postgres"
export PGPASSWORD="OcaiMedical2026!Secure#DB"

echo "=== Aplicando estructura de base de datos ==="
echo "Host: $PGHOST"
echo "Database: $PGDATABASE"
echo ""

# Test de conexión
echo "[1/6] Probando conexión..."
if psql -c "SELECT 1;" > /dev/null 2>&1; then
    echo "✓ Conexión exitosa"
else
    echo "✗ Error de conexión"
    exit 1
fi

# Aplicar DDL
echo "[2/6] Aplicando ddl.sql..."
psql -f ../pipelines/ddl.sql
echo "✓ DDL aplicado"

# Aplicar clinic_onboarding
echo "[3/6] Aplicando clinic_onboarding.sql..."
psql -f ../pipelines/clinic_onboarding.sql
echo "✓ Tabla clinic_onboarding creada"

# Aplicar stored procedure
echo "[4/6] Aplicando clinic_onboarding_sp.sql..."
psql -f ../pipelines/clinic_onboarding_sp.sql
echo "✓ Stored procedure creado"

# Aplicar trigger
echo "[5/7] Aplicando clinic_onboarding_trigger.sql..."
psql -f ../pipelines/clinic_onboarding_trigger.sql
echo "✓ Trigger creado"

# Aplicar vista de contexto del agente
echo "[6/7] Aplicando agent_context_view.sql..."
psql -f ../pipelines/agent_context_view.sql
echo "✓ Vista v_agent_context creada"

# Verificar
echo "[7/7] Verificando instalación..."
psql -c "\dn"
psql -c "\dt medical.*"
psql -c "\dv medical.*"

echo ""
echo "=== ✓ Migración completada ==="
