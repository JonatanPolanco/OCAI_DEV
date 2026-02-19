# Lista de Verificación: Migración OCAI de GCP a AWS

## Pre-requisitos
- [ ] Cuenta AWS con permisos de administrador
- [ ] AWS CLI instalado (opcional pero recomendado)
- [ ] PostgreSQL client (psql) instalado localmente
- [ ] Git Bash o terminal con soporte SSH/SCP (Windows)
- [ ] Acceso al dominio ocaihealth.com (para actualizar DNS)

## Fase 1: Configuración de RDS PostgreSQL

### 1.1 Crear Security Group para RDS
- [ ] Security Group creado: `ocai-rds-sg`
- [ ] Inbound: PostgreSQL (5432) desde Mi IP
- [ ] Inbound: PostgreSQL (5432) desde EC2 Security Group (agregar después)
- [ ] SG ID guardado: `sg-________________`

### 1.2 Crear Instancia RDS
- [ ] Instancia RDS creada: `ocai-medical-db`
- [ ] Engine: PostgreSQL 14+
- [ ] Instance class: `db.t3.micro` o `db.t3.small`
- [ ] Storage: 20 GB gp3
- [ ] Initial database name: `n8n_db` ⚠️ CRÍTICO
- [ ] Public access: No (recomendado)
- [ ] Security Group: `ocai-rds-sg` asignado
- [ ] Backup automático habilitado
- [ ] Encryption habilitado

### 1.3 Guardar Credenciales RDS
- [ ] Endpoint guardado: `________________________________.rds.amazonaws.com`
- [ ] Puerto: `5432`
- [ ] Usuario: `__________________`
- [ ] Contraseña: `__________________` (en archivo seguro)
- [ ] Database: `n8n_db`

### 1.4 Verificar Conexión a RDS
- [ ] Conexión exitosa desde local: `psql -h <endpoint> -U postgres -d n8n_db`
- [ ] Query de prueba ejecutada: `SELECT 1;`

### 1.5 Ejecutar Scripts SQL
- [ ] Script ejecutado: `pipelines/ddl.sql`
- [ ] Script ejecutado: `pipelines/clinic_onboarding.sql`
- [ ] Script ejecutado: `pipelines/clinic_onboarding_sp.sql`
- [ ] Script ejecutado: `pipelines/clinic_onboarding_trigger.sql`
- [ ] (Opcional) Datos de prueba: `insert_test_data.sql`

### 1.6 Verificar Instalación DB
- [ ] Esquema `medical` creado
- [ ] Tablas verificadas: `\dt medical.*` (mínimo 15 tablas)
- [ ] Stored procedure `mvp_create_patient_appointment_evaluation` existe
- [ ] Stored procedure `process_clinic_onboarding` existe
- [ ] Trigger `trg_run_onboarding` existe

**Completado:** ☐ Fase 1

---

## Fase 2: Configuración de EC2 para n8n

### 2.1 Crear Security Group para EC2
- [ ] Security Group creado: `ocai-n8n-sg`
- [ ] Inbound: HTTP (80) desde Anywhere
- [ ] Inbound: HTTPS (443) desde Anywhere
- [ ] Inbound: SSH (22) desde Mi IP
- [ ] SG ID guardado: `sg-________________`

### 2.2 Actualizar Security Group de RDS
- [ ] RDS SG actualizado con regla: PostgreSQL (5432) desde `ocai-n8n-sg`

### 2.3 Asignar Elastic IP
- [ ] Elastic IP asignada: `________________`
- [ ] Elastic IP guardada para DNS

### 2.4 Crear/Verificar Key Pair
- [ ] Key Pair existe: `ocai-key-pair-aws` (o usar `ocai-key-pair`)
- [ ] Archivo .pem descargado y guardado
- [ ] Permisos configurados: `chmod 400 <key>.pem`

### 2.5 Lanzar Instancia EC2
- [ ] Instancia creada: `ocai-n8n-server`
- [ ] AMI: Ubuntu 22.04 LTS
- [ ] Instance type: `t3.small` (o `t3.medium`)
- [ ] Storage: 30 GB gp3
- [ ] VPC: Misma VPC que RDS
- [ ] Subnet: Pública (con internet access)
- [ ] Security Group: `ocai-n8n-sg` asignado
- [ ] Key Pair: Asignado
- [ ] Instance ID: `i-________________`

### 2.6 Asociar Elastic IP a EC2
- [ ] Elastic IP asociada a instancia `ocai-n8n-server`

### 2.7 Conectar via SSH
- [ ] Conexión SSH exitosa: `ssh -i <key>.pem ubuntu@<elastic-ip>`
- [ ] Prompt visible: `ubuntu@ip-172-31-x-x:~$`

### 2.8 Instalar Docker y Docker Compose
- [ ] Sistema actualizado: `sudo apt update && sudo apt upgrade -y`
- [ ] Docker instalado: `docker --version`
- [ ] Docker Compose instalado: `docker-compose --version`
- [ ] Usuario agregado a grupo docker: `groups` (debe incluir "docker")
- [ ] Docker corriendo sin sudo: `docker ps` (sin error)

### 2.9 Crear Estructura de Directorios
- [ ] Directorio creado: `~/n8n`
- [ ] Directorio creado: `~/n8n/local-files`

### 2.10 Transferir Archivos de Configuración
- [ ] Archivo transferido: `docker-compose.yml`
- [ ] Archivo transferido: `.env`
- [ ] Archivo creado: `acme.json` con permisos 600

### 2.11 Iniciar Docker Compose
- [ ] Comando ejecutado: `docker-compose up -d`
- [ ] Contenedor n8n corriendo: `docker ps` (ver `n8n`)
- [ ] Contenedor traefik corriendo: `docker ps` (ver `traefik`)
- [ ] Logs sin errores críticos: `docker-compose logs`

### 2.12 Verificar Acceso Temporal
- [ ] Acceso HTTP funciona: `http://<elastic-ip>` O
- [ ] /etc/hosts configurado: `<elastic-ip> n8n.ocaihealth.com`
- [ ] n8n UI visible (pantalla de login o setup)

**Completado:** ☐ Fase 2

---

## Fase 3: Configuración de DNS

### 3.1 Obtener Información
- [ ] Elastic IP confirmada: `________________`
- [ ] Proveedor DNS identificado: ________________ (GoDaddy/Cloudflare/Route53)

### 3.2 Actualizar DNS
- [ ] Localizado registro A para `n8n.ocaihealth.com`
- [ ] TTL reducido a 300 segundos (antes del cambio)
- [ ] Registro A actualizado con nueva Elastic IP
- [ ] Cambio guardado en proveedor DNS

### 3.3 Verificar Propagación DNS
- [ ] DNS propagado localmente: `nslookup n8n.ocaihealth.com`
- [ ] DNS propagado globalmente: Usar https://dnschecker.org
- [ ] IP correcta retornada

### 3.4 Verificar SSL Let's Encrypt
- [ ] Acceso HTTPS funciona: `https://n8n.ocaihealth.com`
- [ ] Certificado SSL válido (candado verde en navegador)
- [ ] Logs de Traefik muestran certificado obtenido: `docker-compose logs traefik | grep certificate`

**Completado:** ☐ Fase 3

---

## Fase 4: Configuración de n8n

### 4.1 Acceder a n8n
- [ ] Acceso exitoso: `https://n8n.ocaihealth.com`
- [ ] Usuario/contraseña configurado (si es primera vez)

### 4.2 Crear Credenciales PostgreSQL
- [ ] Credencial creada en n8n: "sql cloud" (o nombre similar)
- [ ] Host: RDS endpoint configurado
- [ ] Database: `n8n_db`
- [ ] User: Usuario RDS
- [ ] Password: Contraseña RDS
- [ ] Port: `5432`
- [ ] SSL: Enabled
- [ ] Conexión probada exitosamente

### 4.3 Crear Otras Credenciales
- [ ] Google Sheets OAuth2 (si aplica)
- [ ] Anthropic/OpenAI API keys (si aplica)
- [ ] Vapi.ai credentials (si aplica)
- [ ] Twilio credentials (si aplica)
- [ ] Otras APIs necesarias

### 4.4 Importar Workflows Principales
- [ ] Importado: `Master.json`
- [ ] Importado: `Master_dev.json`
- [ ] Importado: `master_dev_voice.json`

### 4.5 Importar Workflows de Citas
- [ ] Importado: `appointment_agent.json`
- [ ] Importado: `appointment_agent_dev.json`
- [ ] Importado: `appointment_agent_test.json`
- [ ] Importado: `appointment_mcp_agent.json`

### 4.6 Importar Workflows de Datos
- [ ] Importado: `data_storage_master.json`
- [ ] Importado: `crm_workflow.json`

### 4.7 Importar Workflows Auxiliares
- [ ] Importado: `calendar_mcp.json`
- [ ] Importado: `calculate_avaliable_slots.json`
- [ ] Importado: `mcp_server.json`

### 4.8 Actualizar Conexiones en Workflows
- [ ] Workflow actualizado: `data_storage_master.json` (conexión PostgreSQL)
- [ ] Workflow actualizado: `crm_workflow.json` (conexión PostgreSQL)
- [ ] Otros workflows con DB actualizados

### 4.9 Activar Workflows
- [ ] Workflows necesarios activados (switch ON)
- [ ] Workflows de prueba desactivados (si no se usan)

**Completado:** ☐ Fase 4

---

## Fase 5: Pruebas End-to-End

### 5.1 Pruebas de Base de Datos
- [ ] Conexión directa a RDS funciona
- [ ] Stored procedure `mvp_create_patient_appointment_evaluation` ejecutado exitosamente
- [ ] Datos insertados en tabla `patient`
- [ ] Datos insertados en tabla `appointment`
- [ ] No hay errores en queries

### 5.2 Pruebas de n8n Workflows
- [ ] Workflow de prueba ejecutado manualmente
- [ ] Workflow se conecta a RDS exitosamente
- [ ] Workflow inserta datos en base de datos
- [ ] Logs sin errores

### 5.3 Pruebas de Integración CRM
- [ ] Workflow `crm_workflow.json` ejecutado
- [ ] Conexión a Google Sheets funciona
- [ ] Lectura de datos desde Google Sheets exitosa
- [ ] Inserción en PostgreSQL desde Google Sheets funciona

### 5.4 Pruebas de Onboarding
- [ ] Fila insertada en Google Sheets (tabla clinic)
- [ ] Workflow detecta nueva fila
- [ ] Datos insertados en `clinic_onboarding` con status 'Ready'
- [ ] Trigger ejecuta stored procedure automáticamente
- [ ] Clínica creada en tabla `clinic`
- [ ] Doctores creados en tabla `doctor`
- [ ] Status cambia a 'Completed'

### 5.5 Pruebas de Flujo Completo
- [ ] Flujo end-to-end de cita médica funciona
- [ ] Agente de IA puede agendar citas (si aplica)
- [ ] Datos persisten correctamente en base de datos
- [ ] No hay race conditions ni deadlocks

**Completado:** ☐ Fase 5

---

## Fase 6: Migración de Cloud Functions (Opcional)

### Opción Seleccionada:
- [ ] Opción A: AWS Lambda
- [ ] Opción B: Endpoint en EC2
- [ ] Opción C: Integración en n8n
- [ ] No migrar (no se usa actualmente)

### Si se seleccionó Lambda:
- [ ] Lambda function creada
- [ ] Código subido: `appointment-service-store.py`
- [ ] Layer de dependencias configurado
- [ ] Variables de entorno configuradas
- [ ] VPC configurado para acceso a RDS
- [ ] API Gateway endpoint creado
- [ ] Endpoint probado exitosamente

### Si se seleccionó EC2:
- [ ] Python y dependencias instalados en EC2
- [ ] Flask app configurada
- [ ] Gunicorn/uWSGI configurado
- [ ] Nginx/Traefik reverse proxy configurado
- [ ] Endpoint expuesto públicamente
- [ ] Endpoint probado exitosamente

### Si se seleccionó n8n:
- [ ] Workflow webhook creado
- [ ] Lógica de validación implementada
- [ ] Nodo PostgreSQL configurado
- [ ] Respuesta JSON configurada
- [ ] Endpoint probado exitosamente

### Actualización de URLs
- [ ] URLs de webhooks actualizadas en workflows
- [ ] URLs actualizadas en configuración de agente IA
- [ ] URLs de Cloud Functions GCP reemplazadas
- [ ] URLs probadas

**Completado:** ☐ Fase 6

---

## Fase 7: Documentación

### 7.1 Crear Documentación de Migración
- [ ] Archivo creado: `AWS_MIGRATION_NOTES.md`
- [ ] RDS endpoint documentado
- [ ] EC2 IP documentado
- [ ] Security groups documentados
- [ ] Workflows migrados listados
- [ ] Endpoints actualizados documentados

### 7.2 Actualizar README.md
- [ ] Sección "Infraestructura AWS" agregada
- [ ] Información de RDS actualizada
- [ ] Información de EC2 actualizada
- [ ] Información de conexión actualizada

### 7.3 Actualizar Configuración Local
- [ ] Archivo `pipelines/.env` actualizado con credenciales RDS
- [ ] Archivos de credenciales locales actualizados
- [ ] `.gitignore` actualizado con entradas de seguridad
- [ ] Credenciales NO commiteadas a Git

### 7.4 Backups y Seguridad
- [ ] Backups automáticos configurados en RDS
- [ ] CloudWatch monitoring configurado (opcional)
- [ ] Alertas configuradas (opcional)
- [ ] Passwords rotados si es necesario

**Completado:** ☐ Fase 7

---

## Fase 8: Post-Migración

### 8.1 Verificación Final
- [ ] Sistema funcionando en producción
- [ ] Todos los workflows activos funcionan
- [ ] Monitoreo sin errores críticos
- [ ] Performance aceptable

### 8.2 Limpieza
- [ ] Recursos de GCP desactivados (si se tiene acceso)
- [ ] Archivos temporales eliminados
- [ ] Credenciales antiguas revocadas

### 8.3 Capacitación
- [ ] Equipo capacitado en nueva infraestructura AWS
- [ ] Documentación de operación creada
- [ ] Procedimientos de troubleshooting documentados

**Completado:** ☐ Fase 8

---

## Costos Estimados (Mensual)

| Servicio | Configuración | Costo Estimado |
|----------|---------------|----------------|
| RDS PostgreSQL | db.t3.micro | $15-20 |
| EC2 | t3.small | $15-20 |
| Storage | 50 GB | $5 |
| Elastic IP | (gratis si está asociada) | $0 |
| Transfer | Estimado | $5 |
| **Total** | | **$40-50/mes** |

---

## Contactos de Emergencia

- [ ] Admin AWS: ____________________
- [ ] DNS Provider: ____________________
- [ ] Soporte técnico: ____________________

---

## Rollback Plan (Si algo falla)

### RDS con problemas:
1. Tomar snapshot de RDS
2. Restaurar desde snapshot o
3. Recrear RDS y re-ejecutar scripts

### EC2 con problemas:
1. Terminar instancia
2. Lanzar nueva instancia
3. Repetir configuración

### DNS mal configurado:
1. Revertir registro A al valor anterior
2. Esperar propagación

### Workflows no funcionan:
1. Revisar logs: `docker-compose logs`
2. Verificar credenciales en n8n UI
3. Reimportar workflows desde JSON

---

**Fecha de inicio:** ____/____/______
**Fecha de finalización:** ____/____/______
**Migrado por:** ______________________
**Verificado por:** ______________________

---

## Notas Adicionales

[Espacio para notas, problemas encontrados, soluciones aplicadas, etc.]
