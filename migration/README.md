# Migración OCAI Medical: GCP → AWS

Esta carpeta contiene todos los archivos necesarios para migrar el sistema OCAI Medical de Google Cloud Platform a Amazon Web Services.

## Contenido de la Carpeta

### Guías Paso a Paso

1. **[AWS-RDS-SETUP-GUIDE.md](AWS-RDS-SETUP-GUIDE.md)**
   - Guía completa para crear RDS PostgreSQL
   - Configuración de Security Groups
   - Aplicación de scripts SQL
   - Verificación de instalación
   - **⏱️ Tiempo estimado:** 30-45 minutos

2. **[AWS-EC2-SETUP-GUIDE.md](AWS-EC2-SETUP-GUIDE.md)**
   - Guía completa para crear instancia EC2
   - Instalación de Docker y Docker Compose
   - Configuración de n8n con Traefik
   - Configuración de SSL con Let's Encrypt
   - **⏱️ Tiempo estimado:** 45-60 minutos

3. **[MIGRATION-CHECKLIST.md](MIGRATION-CHECKLIST.md)**
   - Lista de verificación exhaustiva
   - 8 fases con checkboxes
   - Verificación de cada paso
   - Información de contactos y costos
   - **Usar esta lista durante la migración**

### Scripts de Automatización

1. **[1-setup-rds.sh](1-setup-rds.sh)**
   - Aplica todos los scripts SQL en orden correcto
   - Verifica conexión a RDS
   - Crea esquema, tablas, stored procedures y triggers
   - Muestra logs de progreso con colores

   **Uso:**
   ```bash
   chmod +x 1-setup-rds.sh
   ./1-setup-rds.sh <rds-endpoint> <username> n8n_db
   ```

2. **[2-verify-rds.sh](2-verify-rds.sh)**
   - Verifica que RDS está configurado correctamente
   - Valida esquema, tablas, stored procedures y triggers
   - Prueba el stored procedure MVP
   - Muestra resumen de base de datos

   **Uso:**
   ```bash
   chmod +x 2-verify-rds.sh
   ./2-verify-rds.sh <rds-endpoint> <username> n8n_db
   ```

## Orden de Ejecución Recomendado

### Fase 1: RDS PostgreSQL (30-45 min)
1. Leer **AWS-RDS-SETUP-GUIDE.md**
2. Crear RDS en AWS Console siguiendo la guía
3. Guardar endpoint y credenciales de RDS
4. Ejecutar `./1-setup-rds.sh <endpoint> <user> n8n_db`
5. Verificar con `./2-verify-rds.sh <endpoint> <user> n8n_db`
6. ✅ Marcar Fase 1 en **MIGRATION-CHECKLIST.md**

### Fase 2: EC2 para n8n (45-60 min)
1. Leer **AWS-EC2-SETUP-GUIDE.md**
2. Crear instancia EC2 en AWS Console
3. Instalar Docker y Docker Compose
4. Transferir archivos de configuración
5. Iniciar Docker Compose
6. ✅ Marcar Fase 2 en **MIGRATION-CHECKLIST.md**

### Fase 3: DNS y SSL (15-30 min)
1. Actualizar registro DNS A para n8n.ocaihealth.com
2. Apuntar a Elastic IP de EC2
3. Esperar propagación de DNS
4. Verificar SSL Let's Encrypt
5. ✅ Marcar Fase 3 en **MIGRATION-CHECKLIST.md**

### Fase 4: n8n Workflows (30-60 min)
1. Acceder a n8n UI
2. Crear credenciales de PostgreSQL
3. Importar workflows desde `n8n_workflows/`
4. Actualizar conexiones en workflows
5. Activar workflows necesarios
6. ✅ Marcar Fase 4 en **MIGRATION-CHECKLIST.md**

### Fase 5: Pruebas (30-45 min)
1. Probar stored procedures en RDS
2. Ejecutar workflows de prueba en n8n
3. Probar integración CRM con Google Sheets
4. Probar flujo completo de onboarding
5. ✅ Marcar Fase 5 en **MIGRATION-CHECKLIST.md**

## Pre-requisitos

### Software Necesario
- [ ] PostgreSQL client (`psql`)
  - Ubuntu/Debian: `sudo apt-get install postgresql-client`
  - MacOS: `brew install postgresql`
  - Windows: Descargar desde [postgresql.org](https://www.postgresql.org/download/)
- [ ] SSH client (OpenSSH, PuTTY, o Git Bash)
- [ ] SCP o WinSCP para transferencia de archivos

### Acceso y Permisos
- [ ] Cuenta AWS con permisos de administrador
- [ ] Acceso al dominio ocaihealth.com (para actualizar DNS)
- [ ] Credenciales de Google Sheets (OAuth2) si aplica

### Archivos del Proyecto
- [ ] `pipelines/ddl.sql`
- [ ] `pipelines/clinic_onboarding.sql`
- [ ] `pipelines/clinic_onboarding_sp.sql`
- [ ] `pipelines/clinic_onboarding_trigger.sql`
- [ ] `gcp_instance/docker-compose.yml`
- [ ] `gcp_instance/.env`
- [ ] `n8n_workflows/*.json` (11 archivos)
- [ ] Key pair `.pem` (para SSH)

## Estructura de Archivos SQL

Los scripts SQL deben ejecutarse en este orden:

```
pipelines/
├── 1. ddl.sql                      # Esquema, tablas, stored procedures base
├── 2. clinic_onboarding.sql        # Tabla staging para onboarding
├── 3. clinic_onboarding_sp.sql     # Stored procedure de onboarding
└── 4. clinic_onboarding_trigger.sql # Trigger automático
```

## Información de Conexión

### RDS PostgreSQL
Después de crear RDS, guardar:
```
Endpoint: xxxxxxxx.xxxxx.us-east-1.rds.amazonaws.com
Port: 5432
Database: n8n_db
Username: postgres (o personalizado)
Password: [tu-contraseña-segura]
```

### EC2 Instance
Después de crear EC2, guardar:
```
Instance ID: i-xxxxxxxxxxxxxxxxx
Public IP/Elastic IP: xx.xx.xx.xx
Security Group: sg-xxxxxxxxxxxxxxxxx
Key Pair: ocai-key-pair-aws.pem
```

### SSH Connection
```bash
ssh -i ocai-key-pair-aws.pem ubuntu@<elastic-ip>
```

### PostgreSQL Connection
```bash
psql -h <rds-endpoint> -U postgres -d n8n_db
```

## Troubleshooting Rápido

### No puedo conectar a RDS
- Verificar Security Group permite tu IP (puerto 5432)
- Verificar endpoint es correcto
- Verificar que RDS está en estado "Available"
- Usar `-h` con el endpoint completo, no solo el hostname

### No puedo conectar a EC2
- Verificar permisos del archivo .pem: `chmod 400 <key>.pem`
- Verificar Security Group permite tu IP (puerto 22)
- Verificar que estás usando `ubuntu@<ip>` (no `root@`)

### Docker no funciona en EC2
- Verificar que estás en grupo docker: `groups`
- Cerrar sesión y volver a conectar después de agregar al grupo
- Verificar que Docker está corriendo: `sudo systemctl status docker`

### n8n no inicia
- Verificar logs: `docker-compose logs n8n`
- Verificar archivo `.env` está presente
- Verificar permisos de `acme.json`: `chmod 600 acme.json`
- Verificar puertos 80 y 443 disponibles

### SSL no funciona
- Verificar DNS apunta a la IP correcta: `nslookup n8n.ocaihealth.com`
- Esperar propagación de DNS (puede tomar hasta 48h)
- Verificar logs de Traefik: `docker-compose logs traefik | grep acme`
- Verificar puerto 80 está abierto (Let's Encrypt usa HTTP challenge)

## Costos Estimados

| Servicio | Configuración | Costo/Mes (USD) |
|----------|---------------|-----------------|
| RDS PostgreSQL | db.t3.micro, 20GB | $15-20 |
| EC2 | t3.small, 30GB | $15-20 |
| Storage | EBS + RDS | $5 |
| Data Transfer | Estimado | $5 |
| Elastic IP | (gratis si asociada) | $0 |
| **Total** | | **$40-50** |

*Nota: Costos pueden variar según región y uso real.*

## Archivos de Seguridad

**⚠️ NUNCA commitear estos archivos:**
- `aws-credentials.txt` - Credenciales de RDS
- `*.pem` - Key pairs de SSH
- `.env` - Variables de entorno con passwords
- `migration/*.txt` - Notas con credenciales

**Verificar `.gitignore` antes de hacer commit.**

## Plan de Rollback

Si algo sale mal durante la migración:

### RDS con problemas
1. Tomar snapshot de RDS en AWS Console
2. Restaurar desde snapshot o recrear RDS
3. Re-ejecutar scripts SQL

### EC2 con problemas
1. Terminar instancia EC2
2. Crear nueva instancia siguiendo la guía
3. Repetir configuración Docker

### DNS mal configurado
1. Revertir registro A al valor anterior
2. Esperar propagación

## Soporte y Referencias

- **Plan completo:** `../PLAN.md` (si existe)
- **Documentación AWS RDS:** https://docs.aws.amazon.com/rds/
- **Documentación AWS EC2:** https://docs.aws.amazon.com/ec2/
- **Documentación n8n:** https://docs.n8n.io/
- **Documentación Docker:** https://docs.docker.com/

## Siguiente Paso

🚀 **Comenzar con:** [AWS-RDS-SETUP-GUIDE.md](AWS-RDS-SETUP-GUIDE.md)

📋 **Seguir progreso con:** [MIGRATION-CHECKLIST.md](MIGRATION-CHECKLIST.md)

---

**Última actualización:** Febrero 2026
**Versión:** 1.0
**Proyecto:** OCAI Medical System
