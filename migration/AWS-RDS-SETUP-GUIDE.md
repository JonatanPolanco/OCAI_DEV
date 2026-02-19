# Guía Paso a Paso: Crear RDS PostgreSQL en AWS

## Paso 1: Acceder a AWS Console

1. Ingresar a [AWS Console](https://console.aws.amazon.com/)
2. Seleccionar la región deseada (ej: `us-east-1` - Virginia del Norte)
3. Buscar "RDS" en la barra de búsqueda y hacer click

## Paso 2: Crear Security Group para RDS

**Importante:** Crear el Security Group ANTES de crear RDS

1. En el menú lateral de AWS Console, buscar "VPC"
2. En el menú lateral, click en "Security Groups"
3. Click en "Create security group"
4. Configurar:
   - **Name:** `ocai-rds-sg`
   - **Description:** Security group for OCAI RDS PostgreSQL
   - **VPC:** Seleccionar VPC por defecto o la VPC que estén usando

### Inbound Rules:
Click "Add rule" y agregar:

**Regla 1: Acceso desde tu IP (para desarrollo)**
- Type: `PostgreSQL`
- Protocol: `TCP`
- Port range: `5432`
- Source: `My IP` (AWS detectará tu IP automáticamente)
- Description: `Dev access from my IP`

**Regla 2: Acceso desde EC2 (para n8n)**
- Type: `PostgreSQL`
- Protocol: `TCP`
- Port range: `5432`
- Source: `Custom` → Seleccionar el Security Group de EC2 (crearlo después si aún no existe)
- Description: `Access from EC2 n8n instance`

### Outbound Rules:
- Dejar por defecto (All traffic)

5. Click "Create security group"
6. **Guardar el ID del Security Group** (ej: `sg-0123456789abcdef0`)

## Paso 3: Crear Instancia RDS PostgreSQL

1. Regresar a RDS en AWS Console
2. Click en "Create database"

### Engine options:
- **Engine type:** PostgreSQL
- **Version:** PostgreSQL 14.x o superior (seleccionar la más reciente)

### Templates:
- Seleccionar **"Free tier"** (si aplica) o **"Dev/Test"**

### Settings:
- **DB instance identifier:** `ocai-medical-db` (o el nombre que prefieran)
- **Master username:** `postgres` (o crear un usuario personalizado)
- **Master password:** Generar contraseña segura
  - Sugerencia: Usar AWS Secrets Manager o generador de passwords
  - Ejemplo: `OcaiDB2026!Secure#Pass`
- **Confirm password:** Repetir la contraseña
- ⚠️ **IMPORTANTE:** Guardar estas credenciales en un lugar seguro

### Instance configuration:
- **DB instance class:** `db.t3.micro` (1 vCPU, 1 GB RAM)
  - Si necesitan más potencia: `db.t3.small` (2 vCPU, 2 GB RAM)
- **Burstable classes** (incluido en free tier)

### Storage:
- **Storage type:** General Purpose SSD (gp3)
- **Allocated storage:** `20` GB
- **Storage autoscaling:** Habilitar (opcional)
  - Maximum storage threshold: `50` GB

### Connectivity:
- **Virtual private cloud (VPC):** Seleccionar VPC por defecto o su VPC
- **Subnet group:** default
- **Public access:** **NO** (más seguro, solo acceso desde VPC)
  - Si necesitan acceso desde internet temporalmente: **YES** (cambiar después)
- **VPC security group:** Seleccionar el creado en Paso 2 (`ocai-rds-sg`)
- **Availability Zone:** No preference (o seleccionar específica)

### Database authentication:
- Seleccionar: **Password authentication**

### Additional configuration (Expandir):
- **Initial database name:** `n8n_db` ⚠️ **MUY IMPORTANTE**
- **DB parameter group:** default.postgres14
- **Backup:**
  - Habilitar backups automáticos
  - Backup retention period: `7` días
  - Backup window: Seleccionar horario de baja actividad
- **Encryption:** Habilitar encryption at rest (recomendado)
- **Performance Insights:** Deshabilitar (opcional, genera costo)
- **Monitoring:** Enhanced monitoring - Deshabilitar (opcional)
- **Log exports:** Marcar `PostgreSQL log` (recomendado para debugging)
- **Maintenance:**
  - Enable auto minor version upgrade: ✓
  - Maintenance window: Seleccionar horario conveniente
- **Deletion protection:** Habilitar (recomendado)

### Estimated monthly costs:
- Verificar el costo estimado (debe ser ~$15-20/mes para db.t3.micro)

3. Click "Create database"
4. **Esperar 5-10 minutos** mientras se crea la instancia

## Paso 4: Obtener Endpoint de RDS

1. En RDS Console, click en "Databases"
2. Click en el nombre de la base de datos creada (`ocai-medical-db`)
3. En la sección "Connectivity & security":
   - **Endpoint:** Copiar el endpoint (ej: `ocai-medical-db.c9z8x7y6w5v4.us-east-1.rds.amazonaws.com`)
   - **Port:** Verificar que es `5432`
4. **Guardar el endpoint** - Lo necesitarás para conectarte

## Paso 5: Verificar Conexión

### Opción A: Desde tu computadora local

Instalar PostgreSQL client si no lo tienes:
```bash
# Ubuntu/Debian
sudo apt-get install postgresql-client

# MacOS
brew install postgresql

# Windows
# Descargar desde https://www.postgresql.org/download/windows/
```

Probar conexión:
```bash
psql -h <rds-endpoint> -U postgres -d n8n_db
# Ejemplo: psql -h ocai-medical-db.c9z8x7y6w5v4.us-east-1.rds.amazonaws.com -U postgres -d n8n_db
```

Ingresar la contraseña cuando se solicite.

Si se conecta exitosamente, verás:
```
n8n_db=>
```

### Opción B: Desde AWS Console (Query Editor)

1. En RDS Console, buscar "Query Editor" en el menú lateral
2. Connect to database:
   - Database instance: Seleccionar `ocai-medical-db`
   - Database username: El usuario creado
   - Password: Ingresar contraseña
3. Click "Connect"
4. Ejecutar query de prueba: `SELECT 1;`

## Paso 6: Aplicar Scripts SQL

Una vez verificada la conexión, ejecutar el script de setup:

```bash
cd migration
chmod +x 1-setup-rds.sh
./1-setup-rds.sh <rds-endpoint> postgres n8n_db
```

O ejecutar manualmente cada script:

```bash
# 1. DDL principal
psql -h <rds-endpoint> -U postgres -d n8n_db -f pipelines/ddl.sql

# 2. Tabla onboarding
psql -h <rds-endpoint> -U postgres -d n8n_db -f pipelines/clinic_onboarding.sql

# 3. Stored procedure onboarding
psql -h <rds-endpoint> -U postgres -d n8n_db -f pipelines/clinic_onboarding_sp.sql

# 4. Trigger onboarding
psql -h <rds-endpoint> -U postgres -d n8n_db -f pipelines/clinic_onboarding_trigger.sql

# 5. (Opcional) Datos de prueba
psql -h <rds-endpoint> -U postgres -d n8n_db -f insert_test_data.sql
```

## Paso 7: Verificar Instalación

Conectar a la base de datos y ejecutar:

```sql
-- Verificar esquema
\dn

-- Debería mostrar: medical

-- Verificar tablas
\dt medical.*

-- Debería mostrar: appointment, chat_history, clinic, clinic_branch, etc.

-- Verificar stored procedures
\df medical.mvp_create_patient_appointment_evaluation
\df medical.process_clinic_onboarding

-- Verificar trigger
SELECT tgname, tgrelid::regclass
FROM pg_trigger
WHERE tgname = 'trg_run_onboarding';
```

## Paso 8: Guardar Credenciales

Crear archivo local (NO commitear) con las credenciales:

```bash
# Crear archivo de credenciales
cat > aws-credentials.txt <<EOF
=== RDS PostgreSQL Credentials ===
Endpoint: <tu-rds-endpoint>
Port: 5432
Database: n8n_db
Username: postgres
Password: <tu-contraseña>
Region: us-east-1

Connection String:
postgresql://postgres:<password>@<endpoint>:5432/n8n_db
EOF

# Proteger el archivo
chmod 600 aws-credentials.txt
```

**⚠️ IMPORTANTE:** Agregar a `.gitignore`:
```
aws-credentials.txt
migration/*.txt
*.pem
```

## Troubleshooting

### Error: "Connection timed out"
- Verificar Security Group permite tu IP
- Verificar que RDS tiene "Public accessibility" habilitado (si conectas desde internet)
- Verificar que la subnet del RDS tiene ruta a Internet Gateway

### Error: "password authentication failed"
- Verificar usuario y contraseña correctos
- El usuario master por defecto es `postgres` (a menos que lo hayas cambiado)

### Error: "database n8n_db does not exist"
- Olvidaste especificar "Initial database name" al crear RDS
- Solución: Crear la base de datos manualmente:
  ```sql
  psql -h <endpoint> -U postgres -d postgres
  CREATE DATABASE n8n_db;
  \q
  ```

### Error: "SSL connection required"
- RDS requiere SSL por defecto
- Agregar parámetro SSL: `psql "sslmode=require host=<endpoint> dbname=n8n_db user=postgres"`

## Siguiente Paso

Una vez completado RDS, continuar con:
→ **[AWS-EC2-SETUP-GUIDE.md](AWS-EC2-SETUP-GUIDE.md)** - Configurar EC2 para n8n
