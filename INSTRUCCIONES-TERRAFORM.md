# 🚀 Instrucciones Finales - Despliegue con Terraform

## ✅ Lo que ya está configurado:

1. ✅ Terraform instalado (v1.14.5)
2. ✅ AWS CLI instalado y configurado
3. ✅ SSH key creado (~/.ssh/id_rsa)
4. ✅ terraform.tfvars configurado con contraseña segura
5. ✅ Script de despliegue automatizado creado

---

## 🎯 Paso Final: Ejecutar el Despliegue

### Opción 1: Script Automatizado (Recomendado) 🌟

**Paso 1: Reiniciar Terminal**
- Cierra esta ventana de terminal
- Abre una **nueva terminal** (Git Bash o CMD)

**Paso 2: Navegar al proyecto**
```bash
cd "C:\Users\JonatanDavidPolancoH\OneDrive - Perceptio S.A.S\Escritorio\OCAI_DEV"
```

**Paso 3: Ejecutar el script**
```bash
./deploy-terraform.sh
```

Este script hará **TODO automáticamente**:
- ✅ Verifica pre-requisitos
- ✅ Inicializa Terraform
- ✅ Muestra el plan de ejecución
- ✅ Despliega toda la infraestructura (con tu confirmación)
- ✅ Guarda los outputs
- ✅ Muestra próximos pasos

⏱️ **Tiempo: 10-15 minutos**

---

### Opción 2: Comandos Manuales

Si prefieres ejecutar paso a paso:

**1. Reiniciar Terminal** (IMPORTANTE)

**2. Navegar al proyecto**
```bash
cd "C:\Users\JonatanDavidPolancoH\OneDrive - Perceptio S.A.S\Escritorio\OCAI_DEV"
cd terraform
```

**3. Verificar Terraform**
```bash
terraform --version
# Debe mostrar: Terraform v1.14.5
```

**4. Inicializar Terraform**
```bash
terraform init
```

**5. Ver el plan**
```bash
terraform plan
```

**6. Aplicar (crear infraestructura)**
```bash
terraform apply
```

Escribir `yes` cuando pregunte.

---

## 📋 Información Importante

### Contraseña de Base de Datos
La contraseña ya está configurada en `terraform/terraform.tfvars`:
```
db_password = "OcaiMedical2026!Secure#DB"
```

**⚠️ Guarda esta contraseña** - la necesitarás para:
- Conectar a RDS desde tu computadora
- Configurar credenciales en n8n
- Aplicar scripts SQL

### Credenciales AWS
Ya están configuradas:
- Account: 444847048892
- User: BedrockAPIKey-m3ea
- Region: us-east-1

### SSH Key
Ya creado en:
- Privada: `~/.ssh/id_rsa`
- Pública: `~/.ssh/id_rsa.pub`

---

## 🎬 Después del Despliegue

### 1. Aplicar Scripts SQL a RDS (5 min)

```bash
cd migration

# Usar el endpoint que Terraform te dio
./1-setup-rds.sh <rds-endpoint> postgres n8n_db

# Verificar
./2-verify-rds.sh <rds-endpoint> postgres n8n_db
```

### 2. Configurar DNS (5 min)

Actualizar registro DNS:
```
Host: n8n.ocaihealth.com
Type: A
Value: <ec2-public-ip>  # Del output de Terraform
TTL: 300
```

### 3. Esperar DNS y SSL (10-60 min)

DNS toma tiempo en propagar. Mientras tanto:
- Let's Encrypt obtendrá el certificado SSL automáticamente
- n8n estará disponible internamente en EC2

### 4. Conectar por SSH

```bash
ssh -i ~/.ssh/id_rsa ubuntu@<ec2-ip>

# Verificar que n8n está corriendo
docker ps
cd ~/n8n
docker-compose logs -f
```

### 5. Acceder a n8n

Una vez DNS propagado:
```
https://n8n.ocaihealth.com
```

---

## 📊 Recursos que se Crearán

### Amazon RDS PostgreSQL
- **Identifier:** ocai-medical-db
- **Instance:** db.t3.micro (1 vCPU, 1GB RAM)
- **Storage:** 20 GB gp3
- **Database:** n8n_db
- **Costo:** ~$15-20/mes

### Amazon EC2
- **Name:** ocai-n8n-server
- **Instance:** t3.small (2 vCPU, 2GB RAM)
- **Storage:** 30 GB gp3
- **AMI:** Ubuntu 22.04 LTS
- **Costo:** ~$15-20/mes

### Networking
- 2 Security Groups (RDS y EC2)
- 1 Elastic IP (gratis mientras esté asociada)

### Configuración Automática
- Docker + Docker Compose
- n8n + Traefik
- SSL con Let's Encrypt

**Costo Total Mensual: ~$40-50**

---

## 🐛 Troubleshooting

### "terraform: command not found"
**Solución:** Reiniciar la terminal

### "No valid credential sources found"
**Solución:**
```bash
aws configure
# Volver a ingresar Access Key y Secret Key
```

### Error al crear RDS
**Posibles causas:**
- Región no soporta db.t3.micro → Cambiar a db.t3.small en terraform.tfvars
- Cuota de RDS alcanzada → Verificar límites en AWS Console

### Error al crear EC2
**Posibles causas:**
- Cuota de instancias alcanzada
- Key pair no válido → Verificar que ~/.ssh/id_rsa.pub existe

### Terraform apply se cuelga
Es normal durante la creación de RDS (5-8 minutos). Espera pacientemente.

---

## 🆘 Si Algo Sale Mal

### Destruir y volver a intentar
```bash
cd terraform
terraform destroy
# Escribir "yes"

# Luego volver a aplicar
terraform apply
```

### Ver logs de Terraform
```bash
export TF_LOG=DEBUG
terraform apply
```

### Verificar estado
```bash
terraform show
terraform state list
```

---

## 📞 Archivos de Referencia

- **Script de despliegue:** `deploy-terraform.sh`
- **Configuración:** `terraform/terraform.tfvars`
- **Plan de migración:** `C:\Users\...\plans\immutable-greeting-kahan.md`
- **Guía completa:** `terraform/README.md`
- **Checklist:** `migration/MIGRATION-CHECKLIST.md`

---

## ✅ Checklist Rápido

Antes de ejecutar el script, verifica:
- [ ] Terminal reiniciada
- [ ] En la carpeta correcta del proyecto
- [ ] Terraform funciona: `terraform --version`
- [ ] AWS configurado: `aws sts get-caller-identity`
- [ ] SSH key existe: `ls ~/.ssh/id_rsa.pub`

---

## 🎯 Comando para Ejecutar AHORA

```bash
# 1. Cerrar esta terminal
# 2. Abrir nueva terminal
# 3. Ejecutar:

cd "C:\Users\JonatanDavidPolancoH\OneDrive - Perceptio S.A.S\Escritorio\OCAI_DEV"
./deploy-terraform.sh
```

---

**¡Todo listo para desplegar! 🚀**

Una vez que reinicies la terminal y ejecutes el script, el despliegue será completamente automático.
