# AWS Lambda Functions - OCAI Medical

Lambdas para el sistema médico OCAI migradas desde GCP Cloud Functions.

## Lambdas Disponibles

### 1. `lambda_appointment_store.py`
Crea paciente + cita + evaluación usando la stored procedure `mvp_create_patient_appointment_evaluation`.

**Endpoint:** POST `/appointment/create`

**Request Body:**
```json
{
  "first_name": "Juan",
  "last_name": "Pérez",
  "phone": "+573001234567",
  "birth_date": "1990-05-15",
  "appointment_date": "2026-03-01",
  "appointment_time": "14:30",
  "appointment_reason": "Consulta general",
  "doctor_id": 1,
  "clinic_id": 1,
  "self_evaluation": "Me duele la cabeza desde hace 3 días",
  "sessionId": "session_123456"
}
```

**Response:**
```json
{
  "success": true,
  "patient_id": 123,
  "appointment_id": 456,
  "chat_history_id": 789,
  "evaluations_processed": 1,
  "request_id": "abc-123",
  "processing_time_seconds": 0.245,
  "mvp_version": "v1.0"
}
```

## Configuración

### Variables de Entorno

Configurar en cada Lambda en AWS Console:

```bash
DB_HOST=ocai-medical-db.copmy0ewmif4.us-east-1.rds.amazonaws.com
DB_PORT=5432
DB_NAME=n8n_db
DB_USER=postgres
DB_PASSWORD=<your-password>
```

### Permisos IAM

La Lambda necesita:
- Acceso a RDS (a través de Security Group)
- CloudWatch Logs (para logging)
- VPC (si RDS está en VPC privada)

## Deployment

### Opción 1: Manual (AWS Console)

1. Crear Lambda en AWS Console
2. Runtime: Python 3.11
3. Copiar código de `lambda_appointment_store.py`
4. Agregar Layer con psycopg2 o incluir en package
5. Configurar variables de entorno
6. Configurar timeout: 30 segundos
7. Configurar memoria: 256 MB

### Opción 2: Package + Upload

```bash
# Desde el directorio aws_lambdas/
cd aws_lambdas

# Crear package
mkdir -p package
pip install -r requirements.txt -t package/
cp lambda_appointment_store.py package/

# Crear ZIP
cd package
zip -r ../lambda_appointment_store.zip .
cd ..

# Subir a Lambda via AWS CLI
aws lambda update-function-code \
  --function-name ocai-appointment-store \
  --zip-file fileb://lambda_appointment_store.zip \
  --region us-east-1
```

### Opción 3: Con Terraform

Ver `terraform/lambda.tf` para deployment automatizado.

## Testing

### Test Local
```bash
python -c "
import json
from lambda_appointment_store import lambda_handler

event = {
    'body': json.dumps({
        'first_name': 'Test',
        'last_name': 'User',
        'phone': '+573001234567',
        'birth_date': '1990-01-01',
        'appointment_date': '2026-03-01',
        'appointment_time': '14:00'
    })
}

class Context:
    request_id = 'test-123'

result = lambda_handler(event, Context())
print(json.dumps(result, indent=2))
"
```

### Test via API Gateway
```bash
curl -X POST https://your-api-gateway-url.amazonaws.com/appointment/create \
  -H "Content-Type: application/json" \
  -d '{
    "first_name": "Juan",
    "last_name": "Pérez",
    "phone": "+573001234567",
    "birth_date": "1990-05-15",
    "appointment_date": "2026-03-01",
    "appointment_time": "14:30"
  }'
```

## Monitoreo

### CloudWatch Logs
```bash
aws logs tail /aws/lambda/ocai-appointment-store --follow
```

### Métricas
- Duración promedio: ~200-500ms
- Errores: Revisar logs para detalles
- Invocaciones: Dashboard en CloudWatch

## Troubleshooting

### Error: "Unable to connect to database"
- Verificar Security Group permite conexión desde Lambda
- Verificar VPC configuration si RDS está en VPC privada
- Verificar credentials en variables de entorno

### Error: "Missing required environment variables"
- Verificar que todas las variables DB_* están configuradas
- Verificar valores no tienen espacios o caracteres especiales

### Error: "Timeout"
- Aumentar timeout de Lambda (default 3s → 30s)
- Revisar performance de stored procedure
- Considerar connection pooling para alto tráfico

## Migración desde GCP

Diferencias con la Cloud Function original:
- ✅ Handler cambiado de `@functions_framework.http` a `lambda_handler(event, context)`
- ✅ Request parsing adaptado para API Gateway
- ✅ pg8000 → psycopg2-binary (mejor soporte en Lambda)
- ✅ CORS headers en response format de Lambda
- ✅ Variables de entorno: DB_IP → DB_HOST

## Próximos Pasos

1. Crear API Gateway para exponer Lambda
2. Configurar custom domain
3. Implementar rate limiting
4. Agregar API key authentication
5. Configurar monitoring y alertas
