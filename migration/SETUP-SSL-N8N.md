# Configurar SSL para n8n.ocaihealth.com

Guía para configurar certificado SSL gratuito con Let's Encrypt en tu servidor n8n.

## Prerequisitos

- ✅ EC2 corriendo con n8n
- ✅ Elastic IP asignada a EC2
- ✅ Dominio `n8n.ocaihealth.com` registrado
- ✅ Security Group permite puertos 80 y 443

## Método 1: SSL con Traefik (Recomendado - Automático)

Si ya tienes Traefik configurado en tu docker-compose.yml, Let's Encrypt se configurará automáticamente.

### Paso 1: Configurar DNS

1. **Ve a tu proveedor de dominio** (GoDaddy, Route 53, Cloudflare, etc.)
2. **Crear registro A**:
   ```
   Type: A
   Name: n8n
   Value: <tu-elastic-ip>
   TTL: 300 (5 minutos)
   ```

3. **Verificar DNS** (esperar 5-15 minutos):
   ```bash
   # Desde tu computadora local
   nslookup n8n.ocaihealth.com

   # Debería retornar tu Elastic IP
   ```

### Paso 2: Verificar docker-compose.yml

Conectar a EC2:
```bash
ssh -i ocai-key-pair-aws.pem ubuntu@<elastic-ip>
cd ~/n8n
```

Verificar que docker-compose.yml tiene configuración de Traefik:

```bash
cat docker-compose.yml | grep -A 10 traefik
```

Debe contener algo como:
```yaml
traefik:
  image: traefik:latest
  command:
    - "--api.insecure=true"
    - "--providers.docker=true"
    - "--entrypoints.web.address=:80"
    - "--entrypoints.websecure.address=:443"
    - "--certificatesresolvers.letsencrypt.acme.email=your-email@ocaihealth.com"
    - "--certificatesresolvers.letsencrypt.acme.storage=/acme.json"
    - "--certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web"
```

### Paso 3: Actualizar docker-compose.yml (Si es necesario)

Si no tienes Traefik configurado, crear/actualizar el archivo:

```bash
cd ~/n8n
nano docker-compose.yml
```

Contenido completo:

```yaml
version: '3.8'

services:
  traefik:
    image: traefik:v2.10
    container_name: traefik
    restart: unless-stopped
    command:
      # API y Dashboard
      - "--api.insecure=true"
      - "--api.dashboard=true"

      # Providers
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"

      # Entrypoints
      - "--entrypoints.web.address=:80"
      - "--entrypoints.websecure.address=:443"

      # Redirect HTTP to HTTPS
      - "--entrypoints.web.http.redirections.entrypoint.to=websecure"
      - "--entrypoints.web.http.redirections.entrypoint.scheme=https"

      # Let's Encrypt
      - "--certificatesresolvers.letsencrypt.acme.email=admin@ocaihealth.com"
      - "--certificatesresolvers.letsencrypt.acme.storage=/acme.json"
      - "--certificatesresolvers.letsencrypt.acme.httpchallenge=true"
      - "--certificatesresolvers.letsencrypt.acme.httpchallenge.entrypoint=web"

      # Logging
      - "--log.level=INFO"
      - "--accesslog=true"

    ports:
      - "80:80"
      - "443:443"
      - "8080:8080"  # Dashboard (opcional, comentar en producción)

    volumes:
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./acme.json:/acme.json

    networks:
      - n8n-network

  n8n:
    image: n8nio/n8n:latest
    container_name: n8n
    restart: unless-stopped
    environment:
      - N8N_HOST=n8n.ocaihealth.com
      - N8N_PROTOCOL=https
      - N8N_PORT=5678
      - WEBHOOK_URL=https://n8n.ocaihealth.com/
      - GENERIC_TIMEZONE=America/Bogota

      # Database
      - DB_TYPE=postgresdb
      - DB_POSTGRESDB_HOST=${DB_HOST}
      - DB_POSTGRESDB_PORT=${DB_PORT}
      - DB_POSTGRESDB_DATABASE=${DB_NAME}
      - DB_POSTGRESDB_USER=${DB_USER}
      - DB_POSTGRESDB_PASSWORD=${DB_PASSWORD}

      # Security
      - N8N_BASIC_AUTH_ACTIVE=true
      - N8N_BASIC_AUTH_USER=${N8N_USER}
      - N8N_BASIC_AUTH_PASSWORD=${N8N_PASSWORD}

    volumes:
      - n8n_data:/home/node/.n8n
      - ./local-files:/files

    labels:
      - "traefik.enable=true"

      # HTTP
      - "traefik.http.routers.n8n.rule=Host(`n8n.ocaihealth.com`)"
      - "traefik.http.routers.n8n.entrypoints=websecure"
      - "traefik.http.routers.n8n.tls=true"
      - "traefik.http.routers.n8n.tls.certresolver=letsencrypt"

      # Service
      - "traefik.http.services.n8n.loadbalancer.server.port=5678"

    networks:
      - n8n-network

    depends_on:
      - traefik

volumes:
  n8n_data:

networks:
  n8n-network:
    driver: bridge
```

Guardar: `Ctrl+X`, `Y`, `Enter`

### Paso 4: Crear archivo .env

```bash
cd ~/n8n
nano .env
```

Contenido:
```bash
# RDS Database
DB_HOST=ocai-medical-db.copmy0ewmif4.us-east-1.rds.amazonaws.com
DB_PORT=5432
DB_NAME=n8n_db
DB_USER=postgres
DB_PASSWORD=<tu-password-rds>

# n8n Authentication
N8N_USER=admin
N8N_PASSWORD=<tu-password-n8n>
```

Guardar: `Ctrl+X`, `Y`, `Enter`

### Paso 5: Crear acme.json

```bash
cd ~/n8n
touch acme.json
chmod 600 acme.json
ls -la acme.json
```

Debe mostrar: `-rw------- 1 ubuntu ubuntu 0 ... acme.json`

### Paso 6: Reiniciar servicios

```bash
cd ~/n8n

# Detener contenedores actuales
docker-compose down

# Iniciar con nueva configuración
docker-compose up -d

# Ver logs en tiempo real
docker-compose logs -f
```

### Paso 7: Verificar obtención de certificado

Buscar en los logs:
```bash
docker-compose logs traefik | grep -i certificate
```

Deberías ver:
```
time="..." level=info msg="Trying to challenge from ..." domain=n8n.ocaihealth.com
time="..." level=info msg="The key type is ..." domain=n8n.ocaihealth.com
time="..." level=info msg="Certificates obtained for domain" domain=n8n.ocaihealth.com
```

**Nota:** Puede tomar 1-2 minutos la primera vez.

### Paso 8: Verificar SSL en navegador

1. Abre tu navegador
2. Ve a: `https://n8n.ocaihealth.com`
3. Verifica que:
   - ✅ Muestra candado verde en la barra de direcciones
   - ✅ Certificado emitido por "Let's Encrypt"
   - ✅ No hay advertencias de seguridad

### Paso 9: Verificar renovación automática

Traefik renueva certificados automáticamente 30 días antes de expirar.

Para verificar el certificado almacenado:
```bash
cat ~/n8n/acme.json
```

Debe tener contenido JSON con el certificado.

## Método 2: SSL con Nginx + Certbot (Manual)

Si no quieres usar Traefik, puedes usar Nginx tradicional.

### Paso 1: Instalar Nginx y Certbot

```bash
sudo apt update
sudo apt install -y nginx certbot python3-certbot-nginx
```

### Paso 2: Configurar Nginx

```bash
sudo nano /etc/nginx/sites-available/n8n.ocaihealth.com
```

Contenido:
```nginx
server {
    listen 80;
    server_name n8n.ocaihealth.com;

    # Redirect HTTP to HTTPS
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name n8n.ocaihealth.com;

    # SSL certificates (Certbot lo llenará automáticamente)
    # ssl_certificate /etc/letsencrypt/live/n8n.ocaihealth.com/fullchain.pem;
    # ssl_certificate_key /etc/letsencrypt/live/n8n.ocaihealth.com/privkey.pem;

    # SSL configuration
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_ciphers HIGH:!aNULL:!MD5;
    ssl_prefer_server_ciphers on;

    # Proxy settings
    location / {
        proxy_pass http://localhost:5678;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;

        # WebSocket support
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
    }

    # Increase timeout for long-running workflows
    proxy_connect_timeout 300s;
    proxy_send_timeout 300s;
    proxy_read_timeout 300s;
}
```

### Paso 3: Habilitar sitio

```bash
sudo ln -s /etc/nginx/sites-available/n8n.ocaihealth.com /etc/nginx/sites-enabled/
sudo nginx -t
sudo systemctl restart nginx
```

### Paso 4: Obtener certificado SSL

```bash
sudo certbot --nginx -d n8n.ocaihealth.com --non-interactive --agree-tos --email admin@ocaihealth.com
```

### Paso 5: Verificar renovación automática

```bash
# Certbot crea un cron job automáticamente
sudo systemctl status certbot.timer

# Probar renovación (dry run)
sudo certbot renew --dry-run
```

## Troubleshooting

### Error: "acme: error: 403 :: urn:ietf:params:acme:error:unauthorized"

**Causa:** DNS no apunta correctamente o firewall bloqueando puerto 80.

**Solución:**
1. Verificar DNS: `nslookup n8n.ocaihealth.com`
2. Verificar Security Group permite puerto 80 desde `0.0.0.0/0`
3. Verificar que Traefik está escuchando en puerto 80: `docker ps`

### Error: "timeout during connect"

**Causa:** EC2 Security Group no permite tráfico HTTP/HTTPS.

**Solución:**
1. Ir a EC2 → Security Groups
2. Seleccionar `ocai-n8n-sg`
3. Verificar Inbound rules:
   - Port 80: 0.0.0.0/0
   - Port 443: 0.0.0.0/0

### Certificado no se renueva automáticamente

**Para Traefik:**
- Verificar que `acme.json` tiene permisos 600
- Verificar logs: `docker-compose logs traefik | grep renew`

**Para Certbot:**
```bash
sudo systemctl status certbot.timer
sudo certbot renew --dry-run
```

### Navegador muestra "Connection not secure"

**Causas posibles:**
1. DNS aún no propagado (esperar 15 minutos)
2. Certificado no obtenido exitosamente (verificar logs)
3. Puerto 443 bloqueado (verificar Security Group)

### Error: "too many certificates already issued"

**Causa:** Let's Encrypt tiene límite de 5 certificados por dominio por semana.

**Solución:**
- Usar staging para pruebas: agregar `--certificatesresolvers.letsencrypt.acme.caserver=https://acme-staging-v02.api.letsencrypt.org/directory`
- Esperar 7 días para reintentar

## Verificación Final

Comandos para verificar todo está funcionando:

```bash
# 1. DNS apunta correctamente
nslookup n8n.ocaihealth.com

# 2. Puerto 443 accesible
telnet n8n.ocaihealth.com 443

# 3. Certificado SSL válido
openssl s_client -connect n8n.ocaihealth.com:443 -servername n8n.ocaihealth.com

# 4. Contenedores corriendo
docker ps

# 5. Logs sin errores
docker-compose logs traefik | tail -50
docker-compose logs n8n | tail -50
```

## Próximos Pasos

Una vez que SSL funciona:
- [ ] Acceder a https://n8n.ocaihealth.com
- [ ] Crear primer workflow
- [ ] Configurar credenciales de RDS en n8n
- [ ] Importar workflows existentes
- [ ] Configurar webhooks con URL HTTPS

## Información de Certificado

El certificado Let's Encrypt:
- ✅ Válido por 90 días
- ✅ Renovación automática cada 60 días
- ✅ Gratuito e ilimitado
- ✅ Reconocido por todos los navegadores
- ✅ Nivel de encriptación: TLS 1.2/1.3
