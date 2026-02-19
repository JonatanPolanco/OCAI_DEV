# Terraform Infrastructure as Code para OCAI Medical

Este directorio contiene la configuración de Terraform para desplegar toda la infraestructura de OCAI Medical en AWS automáticamente.

## ¿Qué crea Terraform?

### Infraestructura AWS:
1. **RDS PostgreSQL**
   - Instancia db.t3.micro
   - Base de datos `n8n_db`
   - Backups automáticos
   - Encryption habilitado

2. **EC2 Instance**
   - Ubuntu 22.04 LTS
   - t3.small (configurable)
   - Docker y Docker Compose preinstalados
   - n8n y Traefik configurados automáticamente
   - SSL con Let's Encrypt

3. **Networking**
   - Security Groups (RDS y EC2)
   - Elastic IP
   - Reglas de firewall configuradas

4. **Configuración Automática**
   - n8n iniciando automáticamente
   - SSL configurado
   - Conexión a RDS preconfigurada

## Pre-requisitos

### 1. Instalar Terraform

**Windows (con Chocolatey):**
```bash
choco install terraform
```

**Windows (manual):**
1. Descargar desde https://www.terraform.io/downloads
2. Extraer terraform.exe
3. Agregar a PATH

**Mac:**
```bash
brew install terraform
```

**Linux:**
```bash
# Ubuntu/Debian
wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
sudo apt update && sudo apt install terraform
```

Verificar instalación:
```bash
terraform --version
# Debe mostrar: Terraform v1.x.x
```

### 2. Configurar AWS CLI

Instalar AWS CLI:
```bash
# Windows
choco install awscli

# Mac
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

Configurar credenciales:
```bash
aws configure
# AWS Access Key ID: [tu-access-key]
# AWS Secret Access Key: [tu-secret-key]
# Default region: us-east-1
# Default output format: json
```

Verificar:
```bash
aws sts get-caller-identity
# Debe mostrar tu información de cuenta
```

### 3. Generar SSH Key Pair (si no existe)

```bash
# Generar nuevo key pair
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""

# Verificar que se crearon
ls ~/.ssh/id_rsa*
# Debe mostrar: id_rsa (privada) y id_rsa.pub (pública)
```

## Configuración Rápida

### 1. Copiar y editar variables

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Editar `terraform.tfvars`:
```hcl
# Cambiar MÍNIMO estos valores:
db_password = "TuContraseñaSegura123!"  # ⚠️ CAMBIAR ESTO

# Verificar rutas SSH (Windows):
public_key_path  = "C:/Users/TuUsuario/.ssh/id_rsa.pub"
private_key_path = "C:/Users/TuUsuario/.ssh/id_rsa"

# O en Linux/Mac:
public_key_path  = "~/.ssh/id_rsa.pub"
private_key_path = "~/.ssh/id_rsa"
```

### 2. Inicializar Terraform

```bash
terraform init
```

Esto descarga los providers de AWS necesarios.

### 3. Ver el plan de ejecución

```bash
terraform plan
```

Esto muestra qué recursos se crearán SIN crearlos todavía. Verifica que todo se vea bien.

### 4. Aplicar la configuración

```bash
terraform apply
```

Terraform preguntará:
```
Do you want to perform these actions? (yes/no)
```

Escribe `yes` y presiona Enter.

**⏱️ Tiempo de creación: 10-15 minutos**

Terraform creará:
- Security Groups (30 seg)
- RDS PostgreSQL (5-8 min)
- Elastic IP (10 seg)
- EC2 Instance (2-3 min)
- Configuración automática (2-3 min)

### 5. Ver los outputs

Al finalizar, Terraform mostrará:
```
Outputs:

rds_endpoint = "ocai-medical-db.xxxxx.us-east-1.rds.amazonaws.com"
rds_port = 5432
ec2_public_ip = "54.123.45.67"
ssh_command = "ssh -i ~/.ssh/id_rsa ubuntu@54.123.45.67"
n8n_url = "https://n8n.ocaihealth.com"
```

**Guardar estos valores!**

## Post-Despliegue

### 1. Esperar que RDS esté disponible

```bash
# Ver estado de RDS
aws rds describe-db-instances --db-instance-identifier ocai-medical-db --query 'DBInstances[0].DBInstanceStatus'
```

Esperar hasta que muestre: `"available"`

### 2. Conectar por SSH a EC2

```bash
# Usar el comando del output
ssh -i ~/.ssh/id_rsa ubuntu@<ec2-public-ip>
```

### 3. Verificar que n8n está corriendo

```bash
# En EC2
cd ~/n8n
docker ps

# Deberías ver 2 contenedores:
# - n8n_n8n_1
# - n8n_traefik_1
```

Ver logs:
```bash
docker-compose logs -f n8n
```

### 4. Aplicar scripts SQL a RDS

Desde tu computadora local:

```bash
cd ..  # Volver a la raíz del proyecto

# Obtener el endpoint de RDS
terraform output rds_endpoint

# Aplicar scripts SQL
psql -h <rds-endpoint> -U postgres -d n8n_db -f pipelines/ddl.sql
psql -h <rds-endpoint> -U postgres -d n8n_db -f pipelines/clinic_onboarding.sql
psql -h <rds-endpoint> -U postgres -d n8n_db -f pipelines/clinic_onboarding_sp.sql
psql -h <rds-endpoint> -U postgres -d n8n_db -f pipelines/clinic_onboarding_trigger.sql
```

O usar el script automático:
```bash
cd migration
./1-setup-rds.sh <rds-endpoint> postgres n8n_db
```

### 5. Configurar DNS

Actualizar registro DNS A:
```
Host: n8n.ocaihealth.com
Type: A
Value: <ec2-public-ip>  # Del output de Terraform
TTL: 300
```

### 6. Acceder a n8n

Una vez que DNS propague (5-60 minutos):
```
https://n8n.ocaihealth.com
```

Let's Encrypt obtendrá el certificado SSL automáticamente.

## Comandos Útiles

### Ver estado de la infraestructura
```bash
terraform show
```

### Ver outputs guardados
```bash
terraform output
terraform output rds_endpoint
terraform output ec2_public_ip
```

### Ver connection string (contiene password)
```bash
terraform output connection_string
```

### Actualizar infraestructura
Si cambias algo en los archivos .tf:
```bash
terraform plan    # Ver qué cambiaría
terraform apply   # Aplicar cambios
```

### Destruir toda la infraestructura
**⚠️ CUIDADO: Esto elimina todo**
```bash
terraform destroy
```

## Personalización

### Cambiar tamaño de instancias

Editar `terraform.tfvars`:
```hcl
# Para más potencia en RDS
db_instance_class = "db.t3.small"  # o "db.t3.medium"

# Para más potencia en EC2
ec2_instance_type = "t3.medium"    # o "t3.large"
```

Aplicar cambios:
```bash
terraform apply
```

### Cambiar región de AWS

Editar `terraform.tfvars`:
```hcl
aws_region = "us-west-2"  # O la región que prefieras
```

**Nota:** Cambiar región requiere recrear toda la infraestructura.

## Archivos Importantes

```
terraform/
├── main.tf                    # Configuración principal
├── variables.tf               # Definición de variables
├── terraform.tfvars.example   # Ejemplo de configuración
├── terraform.tfvars           # Tu configuración (NO commitear)
├── user_data.sh              # Script de inicialización EC2
└── README.md                 # Esta guía
```

## Troubleshooting

### Error: "InvalidKeyPair.NotFound"
- Verificar que la ruta de `public_key_path` es correcta
- El archivo debe existir: `ls -la ~/.ssh/id_rsa.pub`

### Error: "UnauthorizedOperation"
- Verificar que AWS CLI está configurado: `aws sts get-caller-identity`
- Verificar que tienes permisos en AWS

### Error: "DBInstanceNotFound"
- RDS toma 5-8 minutos en crear
- Esperar a que termine completamente antes de usar

### EC2 no responde SSH
- Esperar 2-3 minutos después de que Terraform termine
- Verificar Security Group permite tu IP
- Verificar que estás usando `ubuntu@<ip>` (no `root@`)

### n8n no carga
- Verificar DNS apunta a la IP correcta: `nslookup n8n.ocaihealth.com`
- Esperar propagación de DNS (puede tomar hasta 48h)
- Conectar por SSH y ver logs: `docker-compose logs -f`

## Costos Mensuales Estimados

Con configuración por defecto:
- RDS db.t3.micro: ~$15-20
- EC2 t3.small: ~$15-20
- Storage: ~$5
- Transfer: ~$5
- **Total: ~$40-50/mes**

## Estado de Terraform

Terraform guarda el estado en `terraform.tfstate`.

**⚠️ MUY IMPORTANTE:**
- **NO** eliminar `terraform.tfstate`
- **NO** commitear `terraform.tfstate` a Git
- Hacer backup de `terraform.tfstate` regularmente

Para usar remote state (recomendado para equipos):
```hcl
# Agregar a main.tf
terraform {
  backend "s3" {
    bucket = "mi-bucket-terraform-state"
    key    = "ocai/terraform.tfstate"
    region = "us-east-1"
  }
}
```

## Próximos Pasos

1. ✅ Terraform aplicado
2. ⏳ Aplicar scripts SQL a RDS
3. ⏳ Configurar DNS
4. ⏳ Importar workflows en n8n
5. ⏳ Configurar credenciales en n8n
6. ⏳ Probar flujo end-to-end

Continuar con: `../migration/MIGRATION-CHECKLIST.md`
