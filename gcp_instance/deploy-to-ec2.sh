#!/bin/bash
# Script para deployar n8n con SSL a EC2
set -e

# Configuración
KEY_PATH="${1:-ocai-key-pair-aws.pem}"
EC2_IP="${2}"
EC2_USER="ubuntu"

if [ -z "$EC2_IP" ]; then
    echo "❌ Error: Debes proporcionar la IP del servidor EC2"
    echo "Uso: $0 <path-to-key.pem> <ec2-ip>"
    echo "Ejemplo: $0 ocai-key-pair-aws.pem 54.123.45.67"
    exit 1
fi

if [ ! -f "$KEY_PATH" ]; then
    echo "❌ Error: No se encuentra el archivo de llave: $KEY_PATH"
    exit 1
fi

echo "=== Deploying n8n to EC2 ==="
echo "EC2 IP: $EC2_IP"
echo "Key: $KEY_PATH"
echo ""

# Verificar conexión SSH
echo "[1/7] Verificando conexión SSH..."
if ssh -i "$KEY_PATH" -o ConnectTimeout=10 -o StrictHostKeyChecking=no $EC2_USER@$EC2_IP "echo '✓ Conexión exitosa'" 2>/dev/null; then
    echo "✓ SSH funciona correctamente"
else
    echo "❌ Error: No se puede conectar a EC2"
    echo "Verifica:"
    echo "  - La IP es correcta"
    echo "  - El archivo .pem tiene permisos 400"
    echo "  - El Security Group permite SSH desde tu IP"
    exit 1
fi

# Crear directorio en EC2
echo "[2/7] Creando directorio en EC2..."
ssh -i "$KEY_PATH" $EC2_USER@$EC2_IP "mkdir -p ~/n8n/local-files"
echo "✓ Directorio creado"

# Transferir archivos
echo "[3/7] Transfiriendo archivos..."
scp -i "$KEY_PATH" docker-compose.yml $EC2_USER@$EC2_IP:~/n8n/
scp -i "$KEY_PATH" .env $EC2_USER@$EC2_IP:~/n8n/
echo "✓ Archivos transferidos"

# Crear acme.json
echo "[4/7] Creando acme.json..."
ssh -i "$KEY_PATH" $EC2_USER@$EC2_IP "cd ~/n8n && touch acme.json && chmod 600 acme.json"
echo "✓ acme.json creado con permisos correctos"

# Verificar Docker instalado
echo "[5/7] Verificando Docker..."
if ssh -i "$KEY_PATH" $EC2_USER@$EC2_IP "docker --version" 2>/dev/null; then
    echo "✓ Docker ya instalado"
else
    echo "⚠️  Docker no encontrado, instalando..."
    ssh -i "$KEY_PATH" $EC2_USER@$EC2_IP "sudo apt update && sudo apt install -y docker.io docker-compose && sudo usermod -aG docker ubuntu"
    echo "✓ Docker instalado (necesitas reconectar SSH después)"
fi

# Iniciar servicios
echo "[6/7] Iniciando servicios Docker..."
ssh -i "$KEY_PATH" $EC2_USER@$EC2_IP "cd ~/n8n && docker-compose pull && docker-compose up -d"
echo "✓ Servicios iniciados"

# Verificar estado
echo "[7/7] Verificando estado..."
sleep 3
ssh -i "$KEY_PATH" $EC2_USER@$EC2_IP "cd ~/n8n && docker-compose ps"

echo ""
echo "=== ✓ Deployment completado ==="
echo ""
echo "Próximos pasos:"
echo ""
echo "1. Configurar DNS:"
echo "   - Tipo: A"
echo "   - Nombre: n8n"
echo "   - Valor: $EC2_IP"
echo ""
echo "2. Esperar propagación DNS (5-15 minutos)"
echo ""
echo "3. Verificar certificado SSL:"
echo "   ssh -i $KEY_PATH $EC2_USER@$EC2_IP 'cd ~/n8n && docker-compose logs traefik | grep certificate'"
echo ""
echo "4. Acceder a n8n:"
echo "   https://n8n.ocaihealth.com"
echo ""
echo "Ver logs en tiempo real:"
echo "   ssh -i $KEY_PATH $EC2_USER@$EC2_IP 'cd ~/n8n && docker-compose logs -f'"
