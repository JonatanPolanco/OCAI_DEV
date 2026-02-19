# Guía Paso a Paso: Configurar EC2 para n8n

## Paso 1: Crear Security Group para EC2

1. En AWS Console, buscar "EC2"
2. En el menú lateral, click en "Security Groups" (bajo Network & Security)
3. Click en "Create security group"
4. Configurar:
   - **Name:** `ocai-n8n-sg`
   - **Description:** Security group for OCAI n8n instance
   - **VPC:** Seleccionar la misma VPC usada para RDS

### Inbound Rules:
Click "Add rule" para cada regla:

**Regla 1: HTTP**
- Type: `HTTP`
- Protocol: `TCP`
- Port range: `80`
- Source: `Anywhere IPv4` (`0.0.0.0/0`)
- Description: `HTTP for redirect to HTTPS`

**Regla 2: HTTPS**
- Type: `HTTPS`
- Protocol: `TCP`
- Port range: `443`
- Source: `Anywhere IPv4` (`0.0.0.0/0`)
- Description: `HTTPS for n8n access`

**Regla 3: SSH**
- Type: `SSH`
- Protocol: `TCP`
- Port range: `22`
- Source: `My IP` (tu IP actual)
- Description: `SSH access for administration`

### Outbound Rules:
- Dejar por defecto (All traffic)

5. Click "Create security group"
6. **Guardar el ID del Security Group**

## Paso 2: Actualizar Security Group de RDS

**Importante:** Permitir que EC2 acceda a RDS

1. Ir a "Security Groups" y buscar el SG de RDS (`ocai-rds-sg`)
2. Click en el SG → Pestaña "Inbound rules" → "Edit inbound rules"
3. "Add rule":
   - Type: `PostgreSQL`
   - Port: `5432`
   - Source: **Custom** → Seleccionar `ocai-n8n-sg` (el SG de EC2)
   - Description: `Access from n8n EC2 instance`
4. "Save rules"

## Paso 3: Asignar Elastic IP (Recomendado)

**Nota:** Elastic IP es gratuita mientras esté asociada a una instancia en ejecución

1. En EC2 Console, menú lateral → "Elastic IPs" (bajo Network & Security)
2. Click "Allocate Elastic IP address"
3. Seleccionar:
   - **Network Border Group:** Default para tu región
   - **Public IPv4 address pool:** Amazon's pool of IPv4 addresses
4. Click "Allocate"
5. **Guardar la Elastic IP asignada** (ej: `54.123.45.67`)
   - La asociaremos a la instancia EC2 después de crearla

## Paso 4: Crear Key Pair (si no existe)

Si ya tienen `ocai-key-pair.pem`, saltar este paso.

1. En EC2 Console, menú lateral → "Key Pairs" (bajo Network & Security)
2. Click "Create key pair"
3. Configurar:
   - **Name:** `ocai-key-pair-aws`
   - **Key pair type:** RSA
   - **Private key file format:** `.pem` (para Linux/Mac) o `.ppk` (para PuTTY)
4. Click "Create key pair"
5. **Guardar el archivo .pem en un lugar seguro**
6. Cambiar permisos del archivo:
   ```bash
   chmod 400 ocai-key-pair-aws.pem
   ```

## Paso 5: Lanzar Instancia EC2

1. En EC2 Console, click en "Launch Instance"

### Name and tags:
- **Name:** `ocai-n8n-server`

### Application and OS Images:
- **Quick Start:** Ubuntu
- **Ubuntu Server 22.04 LTS** (64-bit x86)
- **AMI:** Seleccionar la versión más reciente (Free tier eligible)

### Instance type:
- **Instance type:** `t3.small` (2 vCPU, 2 GB RAM)
  - Alternativa económica: `t3.micro` (1 vCPU, 1 GB RAM) - puede ser lenta
  - Para mejor rendimiento: `t3.medium` (2 vCPU, 4 GB RAM)

### Key pair:
- Seleccionar el key pair existente o el creado en Paso 4

### Network settings:
Click "Edit" para configurar:
- **VPC:** Seleccionar la misma VPC del RDS
- **Subnet:** Seleccionar una subnet **pública** (con acceso a internet)
- **Auto-assign public IP:** Enable
- **Firewall (security groups):** Select existing security group
  - Seleccionar `ocai-n8n-sg` (creado en Paso 1)

### Configure storage:
- **Size:** `30` GB
- **Volume type:** gp3 (General Purpose SSD)
- **Delete on termination:** ✓ (recomendado)
- **Encrypted:** ✓ (recomendado)

### Advanced details (Opcional):
- **IAM instance profile:** Ninguno (por ahora)
- **User data:** Dejar vacío (instalaremos manualmente)

### Summary:
- Verificar que todo está correcto
- **Estimated cost:** ~$15-20/mes para t3.small

2. Click "Launch instance"
3. Esperar 2-3 minutos mientras se inicializa

## Paso 6: Asociar Elastic IP a EC2

1. Ir a "Elastic IPs"
2. Seleccionar la IP asignada en Paso 3
3. Click "Actions" → "Associate Elastic IP address"
4. Configurar:
   - **Resource type:** Instance
   - **Instance:** Seleccionar `ocai-n8n-server`
   - **Private IP address:** Seleccionar la única opción disponible
5. Click "Associate"

**Ahora tu EC2 tiene una IP pública permanente.**

## Paso 7: Conectar a EC2 via SSH

Obtener la IP pública de la instancia:
1. En EC2 Console → Instances
2. Seleccionar `ocai-n8n-server`
3. Copiar "Public IPv4 address" o la Elastic IP

Conectar:
```bash
ssh -i ocai-key-pair-aws.pem ubuntu@<elastic-ip>
# Ejemplo: ssh -i ocai-key-pair-aws.pem ubuntu@54.123.45.67
```

Si es la primera vez, confirmar la conexión escribiendo `yes`.

Deberías ver:
```
ubuntu@ip-172-31-x-x:~$
```

## Paso 8: Instalar Docker y Docker Compose

Ejecutar en la instancia EC2:

```bash
# Actualizar sistema
sudo apt update
sudo apt upgrade -y

# Instalar Docker
sudo apt install -y docker.io

# Instalar Docker Compose (versión standalone)
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Agregar usuario ubuntu al grupo docker
sudo usermod -aG docker ubuntu

# Habilitar Docker al inicio
sudo systemctl enable docker
sudo systemctl start docker

# Verificar instalación
docker --version
docker-compose --version
```

**Importante:** Cerrar sesión SSH y volver a conectar para que los cambios de grupo surtan efecto:
```bash
exit
ssh -i ocai-key-pair-aws.pem ubuntu@<elastic-ip>
```

Verificar que puedes ejecutar Docker sin sudo:
```bash
docker ps
# Debería mostrar: CONTAINER ID   IMAGE   COMMAND   CREATED   STATUS   PORTS   NAMES
```

## Paso 9: Crear Estructura de Directorios

```bash
# Crear directorio para n8n
mkdir -p ~/n8n
cd ~/n8n

# Crear directorio para archivos locales
mkdir -p local-files
```

## Paso 10: Transferir Archivos desde Local

Desde tu computadora local (NO en la sesión SSH):

```bash
# Navegar a la carpeta del proyecto
cd "C:\Users\JonatanDavidPolancoH\OneDrive - Perceptio S.A.S\Escritorio\OCAI_DEV"

# Transferir docker-compose.yml
scp -i ocai-key-pair-aws.pem gcp_instance/docker-compose.yml ubuntu@<elastic-ip>:~/n8n/

# Transferir .env
scp -i ocai-key-pair-aws.pem gcp_instance/.env ubuntu@<elastic-ip>:~/n8n/
```

**Nota para Windows:** Si el comando `scp` no funciona, usar:
- Git Bash (viene con Git for Windows)
- WinSCP (aplicación gráfica)
- O copiar manualmente el contenido de los archivos

## Paso 11: Crear acme.json para Let's Encrypt

Volver a la sesión SSH en EC2:

```bash
cd ~/n8n
touch acme.json
chmod 600 acme.json
```

## Paso 12: Iniciar Docker Compose

```bash
cd ~/n8n

# Iniciar contenedores en background
docker-compose up -d

# Verificar logs
docker-compose logs -f n8n
# Presionar Ctrl+C para salir de los logs

# Verificar que los contenedores están corriendo
docker ps
```

Deberías ver dos contenedores:
- `n8n_n8n_1` (o similar)
- `n8n_traefik_1` (o similar)

## Paso 13: Verificar Acceso Temporal

**ANTES de configurar DNS**, verificar que n8n funciona:

### Opción A: Acceso via IP (puede no funcionar por SSL)
```
http://<elastic-ip>
```

### Opción B: Configurar /etc/hosts temporal

En tu computadora local:

**Windows:**
1. Abrir Notepad como Administrador
2. Abrir archivo: `C:\Windows\System32\drivers\etc\hosts`
3. Agregar línea:
   ```
   <elastic-ip>  n8n.ocaihealth.com
   ```
4. Guardar

**Linux/Mac:**
```bash
sudo nano /etc/hosts
# Agregar:
# <elastic-ip>  n8n.ocaihealth.com
```

Ahora puedes acceder temporalmente a:
```
http://n8n.ocaihealth.com
```

**Nota:** El HTTPS no funcionará hasta que configures DNS real y Let's Encrypt obtenga el certificado.

## Paso 14: Verificar Logs

```bash
# Logs de n8n
docker-compose logs n8n

# Logs de Traefik
docker-compose logs traefik

# Seguir logs en tiempo real
docker-compose logs -f
```

Buscar errores en los logs. Deberías ver:
- n8n iniciando en puerto 5678
- Traefik iniciando en puertos 80 y 443

## Paso 15: Configurar Auto-restart (Opcional)

Para que Docker Compose inicie automáticamente después de reiniciar EC2:

```bash
# Crear servicio systemd
sudo nano /etc/systemd/system/n8n-docker.service
```

Copiar:
```ini
[Unit]
Description=n8n Docker Compose
Requires=docker.service
After=docker.service

[Service]
Type=oneshot
RemainAfterExit=yes
WorkingDirectory=/home/ubuntu/n8n
ExecStart=/usr/local/bin/docker-compose up -d
ExecStop=/usr/local/bin/docker-compose down
User=ubuntu

[Install]
WantedBy=multi-user.target
```

Guardar (Ctrl+X, Y, Enter) y habilitar:
```bash
sudo systemctl enable n8n-docker.service
sudo systemctl start n8n-docker.service
```

## Troubleshooting

### Error: "Permission denied" al ejecutar docker
- Verificar que estás en el grupo docker: `groups`
- Si no aparece "docker", ejecutar: `sudo usermod -aG docker $USER`
- Cerrar sesión y volver a conectar

### Error: "Cannot connect to Docker daemon"
- Verificar que Docker está corriendo: `sudo systemctl status docker`
- Si no está corriendo: `sudo systemctl start docker`

### Contenedores no inician
- Verificar logs: `docker-compose logs`
- Verificar permisos de acme.json: `ls -la acme.json` (debería ser `-rw-------`)
- Verificar archivo .env está presente: `cat .env`

### No puedo acceder por HTTP
- Verificar Security Group permite puerto 80 y 443
- Verificar que los contenedores están corriendo: `docker ps`
- Verificar logs de Traefik: `docker-compose logs traefik`

### Let's Encrypt no obtiene certificado
- Verificar que DNS apunta correctamente a la Elastic IP
- Esperar propagación de DNS (puede tomar hasta 48h)
- Verificar logs de Traefik: `docker-compose logs traefik | grep acme`

## Siguiente Paso

Una vez que n8n esté funcionando:
→ **Configurar DNS** (actualizar registro A de n8n.ocaihealth.com)
→ **Importar workflows** en n8n UI
→ **Configurar credenciales** de PostgreSQL en n8n

## Comandos Útiles

```bash
# Reiniciar contenedores
docker-compose restart

# Detener contenedores
docker-compose down

# Ver logs
docker-compose logs -f

# Ejecutar comando dentro de contenedor n8n
docker-compose exec n8n bash

# Ver uso de recursos
docker stats

# Limpiar contenedores detenidos
docker system prune -a
```

## Información para Guardar

Crear archivo con detalles de EC2:

```
=== EC2 Instance Info ===
Instance ID: i-xxxxxxxxx
Instance Type: t3.small
Elastic IP: <tu-elastic-ip>
Security Group: ocai-n8n-sg (sg-xxxxx)
Key Pair: ocai-key-pair-aws
Region: us-east-1
Availability Zone: us-east-1a

SSH Command:
ssh -i ocai-key-pair-aws.pem ubuntu@<elastic-ip>

n8n Directory: /home/ubuntu/n8n
Docker Compose: /home/ubuntu/n8n/docker-compose.yml
```
