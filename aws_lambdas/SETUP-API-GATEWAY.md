# Configurar API Gateway para Lambda Appointment Store

## Paso 1: Verificar Lambda creada

1. Ve a **AWS Console** → **Lambda**
2. Verifica que existe la función: `ocai-appointment-store`
3. Verifica configuración:
   - ✅ Runtime: Python 3.11
   - ✅ Handler: `lambda_appointment_store.lambda_handler`
   - ✅ Timeout: 30 segundos
   - ✅ Memory: 256 MB

## Paso 2: Configurar Variables de Entorno

1. En la Lambda, ve a **Configuration** → **Environment variables**
2. Click **Edit**
3. Agregar las siguientes variables:

```
DB_HOST = ocai-medical-db.copmy0ewmif4.us-east-1.rds.amazonaws.com
DB_PORT = 5432
DB_NAME = n8n_db
DB_USER = postgres
DB_PASSWORD = <tu-password-aquí>
```

4. Click **Save**

## Paso 3: Configurar VPC (Si RDS está en VPC privada)

**IMPORTANTE:** Solo si tu RDS no es públicamente accesible.

1. Ve a **Configuration** → **VPC**
2. Click **Edit**
3. Configurar:
   - **VPC:** Selecciona la misma VPC que tu RDS
   - **Subnets:** Selecciona al menos 2 subnets privadas
   - **Security groups:** Crear o seleccionar uno que permita:
     - Outbound: TCP 5432 al Security Group de RDS
4. Click **Save**

## Paso 4: Ajustar Security Group de RDS

1. Ve a **RDS** → **Databases** → `ocai-medical-db`
2. Click en el **VPC security group** activo
3. Ve a **Inbound rules** → **Edit inbound rules**
4. **Add rule**:
   - Type: `PostgreSQL`
   - Protocol: `TCP`
   - Port: `5432`
   - Source: Security Group de Lambda (o Custom con IP si es público)
   - Description: `Lambda appointment store access`
5. **Save rules**

## Paso 5: Crear API Gateway (HTTP API)

1. Ve a **API Gateway** en AWS Console
2. Click **Create API**
3. Selecciona **HTTP API** → **Build**

### Integrations:
4. **Add integration**:
   - Integration type: `Lambda`
   - Lambda function: `ocai-appointment-store`
   - API name: `ocai-appointment-api`
   - Click **Next**

### Configure routes:
5. Configurar ruta:
   - Method: `POST`
   - Resource path: `/appointment/create`
   - Integration target: `ocai-appointment-store`
6. Click **Add method** (opcional para OPTIONS si necesitas CORS preflight)
   - Method: `ANY`
   - Resource path: `/appointment/create`
   - Integration target: `ocai-appointment-store`
7. Click **Next**

### Configure stages:
8. Stage name: `prod` (o `dev` si prefieres)
9. **Auto-deploy**: Enabled
10. Click **Next**

### Review and create:
11. Revisar configuración
12. Click **Create**

## Paso 6: Configurar CORS (Si es necesario)

1. En API Gateway, selecciona tu API
2. Ve a **CORS**
3. Click **Configure**
4. Configurar:
   - **Access-Control-Allow-Origin:** `*` (o tu dominio específico)
   - **Access-Control-Allow-Methods:** `POST, OPTIONS`
   - **Access-Control-Allow-Headers:** `Content-Type, Authorization`
5. Click **Save**

## Paso 7: Obtener URL del Endpoint

1. En API Gateway, ve a **Stages** → `prod`
2. Copiar el **Invoke URL**
3. El endpoint completo será:
   ```
   https://xxxxxxxxxx.execute-api.us-east-1.amazonaws.com/prod/appointment/create
   ```

## Paso 8: Probar el Endpoint

### Desde terminal:
```bash
curl -X POST https://TU-API-ID.execute-api.us-east-1.amazonaws.com/prod/appointment/create \
  -H "Content-Type: application/json" \
  -d '{
    "first_name": "Juan",
    "last_name": "Pérez",
    "phone": "+573001234567",
    "birth_date": "1990-05-15",
    "appointment_date": "2026-03-01",
    "appointment_time": "14:30",
    "appointment_reason": "Consulta general",
    "self_evaluation": "Me duele la cabeza"
  }'
```

### Desde Postman:
1. Method: `POST`
2. URL: `https://TU-API-ID.execute-api.us-east-1.amazonaws.com/prod/appointment/create`
3. Headers:
   - `Content-Type: application/json`
4. Body (raw JSON):
```json
{
  "first_name": "Juan",
  "last_name": "Pérez",
  "phone": "+573001234567",
  "birth_date": "1990-05-15",
  "appointment_date": "2026-03-01",
  "appointment_time": "14:30",
  "appointment_reason": "Consulta general",
  "self_evaluation": "Me duele la cabeza"
}
```

### Respuesta esperada:
```json
{
  "success": true,
  "patient_id": 123,
  "appointment_id": 456,
  "chat_history_id": 789,
  "evaluations_processed": 1,
  "request_id": "abc-123-def",
  "processing_time_seconds": 0.245,
  "mvp_version": "v1.0"
}
```

## Paso 9: Monitoreo

### Ver logs en CloudWatch:
1. Ve a **CloudWatch** → **Log groups**
2. Busca: `/aws/lambda/ocai-appointment-store`
3. Click para ver logs en tiempo real

### Ver métricas:
1. En Lambda, ve a **Monitor** → **Metrics**
2. Revisar:
   - Invocations
   - Duration
   - Errors
   - Throttles

## Troubleshooting

### Error: "Unable to connect to database"
- ✅ Verificar Security Group permite Lambda → RDS
- ✅ Verificar Lambda está en misma VPC que RDS
- ✅ Verificar variables de entorno están configuradas
- ✅ Verificar RDS está activo y accesible

### Error: "Task timed out after 3.00 seconds"
- ✅ Aumentar timeout de Lambda a 30 segundos
- ✅ Verificar conexión de red no está bloqueada

### Error: "Missing required environment variables"
- ✅ Verificar todas las variables DB_* están configuradas
- ✅ No debe haber espacios en los valores

### Error: "Internal server error"
- ✅ Revisar logs en CloudWatch
- ✅ Verificar que el esquema `medical` existe en RDS
- ✅ Verificar que la SP `mvp_create_patient_appointment_evaluation` existe

## Siguiente Paso

Una vez que el endpoint funcione, integrarlo con n8n:

1. En n8n, crear workflow con nodo **HTTP Request**
2. Configurar:
   - Method: `POST`
   - URL: Tu API Gateway endpoint
   - Body: JSON con datos de cita
3. Probar y activar workflow

## Alternativa: Usar Terraform

Si prefieres automatizar todo, ver archivo `terraform/lambda.tf` para deployment con Terraform.
