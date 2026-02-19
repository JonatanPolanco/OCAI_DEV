# Deploy Lambda con Terraform

Automatiza el deployment de Lambda + API Gateway usando Terraform.

## Prerequisitos

1. Terraform instalado: https://www.terraform.io/downloads
2. AWS CLI configurado con credenciales
3. ZIP de Lambda creado: `aws_lambdas/lambda_appointment_store.zip`

## Pasos

### 1. Preparar ZIP de Lambda

```bash
cd aws_lambdas
rm -rf package lambda_appointment_store.zip
mkdir package
pip install -r requirements.txt -t package/
cp lambda_appointment_store.py package/
cd package && zip -r ../lambda_appointment_store.zip . && cd ..
```

O en PowerShell:
```powershell
cd aws_lambdas
Remove-Item -Recurse -Force package -ErrorAction SilentlyContinue
Remove-Item lambda_appointment_store.zip -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path package
pip install -r requirements.txt -t package/
Copy-Item lambda_appointment_store.py package/
Compress-Archive -Path package\* -DestinationPath lambda_appointment_store.zip -Force
```

### 2. Configurar Variables

```bash
cd terraform
cp lambda.tfvars.example lambda.tfvars
```

Editar `lambda.tfvars`:
```hcl
db_host     = "ocai-medical-db.copmy0ewmif4.us-east-1.rds.amazonaws.com"
db_password = "tu-password-aquí"
lambda_runtime = "python3.11"
```

### 3. Inicializar Terraform

```bash
terraform init
```

### 4. Planear Deployment

```bash
terraform plan -var-file="lambda.tfvars"
```

Revisar los recursos que se crearán:
- IAM Role para Lambda
- Lambda Function
- CloudWatch Log Groups
- API Gateway HTTP API
- API Gateway Routes y Stages
- Permisos Lambda/API Gateway

### 5. Aplicar Deployment

```bash
terraform apply -var-file="lambda.tfvars"
```

Escribir `yes` cuando pregunte.

### 6. Obtener Outputs

```bash
terraform output
```

Verás:
```
api_gateway_endpoint = "https://xxxxxxxxxx.execute-api.us-east-1.amazonaws.com/prod/appointment/create"
lambda_function_arn = "arn:aws:lambda:us-east-1:444847048892:function:ocai-appointment-store"
lambda_function_name = "ocai-appointment-store"
```

### 7. Probar Endpoint

```bash
curl -X POST $(terraform output -raw api_gateway_endpoint) \
  -H "Content-Type: application/json" \
  -d '{
    "first_name": "Test",
    "last_name": "User",
    "phone": "+573001234567",
    "birth_date": "1990-01-01",
    "appointment_date": "2026-03-01",
    "appointment_time": "14:00"
  }'
```

## Actualizar Lambda

Si haces cambios en el código:

```bash
# 1. Recrear ZIP
cd aws_lambdas
# ... comandos del paso 1

# 2. Aplicar cambios
cd terraform
terraform apply -var-file="lambda.tfvars"
```

## Destruir Recursos

Para eliminar todos los recursos creados:

```bash
terraform destroy -var-file="lambda.tfvars"
```

## Troubleshooting

### Error: "No such file: lambda_appointment_store.zip"
- Crear el ZIP siguiendo el paso 1

### Error: "Invalid credentials"
- Verificar AWS CLI configurado: `aws sts get-caller-identity`

### Error: Lambda timeout
- Lambda automáticamente configurada con 30s timeout
- Si necesitas más, editar `timeout` en `lambda.tf`

### Error: No puede conectar a RDS
- Verificar Security Group de RDS permite conexiones
- Si RDS está en VPC privada, descomentar `vpc_config` en `lambda.tf`

## Ventajas de Terraform

✅ Reproducible - Misma infraestructura cada vez
✅ Versionable - Cambios en Git
✅ Automatizable - CI/CD pipelines
✅ Documentación - El código ES la documentación
✅ Rollback - Fácil volver a versión anterior

## Próximos Pasos

- [ ] Configurar custom domain en API Gateway
- [ ] Agregar API key authentication
- [ ] Configurar rate limiting
- [ ] Agregar CloudWatch alarms
- [ ] Implementar CI/CD con GitHub Actions
