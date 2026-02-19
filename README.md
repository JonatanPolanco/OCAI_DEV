# OCAI Medical - AI-Powered Healthcare Appointment System

> Sistema inteligente de gestión de citas médicas con agente de WhatsApp y onboarding automatizado de clínicas.

[![AWS](https://img.shields.io/badge/AWS-Lambda%20%7C%20RDS%20%7C%20EC2-orange)](https://aws.amazon.com)
[![PostgreSQL](https://img.shields.io/badge/PostgreSQL-15+-blue)](https://www.postgresql.org/)
[![n8n](https://img.shields.io/badge/n8n-Workflow%20Automation-brightgreen)](https://n8n.io/)
[![Python](https://img.shields.io/badge/Python-3.11-yellow)](https://www.python.org/)

---

## 📋 Índice

- [Arquitectura](#-arquitectura)
- [Componentes](#-componentes)
- [Estructura del Proyecto](#-estructura-del-proyecto)
- [Quick Start](#-quick-start)
- [Base de Datos](#-base-de-datos)
- [Workflows](#-workflows)
- [Deployment](#-deployment)
- [API Documentation](#-api-documentation)

---

## 🏗️ Arquitectura

### Diagrama de Alto Nivel

```
┌─────────────────┐
│   WhatsApp      │
│   Patients      │
└────────┬────────┘
         │
         ▼
┌─────────────────┐      ┌──────────────────┐
│   n8n.ocai      │─────▶│  AWS Lambda      │
│   health.com    │      │  (Appointment    │
│   (Workflows)   │      │   Store)         │
└────────┬────────┘      └────────┬─────────┘
         │                        │
         │                        ▼
         │               ┌─────────────────┐
         └──────────────▶│  AWS RDS        │
                         │  PostgreSQL     │
                         │  (medical)      │
                         └─────────────────┘
                                  ▲
                                  │
                         ┌────────┴─────────┐
                         │  Google Sheets   │
                         │  (CRM - Clinic   │
                         │   Onboarding)    │
                         └──────────────────┘
```

### Stack Tecnológico

**Backend:**
- **AWS Lambda** - Serverless compute para appointment creation
- **AWS RDS PostgreSQL 15** - Base de datos principal (schema: `medical`)
- **AWS API Gateway** - HTTP endpoints para Lambdas
- **n8n** - Workflow automation (self-hosted en EC2)

**Frontend/Integrations:**
- **WhatsApp Business API** - Canal principal de comunicación
- **Google Sheets** - CRM para onboarding de clínicas
- **Traefik** - Reverse proxy con SSL automático

---

## 🧩 Componentes

### 1. Base de Datos PostgreSQL (`medical` schema)

**16 Tablas Principales:**
- `clinic`, `clinic_branch`, `clinic_subscription`, `clinic_onboarding`
- `patient`, `doctor`, `specialty`, `doctor_specialty`
- `appointment`, `patient_billing`, `chat_history`
- `clinic_evaluation_template`, `evaluation_question`, `evaluation_response`
- `clinic_working_hours`, `location`
- `v_agent_context` (Vista para agente de IA)

**6 Stored Procedures:**
- `mvp_create_patient_appointment_evaluation()` - Orquestador principal
- `upsert_patient()` - Gestión idempotente de pacientes
- `upsert_appointment()` - Gestión de citas
- `upsert_evaluation_response()` - Respuestas de evaluación
- `process_clinic_onboarding()` - Onboarding automatizado de clínicas
- `get_patient_id_by_phone_and_name()` - Helper function

### 2. AWS Lambda Functions

**`lambda_appointment_store`**
- **Runtime:** Python 3.11
- **Trigger:** API Gateway (POST)
- **Function:** Crear paciente + cita + evaluación
- **Database:** pg8000 (pure Python)
- **Response Time:** ~200-500ms

### 3. n8n Workflows

**Workflows Principales:**
- `Master_dev.json` - Workflow principal de WhatsApp
- `data_storage_master.json` - Almacenamiento via Lambda
- `crm_workflow.json` - Sync Google Sheets → RDS
- `appointment_agent.json` - Agente de IA para citas

### 4. Infrastructure

**AWS Resources:**
- **RDS:** `ocai-medical-db.copmy0ewmif4.us-east-1.rds.amazonaws.com`
- **Lambda:** `ocai-appointment-store` (us-east-1)
- **EC2:** n8n server con SSL (n8n.ocaihealth.com)

---

## 📁 Estructura del Proyecto

```
OCAI_DEV/
├── aws_lambdas/                    # AWS Lambda functions
│   ├── lambda_appointment_store.py # Lambda principal
│   ├── requirements.txt            # Dependencies (pg8000)
│   ├── deploy-lambda.sh/ps1       # Deployment scripts
│   └── README.md                   # Lambda documentation
│
├── pipelines/                      # Database schema & migrations
│   ├── ddl.sql                     # Schema completo (16 tablas + SPs)
│   ├── clinic_onboarding.sql       # Tabla staging onboarding
│   ├── clinic_onboarding_sp.sql    # SP process_clinic_onboarding
│   ├── clinic_onboarding_trigger.sql # Trigger automático
│   ├── agent_context_view.sql      # Vista para agente IA
│   └── README-AGENT-CONTEXT.md     # Documentación vista
│
├── n8n_workflows/                  # n8n workflow definitions
│   ├── Master_dev.json             # Workflow principal WhatsApp
│   ├── data_storage_master.json    # Lambda integration
│   ├── crm_workflow.json           # Google Sheets sync
│   └── appointment_agent.json      # AI agent workflows
│
├── gcp_instance/                   # n8n deployment configs
│   ├── docker-compose.yml          # Traefik + n8n
│   ├── .env                        # Environment variables
│   ├── deploy-to-ec2.sh/ps1       # EC2 deployment scripts
│   └── README-DEPLOYMENT.md        # Deployment guide
│
├── migration/                      # AWS migration guides
│   ├── AWS-RDS-SETUP-GUIDE.md     # RDS setup step-by-step
│   ├── AWS-EC2-SETUP-GUIDE.md     # EC2 + n8n setup
│   ├── SETUP-SSL-N8N.md           # SSL configuration
│   ├── setup-db.sh                # Database setup script
│   └── MIGRATION-CHECKLIST.md     # Migration tracking
│
├── terraform/                      # Infrastructure as Code
│   ├── lambda.tf                   # Lambda + API Gateway
│   ├── provider.tf                 # AWS provider config
│   └── README-LAMBDA.md            # Terraform deployment
│
├── OCAI CRM.xlsx                   # CRM spreadsheet template
├── ERD.png                         # Entity Relationship Diagram
└── README.md                       # Este archivo
```

---

## 🚀 Quick Start

### Prerequisites

- AWS Account con credenciales configuradas
- PostgreSQL client (`psql`)
- Python 3.11+
- Docker & Docker Compose (para n8n)
- Git

### 1. Clone Repository

```bash
git clone <repository-url>
cd OCAI_DEV
```

### 2. Setup Database (RDS PostgreSQL)

```bash
# Conectar a RDS
export PGPASSWORD='<your-rds-password>'
psql -h ocai-medical-db.copmy0ewmif4.us-east-1.rds.amazonaws.com \
     -U postgres \
     -d n8n_db \
     -p 5432

# Ejecutar scripts en orden
\i pipelines/ddl.sql
\i pipelines/clinic_onboarding.sql
\i pipelines/clinic_onboarding_sp.sql
\i pipelines/clinic_onboarding_trigger.sql
\i pipelines/agent_context_view.sql

# Verificar
\dn                    -- Ver esquemas
\dt medical.*          -- Ver tablas
\df medical.*          -- Ver funciones
```

### 3. Deploy Lambda

```bash
cd aws_lambdas

# Crear package
./deploy-lambda.sh

# O manualmente
pip install -r requirements.txt -t package/
cp lambda_appointment_store.py package/
cd package && zip -r ../lambda_appointment_store.zip . && cd ..

# Deploy
aws lambda update-function-code \
  --function-name ocai-appointment-store \
  --zip-file fileb://lambda_appointment_store.zip \
  --region us-east-1
```

### 4. Deploy n8n

```bash
cd gcp_instance

# Actualizar .env con tus datos
cp .env.example .env
vim .env

# Deploy a EC2
./deploy-to-ec2.sh <key.pem> <ec2-ip>

# Configurar DNS
# Tipo A: n8n.ocaihealth.com → <ec2-ip>

# Acceder a n8n
https://n8n.ocaihealth.com
```

### 5. Import Workflows

1. Abrir n8n: `https://n8n.ocaihealth.com`
2. **Workflows** → **Import from File**
3. Importar en orden:
   - `data_storage_master.json`
   - `crm_workflow.json`
   - `Master_dev.json`
4. Actualizar credenciales PostgreSQL en cada workflow
5. Activar workflows

---

## 💾 Base de Datos

### Schema: `medical`

#### Diagrama Entidad-Relación

![ERD](ERD.png)

#### Tablas Principales

**Gestión de Clínicas:**
```sql
clinic (id, clinic_name, phone_number, status)
  ├── clinic_branch (id, branch_name, location_id, clinic_id)
  ├── clinic_subscription (id, clinic_id, plan, status)
  ├── clinic_working_hours (id, clinic_id, day_of_week, hours)
  └── clinic_evaluation_template (id, clinic_id, template_name)
```

**Gestión Médica:**
```sql
doctor (id, first_name, last_name, clinic_id)
  └── doctor_specialty (id, doctor_id, specialty_id)
      └── specialty (id, name UNIQUE)
```

**Gestión de Pacientes:**
```sql
patient (id, first_name, last_name, phone, birth_date)
  ├── appointment (id, patient_id, doctor_id, timestamp, status)
  │   ├── patient_billing (id, appointment_id, amount, status)
  │   └── evaluation_response (id, appointment_id, question_id)
  └── chat_history (id, session_id, message JSONB)
```

#### Stored Procedures

**Crear Cita Completa:**
```sql
SELECT medical.mvp_create_patient_appointment_evaluation(
  'Juan',                          -- first_name
  'Pérez',                         -- last_name
  '+573001234567',                 -- phone
  '1990-01-01',                    -- birth_date
  '2026-03-01T14:30:00',          -- appointment_timestamp
  'Consulta general',              -- appointment_reason
  1,                               -- doctor_id
  1,                               -- clinic_id
  '[{"question_id":1,"response_text":"Dolor de cabeza"}]'::jsonb, -- evaluation
  'session_123',                   -- session_id
  'ai_agent'                       -- data_source
) as result;
```

**Onboarding de Clínica:**
```sql
-- Se inserta en clinic_onboarding con status 'Ready'
-- El trigger ejecuta automáticamente process_clinic_onboarding()
-- que crea: clinic → location → branch → doctors → specialties
```

#### Vista para Agente IA

```sql
-- Obtener contexto completo de clínica
SELECT * FROM medical.v_agent_context
WHERE clinic_phone = '+573001234567';

-- Retorna: clinic info, working hours, doctors, specialties, evaluation questions
```

---

## 🔄 Workflows

### 1. Master_dev (WhatsApp Agent)

**Trigger:** WhatsApp message
**Flow:**
1. Recibe mensaje de WhatsApp
2. Obtiene contexto de clínica (`v_agent_context`)
3. Procesa con agente de IA
4. Almacena cita vía `data_storage_master`
5. Responde por WhatsApp

### 2. data_storage_master (Lambda Integration)

**Trigger:** Called by other workflows
**Flow:**
1. Recibe datos del paciente
2. Prepara payload (split name, sanitize phone)
3. Llama a Lambda via HTTP
4. Retorna success/error

**Endpoint:**
```
POST https://[API-GATEWAY-ID].execute-api.us-east-1.amazonaws.com/prod/appointment/create
```

### 3. crm_workflow (Clinic Onboarding)

**Trigger:** Manual / Scheduled
**Flow:**
1. Lee Google Sheets (`OCAI CRM.xlsx`)
2. Compara con clínicas existentes en RDS
3. Identifica clínicas nuevas
4. Inserta en `clinic_onboarding` con status 'Ready'
5. Trigger ejecuta `process_clinic_onboarding()`

---

## 🚢 Deployment

### AWS Lambda

**Manual Deploy:**
```bash
cd aws_lambdas
./deploy-lambda.sh <key.pem>
```

**Terraform Deploy:**
```bash
cd terraform
terraform init
terraform plan -var-file="lambda.tfvars"
terraform apply -var-file="lambda.tfvars"
```

**Environment Variables:**
```bash
DB_HOST=ocai-medical-db.copmy0ewmif4.us-east-1.rds.amazonaws.com
DB_PORT=5432
DB_NAME=n8n_db
DB_USER=postgres
DB_PASSWORD=<your-password>
```

### n8n (EC2)

**Automated Deploy:**
```bash
cd gcp_instance
./deploy-to-ec2.ps1 -KeyPath "key.pem" -EC2_IP "54.123.45.67"
```

**Manual Deploy:**
```bash
# SSH to EC2
ssh -i key.pem ubuntu@<ec2-ip>

# Install Docker
sudo apt update && sudo apt install -y docker.io docker-compose

# Setup n8n
mkdir -p ~/n8n && cd ~/n8n
# Copy docker-compose.yml and .env
docker-compose up -d
```

**SSL Configuration:**
- Traefik automatically obtains Let's Encrypt certificate
- Configured via `docker-compose.yml`
- Auto-renewal every 60 days

---

## 📚 API Documentation

### Lambda Endpoint

**Base URL:**
```
https://[API-GATEWAY-ID].execute-api.us-east-1.amazonaws.com/prod
```

#### POST `/appointment/create`

**Request:**
```json
{
  "first_name": "Juan",
  "last_name": "Pérez",
  "phone": "+573001234567",
  "birth_date": "1990-05-15",
  "appointment_date": "2026-03-01",
  "appointment_time": "14:30",
  "appointment_reason": "Consulta general",
  "self_evaluation": "Me duele la cabeza",
  "doctor_id": 1,
  "clinic_id": 1,
  "sessionId": "whatsapp_session_123"
}
```

**Response (Success):**
```json
{
  "success": true,
  "patient_id": 123,
  "appointment_id": 456,
  "chat_history_id": 789,
  "evaluations_processed": 1,
  "processing_time_seconds": 0.245,
  "mvp_version": "v1.0"
}
```

**Response (Error):**
```json
{
  "success": false,
  "error": "Missing required field: phone",
  "error_code": "VALIDATION_ERROR"
}
```

---

## 🔧 Configuration

### Database Connection

**From Local:**
```bash
psql "host=ocai-medical-db.copmy0ewmif4.us-east-1.rds.amazonaws.com \
      port=5432 \
      dbname=n8n_db \
      user=postgres \
      sslmode=require"
```

**From n8n:**
- Host: `ocai-medical-db.copmy0ewmif4.us-east-1.rds.amazonaws.com`
- Port: `5432`
- Database: `n8n_db`
- User: `postgres`
- SSL: Enabled

**From Lambda:**
- Uses environment variables
- SSL: Required
- Connection pooling: Disabled (serverless)

---

## 🛠️ Troubleshooting

### Lambda Issues

**Error: "Unable to connect to database"**
- ✅ Check Security Group allows Lambda → RDS
- ✅ Verify VPC configuration if RDS is private
- ✅ Check environment variables

**Error: "password authentication failed"**
- ✅ Verify DB_PASSWORD in Lambda env vars
- ✅ Test connection from local: `psql "host=..."`

### n8n Issues

**Cannot access n8n.ocaihealth.com**
- ✅ Verify DNS points to EC2 IP
- ✅ Check Security Group allows ports 80/443
- ✅ Check Traefik logs: `docker-compose logs traefik`

**SSL Certificate not obtained**
- ✅ Wait 5-10 minutes for DNS propagation
- ✅ Check port 80 is accessible for ACME challenge
- ✅ Verify Let's Encrypt rate limits not exceeded

### Database Issues

**Constraint violations**
- ✅ Check `specialty.name` has UNIQUE constraint
- ✅ Verify foreign key relationships exist
- ✅ Review stored procedure logic

---

## 📖 Additional Documentation

- [AWS RDS Setup Guide](migration/AWS-RDS-SETUP-GUIDE.md)
- [AWS EC2 Setup Guide](migration/AWS-EC2-SETUP-GUIDE.md)
- [SSL Configuration](migration/SETUP-SSL-N8N.md)
- [Lambda Deployment](aws_lambdas/README.md)
- [Database Schema](pipelines/README-AGENT-CONTEXT.md)
- [Terraform Deployment](terraform/README-LAMBDA.md)

---

## 🤝 Contributing

Este es un proyecto privado. Para contribuir:

1. Crear feature branch
2. Hacer cambios y commit
3. Push y crear Pull Request
4. Esperar code review

---

## 📝 License

Proprietary - OCAI Health © 2026

---

## 📞 Support

Para soporte técnico:
- Email: operation@ocaihealth.com
- Docs: [Internal Wiki](https://wiki.ocaihealth.com)

---

**Última actualización:** 2026-02-19
**Versión:** 2.0.0 (AWS Migration)
