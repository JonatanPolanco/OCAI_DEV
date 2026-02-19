# Deploy n8n con SSL a AWS EC2

Guía rápida para deployar n8n con certificado SSL automático de Let's Encrypt.

## Prerequisitos

✅ Archivos en esta carpeta:
- `docker-compose.yml` - Configuración de Traefik + n8n
- `.env` - Variables de entorno (dominio, email SSL)
- `deploy-to-ec2.sh` o `deploy-to-ec2.ps1` - Script de deployment

✅ En AWS:
- EC2 Ubuntu 22.04 corriendo
- Elastic IP asignada a EC2
- Security Group permite puertos: 22, 80, 443
- Key pair (.pem) descargado

✅ DNS:
- Dominio `ocaihealth.com` registrado
- Acceso para crear registros DNS

## Opción 1: Deploy Automatizado

### Desde Git Bash / WSL / Linux:

```bash
chmod +x deploy-to-ec2.sh
./deploy-to-ec2.sh ocai-key-pair-aws.pem 54.123.45.67
```

### Desde PowerShell (Windows):

```powershell
.\deploy-to-ec2.ps1 -KeyPath "ocai-key-pair-aws.pem" -EC2_IP "54.123.45.67"
```

El script automáticamente:
1. ✅ Verifica conexión SSH
2. ✅ Crea directorios en EC2
3. ✅ Transfiere archivos
4. ✅ Configura acme.json
5. ✅ Verifica Docker instalado
6. ✅ Inicia servicios
7. ✅ Muestra estado

## Opción 2: Deploy Manual

### Paso 1: Conectar a EC2

```bash
ssh -i ocai-key-pair-aws.pem ubuntu@<elastic-ip>
```

### Paso 2: Preparar directorios

```bash
mkdir -p ~/n8n/local-files
cd ~/n8n
```

### Paso 3: Transferir archivos

Desde tu máquina local (otra terminal):

```bash
cd "gcp_instance"
scp -i ocai-key-pair-aws.pem docker-compose.yml ubuntu@<elastic-ip>:~/n8n/
scp -i ocai-key-pair-aws.pem .env ubuntu@<elastic-ip>:~/n8n/
```

### Paso 4: Crear acme.json

En EC2:

```bash
cd ~/n8n
touch acme.json
chmod 600 acme.json
```

### Paso 5: Instalar Docker (si no está)

```bash
sudo apt update
sudo apt install -y docker.io docker-compose
sudo usermod -aG docker ubuntu
exit  # Reconectar SSH
```

### Paso 6: Iniciar servicios

```bash
cd ~/n8n
docker-compose up -d
```

### Paso 7: Ver logs

```bash
docker-compose logs -f
```

## Configurar DNS

### Paso 1: Ir a tu proveedor DNS

- **Route 53** (AWS)
- **Cloudflare**
- **GoDaddy**
- **Namecheap**
- Etc.

### Paso 2: Crear registro A

```
Type: A
Name: n8n
Value: <tu-elastic-ip-de-ec2>
TTL: 300 (5 minutos)
```

### Paso 3: Verificar propagación

```bash
# Esperar 5-15 minutos, luego verificar
nslookup n8n.ocaihealth.com

# Debe retornar tu Elastic IP
```

## Verificar Certificado SSL

Una vez que DNS esté configurado:

```bash
# Conectar a EC2
ssh -i ocai-key-pair-aws.pem ubuntu@<elastic-ip>

# Ver logs de Traefik
cd ~/n8n
docker-compose logs traefik | grep -i certificate

# Deberías ver algo como:
# "Certificates obtained for domain n8n.ocaihealth.com"
```

## Acceder a n8n

1. Abre navegador
2. Ve a: `https://n8n.ocaihealth.com`
3. Verifica:
   - ✅ Candado verde (SSL válido)
   - ✅ No hay advertencias de seguridad
   - ✅ n8n carga correctamente

## Comandos Útiles

```bash
# Ver logs
cd ~/n8n
docker-compose logs -f

# Ver solo logs de n8n
docker-compose logs -f n8n

# Ver solo logs de Traefik
docker-compose logs -f traefik

# Reiniciar servicios
docker-compose restart

# Detener servicios
docker-compose down

# Ver contenedores corriendo
docker ps

# Ver estado de servicios
docker-compose ps

# Ver uso de recursos
docker stats
```

## Troubleshooting

### Error: "acme: error: 403 :: urn:ietf:params:acme:error:unauthorized"

**Causa:** DNS no apunta a tu servidor o Let's Encrypt no puede verificar dominio.

**Solución:**
1. Verificar DNS: `nslookup n8n.ocaihealth.com`
2. Esperar más tiempo (DNS puede tardar hasta 24h)
3. Verificar Security Group permite puerto 80 desde `0.0.0.0/0`

### Navegador muestra "Your connection is not private"

**Causa:** Certificado aún no obtenido.

**Solución:**
1. Verificar logs: `docker-compose logs traefik | grep certificate`
2. Verificar DNS está correcto
3. Esperar 2-5 minutos y recargar

### n8n no carga

**Causa:** Contenedor n8n no inició correctamente.

**Solución:**
```bash
docker-compose logs n8n
docker-compose restart n8n
```

### "Permission denied" al ejecutar docker

**Causa:** Usuario no está en grupo docker.

**Solución:**
```bash
sudo usermod -aG docker ubuntu
exit  # Reconectar SSH
```

## Renovación de Certificado

Traefik renueva automáticamente el certificado 30 días antes de expirar.

Para verificar:
```bash
cat ~/n8n/acme.json | jq '.letsencrypt.Certificates[0].domain'
```

## Configuración Actual

Tu configuración en `.env`:

```bash
DOMAIN_NAME=ocaihealth.com
SUBDOMAIN=n8n
SSL_EMAIL=operation@ocaihealth.com
GENERIC_TIMEZONE=America/Mexico_City
```

Esto significa:
- n8n accesible en: `https://n8n.ocaihealth.com`
- Certificados enviados a: `operation@ocaihealth.com`
- Zona horaria: America/Mexico_City

## Próximos Pasos

Una vez que n8n esté funcionando con SSL:

1. **Conectar a RDS PostgreSQL**
   - En n8n, crear credencial PostgreSQL
   - Host: `ocai-medical-db.copmy0ewmif4.us-east-1.rds.amazonaws.com`
   - Database: `n8n_db`
   - Schema: `medical`

2. **Importar workflows**
   - Workflows de WhatsApp
   - Workflows de CRM
   - Workflow de clinic onboarding

3. **Configurar webhooks**
   - Actualizar URLs a: `https://n8n.ocaihealth.com/webhook/...`
   - Probar con Lambda de appointments

4. **Monitoreo**
   - Configurar alertas
   - Configurar backups

## Información de Soporte

Si encuentras problemas:

1. **Logs de n8n:**
   ```bash
   docker-compose logs n8n | tail -100
   ```

2. **Logs de Traefik:**
   ```bash
   docker-compose logs traefik | tail -100
   ```

3. **Verificar conectividad:**
   ```bash
   curl http://localhost:5678
   curl https://n8n.ocaihealth.com
   ```

4. **Estado de contenedores:**
   ```bash
   docker-compose ps
   docker stats --no-stream
   ```
