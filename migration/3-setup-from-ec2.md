# Ejecutar Migración desde EC2 (Sin instalar nada localmente)

## Ventajas
- ✓ No instalas nada en tu PC Windows
- ✓ La EC2 ya está en la misma VPC que RDS (más rápido y seguro)
- ✓ No necesitas abrir el Security Group de RDS a Internet
- ✓ PostgreSQL client ya está instalado en la EC2

## Pasos

### 1. Obtener IP de tu EC2

```powershell
# Desde tu PC
cd terraform
terraform output ec2_public_ip
```

O busca la IP en AWS Console → EC2 → Instances

### 2. Conectarte por SSH

```bash
# Usar la key que configuraste
ssh -i ~/.ssh/id_rsa ubuntu@TU_IP_EC2

# O si usaste la key por defecto:
ssh -i "C:\Users\JonatanDavidPolancoH\.ssh\id_rsa" ubuntu@TU_IP_EC2
```

### 3. Subir los archivos SQL a EC2

Opción A - Usar SCP (desde tu PC):
```bash
# Navega a tu proyecto
cd "C:\Users\JonatanDavidPolancoH\OneDrive - Perceptio S.A.S\Escritorio\OCAI_DEV"

# Sube la carpeta pipelines
scp -i ~/.ssh/id_rsa -r pipelines/ ubuntu@TU_IP_EC2:~/
```

Opción B - Clonar desde Git (si tu repo está en GitHub/GitLab):
```bash
# En la EC2
git clone https://github.com/tu-usuario/OCAI_DEV.git
cd OCAI_DEV
```

Opción C - Crear los archivos manualmente en EC2:
```bash
# En la EC2
mkdir -p ~/pipelines
nano ~/pipelines/ddl.sql  # Pega el contenido
# Repetir para cada archivo SQL
```

### 4. Ejecutar la migración desde EC2

```bash
# En la EC2, obtener el endpoint de RDS
RDS_HOST="ocai-medical-db.copmy0ewmif4.us-east-1.rds.amazonaws.com"
DB_USER="postgres"
DB_NAME="n8n_db"

# Test de conexión
psql -h $RDS_HOST -U $DB_USER -d $DB_NAME -c "SELECT 1;"

# Aplicar DDL
psql -h $RDS_HOST -U $DB_USER -d $DB_NAME -f ~/pipelines/ddl.sql

# Aplicar onboarding tables
psql -h $RDS_HOST -U $DB_USER -d $DB_NAME -f ~/pipelines/clinic_onboarding.sql

# Aplicar stored procedure
psql -h $RDS_HOST -U $DB_USER -d $DB_NAME -f ~/pipelines/clinic_onboarding_sp.sql

# Aplicar trigger
psql -h $RDS_HOST -U $DB_USER -d $DB_NAME -f ~/pipelines/clinic_onboarding_trigger.sql

# Verificar
psql -h $RDS_HOST -U $DB_USER -d $DB_NAME -c "\dt medical.*"
```

### 5. Script automatizado en EC2

O sube el script bash a la EC2:
```bash
# Desde tu PC
scp -i ~/.ssh/id_rsa migration/1-setup-rds.sh ubuntu@TU_IP_EC2:~/

# En la EC2
bash ~/1-setup-rds.sh ocai-medical-db.copmy0ewmif4.us-east-1.rds.amazonaws.com postgres n8n_db
```

## Ventajas de este enfoque

1. **Seguridad**: RDS solo acepta conexiones desde la VPC, no desde Internet
2. **Velocidad**: Conexión directa dentro de AWS
3. **Simple**: No instalas nada en tu PC Windows
4. **Persistente**: Los scripts quedan en la EC2 para futuras migraciones
