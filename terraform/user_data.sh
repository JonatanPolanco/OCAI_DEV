
#!/bin/bash
# User Data Script para EC2 Instance
# Este script se ejecuta automáticamente al iniciar la instancia

set -e

echo "========================================"
echo "Iniciando configuración de OCAI n8n Server"
echo "========================================"

# Variables pasadas desde Terraform
DB_HOST="${db_host}"
DB_PORT="${db_port}"
DB_NAME="${db_name}"
DB_USER="${db_user}"
DB_PASSWORD="${db_password}"
DOMAIN_NAME="${domain_name}"
SUBDOMAIN="${subdomain}"
SSL_EMAIL="${ssl_email}"

# Actualizar sistema
echo "[1/8] Actualizando sistema..."
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get upgrade -y

# Instalar Docker
echo "[2/8] Instalando Docker..."
apt-get install -y docker.io

# Instalar Docker Compose
echo "[3/8] Instalando Docker Compose..."
curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
chmod +x /usr/local/bin/docker-compose

# Configurar Docker
echo "[4/8] Configurando Docker..."
systemctl enable docker
systemctl start docker
usermod -aG docker ubuntu

# Crear estructura de directorios
echo "[5/8] Creando directorios..."
mkdir -p /home/ubuntu/n8n/local-files
cd /home/ubuntu/n8n

# Crear archivo .env
echo "[6/8] Creando archivo .env..."
cat > /home/ubuntu/n8n/.env <<EOF
DOMAIN_NAME=$DOMAIN_NAME
SUBDOMAIN=$SUBDOMAIN
GENERIC_TIMEZONE=America/Mexico_City
SSL_EMAIL=$SSL_EMAIL
EOF

# Crear docker-compose.yml
echo "[7/8] Creando docker-compose.yml..."
cat > /home/ubuntu/n8n/docker-compose.yml <<'EOF'
services:
  traefik:
    image: "traefik"
    restart: always
    command:
      - "--api=true"
      - "--api.insecure=true"
      - "--providers.docker=true"
      - "--providers.docker.exposedbydefault=false"
      - "--entrypoints.web.address=:80"
      - "--entrypoints.web.http.redirections.entryPoint.to=websecure"
      - "--entrypoints.web.http.redirections.entrypoint.scheme=https"
      - "--entrypoints.websecure.address=:443"
      - "--certificatesresolvers.mytlschallenge.acme.tlschallenge=true"
      - "--certificatesresolvers.mytlschallenge.acme.email=$${SSL_EMAIL}"
      - "--certificatesresolvers.mytlschallenge.acme.storage=/letsencrypt/acme.json"
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - traefik_data:/letsencrypt
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./acme.json:/letsencrypt/acme.json

  n8n:
    image: docker.n8n.io/n8nio/n8n
    restart: always
    ports:
      - "127.0.0.1:5678:5678"
    labels:
      - traefik.enable=true
      - traefik.http.routers.n8n.rule=Host(`$${SUBDOMAIN}.$${DOMAIN_NAME}`)
      - traefik.http.routers.n8n.tls=true
      - traefik.http.routers.n8n.entrypoints=web,websecure
      - traefik.http.routers.n8n.tls.certresolver=mytlschallenge
      - traefik.http.middlewares.n8n.headers.SSLRedirect=true
      - traefik.http.middlewares.n8n.headers.STSSeconds=315360000
      - traefik.http.middlewares.n8n.headers.browserXSSFilter=true
      - traefik.http.middlewares.n8n.headers.contentTypeNosniff=true
      - traefik.http.middlewares.n8n.headers.forceSTSHeader=true
      - traefik.http.middlewares.n8n.headers.SSLHost=$${DOMAIN_NAME}
      - traefik.http.middlewares.n8n.headers.STSIncludeSubdomains=true
      - traefik.http.middlewares.n8n.headers.STSPreload=true
      - traefik.http.routers.n8n.middlewares=n8n@docker
    environment:
      - N8N_HOST=$${SUBDOMAIN}.$${DOMAIN_NAME}
      - N8N_PORT=5678
      - N8N_PROTOCOL=https
      - NODE_ENV=production
      - WEBHOOK_URL=https://$${SUBDOMAIN}.$${DOMAIN_NAME}/
      - GENERIC_TIMEZONE=$${GENERIC_TIMEZONE}
    volumes:
      - n8n_data:/home/node/.n8n
      - ./local-files:/files

volumes:
  n8n_data:
  traefik_data:
EOF

# Crear acme.json
touch /home/ubuntu/n8n/acme.json
chmod 600 /home/ubuntu/n8n/acme.json

# Ajustar permisos
chown -R ubuntu:ubuntu /home/ubuntu/n8n

# Crear servicio systemd para Docker Compose
echo "[8/8] Creando servicio systemd..."
cat > /etc/systemd/system/n8n-docker.service <<EOF
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
EOF

# Habilitar y iniciar servicio
systemctl daemon-reload
systemctl enable n8n-docker.service
systemctl start n8n-docker.service

# Guardar información de conexión
cat > /home/ubuntu/n8n/connection-info.txt <<EOF
======================================
OCAI Medical - Connection Information
======================================

RDS PostgreSQL:
  Host: $DB_HOST
  Port: $DB_PORT
  Database: $DB_NAME
  Username: $DB_USER
  Password: [Guardado en variables de Terraform]

n8n:
  URL: https://$SUBDOMAIN.$DOMAIN_NAME
  Local Access: http://localhost:5678

Docker:
  Check status: docker ps
  View logs: docker-compose logs -f
  Restart: docker-compose restart

Created: $(date)
======================================
EOF

chown ubuntu:ubuntu /home/ubuntu/n8n/connection-info.txt

echo "========================================"
echo "Configuración completada!"
echo "n8n estará disponible en: https://$SUBDOMAIN.$DOMAIN_NAME"
echo "Información guardada en: /home/ubuntu/n8n/connection-info.txt"
echo "========================================"
