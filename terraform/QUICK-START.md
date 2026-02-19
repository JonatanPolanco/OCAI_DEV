# 🚀 Quick Start - Despliegue con Terraform

## ✅ Terraform Instalado

Terraform v1.14.5 está instalado correctamente.

## 📋 Checklist de Pre-requisitos

Antes de ejecutar Terraform, necesitas:

### 1. ✅ Terraform Instalado
```bash
terraform --version
# Debería mostrar: Terraform v1.14.5
```

**Si no funciona:** Reinicia la terminal (cerrar y abrir nueva ventana).

### 2. ⚠️ Configurar AWS CLI

```bash
# Verificar si AWS CLI está instalado
aws --version

# Si no está instalado:
winget install Amazon.AWSCLI

# Configurar credenciales
aws configure
```

Cuando pida información, ingresar:
```
AWS Access Key ID: [Obtener de AWS Console → IAM → Security Credentials]
AWS Secret Access Key: [Obtener de AWS Console → IAM → Security Credentials]
Default region name: us-east-1
Default output format: json
```

**Obtener credenciales AWS:**
1. Ir a https://console.aws.amazon.com/
2. Click en tu nombre arriba a la derecha → Security Credentials
3. Scroll down → Access keys → Create access key
4. Copiar Access Key ID y Secret Access Key

### 3. ⚠️ Crear SSH Key Pair

```bash
# Verificar si ya existe
ls ~/.ssh/id_rsa.pub

# Si no existe, crear uno nuevo
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
```

Para Git Bash en Windows:
```bash
mkdir -p ~/.ssh
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
```

### 4. ⚠️ Configurar Variables de Terraform

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars
```

Editar `terraform.tfvars` con un editor de texto:
```bash
# Abrir con VS Code
code terraform.tfvars

# O con Notepad
notepad terraform.tfvars
```

**Cambios OBLIGATORIOS:**
```hcl
# Línea 14: CAMBIAR contraseña
db_password = "TuContraseñaSegura123!"

# Líneas 23-24: Verificar rutas (Windows)
public_key_path  = "C:/Users/JonatanDavidPolancoH/.ssh/id_rsa.pub"
private_key_path = "C:/Users/JonatanDavidPolancoH/.ssh/id_rsa"
```

**Nota:** En Windows, usar `/` (forward slash), NO `\` (backslash).

---

## 🎯 Despliegue en 4 Pasos

### Paso 1: Navegar a carpeta terraform

```bash
cd "C:\Users\JonatanDavidPolancoH\OneDrive - Perceptio S.A.S\Escritorio\OCAI_DEV\terraform"
```

### Paso 2: Inicializar Terraform

```bash
terraform init
```

Esto descarga el provider de AWS. Deberías ver:
```
Terraform has been successfully initialized!
```

### Paso 3: Ver el Plan (Opcional pero Recomendado)

```bash
terraform plan
```

Esto muestra QUÉ se va a crear SIN crear nada todavía. Revisa que:
- Se crearán 2 Security Groups
- Se creará 1 RDS PostgreSQL
- Se creará 1 EC2 Instance
- Se creará 1 Elastic IP

### Paso 4: Aplicar (Crear Todo)

```bash
terraform apply
```

Terraform preguntará:
```
Do you want to perform these actions?
  Terraform will perform the actions described above.
  Only 'yes' will be accepted to approve.

  Enter a value:
```

Escribe `yes` y presiona Enter.

⏱️ **Tiempo de espera: 10-15 minutos**

Verás el progreso:
- Creating aws_security_group.rds... ✓
- Creating aws_security_group.ec2... ✓
- Creating aws_db_instance.postgres... (5-8 min)
- Creating aws_instance.n8n... (2-3 min)
- Creating aws_eip.n8n... ✓

---

## 📊 Ver los Resultados

Al terminar, Terraform mostrará los outputs:

```
Outputs:

rds_endpoint = "ocai-medical-db.c9z8x7y6w5v4.us-east-1.rds.amazonaws.com"
rds_port = 5432
rds_database_name = "n8n_db"
ec2_public_ip = "54.123.45.67"
ec2_instance_id = "i-0123456789abcdef0"
ssh_command = "ssh -i C:/Users/JonatanDavidPolancoH/.ssh/id_rsa ubuntu@54.123.45.67"
n8n_url = "https://n8n.ocaihealth.com"
```

**⚠️ GUARDAR estos valores** - Los necesitarás para los siguientes pasos.

---

## 🔍 Verificar que Todo Funciona

### 1. Verificar RDS está disponible

```bash
aws rds describe-db-instances --db-instance-identifier ocai-medical-db --query 'DBInstances[0].DBInstanceStatus'
```

Debería retornar: `"available"`

### 2. Conectar por SSH a EC2

```bash
# Usar el comando del output
ssh -i ~/.ssh/id_rsa ubuntu@<tu-ec2-ip>

# Ejemplo:
# ssh -i ~/.ssh/id_rsa ubuntu@54.123.45.67
```

### 3. Verificar Docker en EC2

Una vez conectado por SSH:

```bash
# Ver contenedores corriendo
docker ps

# Deberías ver:
# - n8n_n8n_1
# - n8n_traefik_1

# Ver logs de n8n
cd ~/n8n
docker-compose logs -f n8n
```

Presiona `Ctrl+C` para salir de los logs.

### 4. Ver información de conexión

```bash
cat ~/n8n/connection-info.txt
```

---

## 📝 Próximos Pasos

### Paso A: Aplicar Scripts SQL a RDS

Desde tu computadora local (NO en EC2):

```bash
cd ../migration

# Usar el endpoint de RDS que Terraform te dio
./1-setup-rds.sh <rds-endpoint> postgres n8n_db

# Ejemplo:
# ./1-setup-rds.sh ocai-medical-db.c9z8x7y6w5v4.us-east-1.rds.amazonaws.com postgres n8n_db
```

Esto aplica todos los scripts SQL en orden y crea:
- Esquema `medical`
- Todas las tablas
- Stored procedures
- Triggers

### Paso B: Configurar DNS

Actualizar el registro DNS A en tu proveedor (GoDaddy, Cloudflare, etc.):

```
Host: n8n.ocaihealth.com
Type: A
Value: <tu-ec2-ip>  # Del output de Terraform
TTL: 300
```

### Paso C: Esperar DNS y SSL

1. Esperar 10-60 minutos para que DNS propague
2. Let's Encrypt obtendrá el certificado SSL automáticamente
3. Verificar en logs de EC2:
   ```bash
   ssh -i ~/.ssh/id_rsa ubuntu@<ec2-ip>
   cd ~/n8n
   docker-compose logs traefik | grep certificate
   ```

### Paso D: Acceder a n8n

Una vez que DNS esté propagado:

```
https://n8n.ocaihealth.com
```

Configurar usuario y contraseña en el setup inicial.

### Paso E: Configurar n8n

1. Crear credenciales de PostgreSQL en n8n:
   - Host: `<rds-endpoint>`
   - Database: `n8n_db`
   - User: `postgres`
   - Password: La que pusiste en terraform.tfvars
   - Port: `5432`
   - SSL: Enabled

2. Importar workflows:
   - En n8n: Click "..." → "Import from File"
   - Importar todos los archivos de `n8n_workflows/`
   - Actualizar credenciales en cada workflow

---

## 🛠️ Comandos Útiles

### Ver outputs guardados
```bash
terraform output
terraform output rds_endpoint
terraform output ec2_public_ip
```

### Ver connection string (incluye password)
```bash
terraform output connection_string
```

### Ver estado de infraestructura
```bash
terraform show
```

### Actualizar configuración
Si cambias algo en terraform.tfvars:
```bash
terraform plan    # Ver cambios
terraform apply   # Aplicar cambios
```

### Destruir todo (⚠️ CUIDADO)
```bash
terraform destroy
# Esto elimina RDS, EC2, y todo lo creado
```

---

## 🐛 Troubleshooting

### Error: "No AWS credentials found"
```bash
aws configure
# Ingresar Access Key y Secret Key
```

### Error: "InvalidKeyPair.NotFound"
Verificar que existe el key pair:
```bash
ls ~/.ssh/id_rsa.pub

# Si no existe, crear:
ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
```

### Error: "terraform: command not found"
Reiniciar la terminal (cerrar y abrir nueva ventana).

### RDS tarda mucho
Es normal, RDS toma 5-8 minutos en crear. Espera pacientemente.

### EC2 no responde SSH
- Esperar 2-3 minutos después de que Terraform termine
- Verificar Security Group permite tu IP
- Usar `ubuntu@<ip>` (NO `root@`)

### n8n no carga
- Verificar DNS: `nslookup n8n.ocaihealth.com`
- Esperar propagación de DNS (puede tomar hasta 48h)
- Ver logs en EC2: `docker-compose logs -f`

---

## 📞 ¿Necesitas Ayuda?

Si encuentras problemas:
1. Revisa esta guía completa
2. Revisa `terraform/README.md` para más detalles
3. Revisa `migration/MIGRATION-CHECKLIST.md` para verificar pasos

---

## ✅ Checklist Rápido

- [ ] Terraform instalado y funcionando
- [ ] AWS CLI instalado y configurado
- [ ] SSH key pair creado
- [ ] terraform.tfvars configurado con contraseña
- [ ] `terraform init` ejecutado
- [ ] `terraform apply` ejecutado (15 min)
- [ ] Outputs guardados
- [ ] RDS disponible (verificado)
- [ ] EC2 accesible por SSH
- [ ] Docker corriendo en EC2
- [ ] Scripts SQL aplicados a RDS
- [ ] DNS configurado apuntando a EC2 IP
- [ ] n8n accesible en https://n8n.ocaihealth.com
- [ ] Credenciales de PostgreSQL en n8n
- [ ] Workflows importados

---

**¡Listo para empezar! 🚀**
