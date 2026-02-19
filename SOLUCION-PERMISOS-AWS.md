# Solución: Error de Permisos AWS Terraform

## Problema
El usuario IAM `BedrockAPIKey-m3ea` no tiene permisos para crear infraestructura EC2/RDS.

## Solución: Crear Usuario IAM Dedicado para Terraform

### Paso 1: Crear Usuario en AWS Console

1. Accede a https://console.aws.amazon.com/iam/
2. Navega a **Users** → **Create user**
3. Nombre: `terraform-deployer`
4. Marca: **Provide user access to AWS Management Console** → OPCIONAL (solo si quieres que tenga acceso web)
5. Click **Next**

### Paso 2: Asignar Permisos

**Opción A: Políticas Administradas (Más simple)**
- Selecciona **Attach policies directly**
- Agrega estas políticas:
  - `AmazonEC2FullAccess`
  - `AmazonRDSFullAccess`
  - `AmazonVPCFullAccess`
  - `IAMReadOnlyAccess`

**Opción B: Política Personalizada (Más segura)**
1. Selecciona **Create policy**
2. Ve a la pestaña **JSON**
3. Pega el contenido del archivo `iam-policy-terraform.json`
4. Nombra la política: `TerraformOCAIDeployPolicy`
5. Asigna esta política al usuario

### Paso 3: Crear Access Keys

1. Click en el usuario creado
2. Ve a **Security credentials**
3. Scroll hasta **Access keys**
4. Click **Create access key**
5. Selecciona **Command Line Interface (CLI)**
6. Marca "I understand..."
7. Click **Create access key**
8. **GUARDA** el Access Key ID y Secret Access Key (solo se muestra una vez)

### Paso 4: Configurar Nuevo Perfil AWS

Opción 1: Usar `aws configure` con perfil:
```bash
aws configure --profile terraform
# Ingresa:
# - AWS Access Key ID: [tu nuevo access key]
# - AWS Secret Access Key: [tu secret key]
# - Default region: us-east-1
# - Default output format: json
```

Opción 2: Editar manualmente `~/.aws/credentials`:
```
[default]
aws_access_key_id = [tu BedrockAPIKey actual]
aws_secret_access_key = [tu secret actual]

[terraform]
aws_access_key_id = [nuevo access key de terraform-deployer]
aws_secret_access_key = [nuevo secret key]
```

### Paso 5: Usar el Nuevo Perfil con Terraform

**Opción A: Variable de entorno (recomendada)**
```powershell
$env:AWS_PROFILE = "terraform"
.\deploy-terraform.ps1
```

**Opción B: Modificar script de deploy**
Edita `deploy-terraform.ps1` para agregar al inicio:
```powershell
$env:AWS_PROFILE = "terraform"
```

**Opción C: Modificar provider en main.tf**
```hcl
provider "aws" {
  region  = var.aws_region
  profile = "terraform"

  default_tags {
    tags = {
      Project     = "OCAI-Medical"
      Environment = var.environment
      ManagedBy   = "Terraform"
    }
  }
}
```

### Paso 6: Verificar Permisos

```bash
# Verificar que estás usando el perfil correcto
aws sts get-caller-identity --profile terraform

# Debería mostrar:
# "Arn": "arn:aws:iam::444847048892:user/terraform-deployer"
```

### Paso 7: Ejecutar Terraform Nuevamente

```powershell
$env:AWS_PROFILE = "terraform"
.\deploy-terraform.ps1
```

## Alternativa Rápida: Variable de Entorno Temporal

Si solo quieres probar sin crear un perfil:
```powershell
$env:AWS_ACCESS_KEY_ID = "NUEVO_ACCESS_KEY"
$env:AWS_SECRET_ACCESS_KEY = "NUEVO_SECRET_KEY"
$env:AWS_REGION = "us-east-1"
.\deploy-terraform.ps1
```

## Verificación de Seguridad

Después de crear el usuario, verifica:
1. ✓ Las Access Keys están guardadas de forma segura
2. ✓ No compartas las credenciales en repositorios Git
3. ✓ El usuario `BedrockAPIKey-m3ea` sigue funcionando para tus APIs
4. ✓ El nuevo usuario solo se usa para despliegues de infraestructura

## Troubleshooting

Si sigues teniendo errores:
```bash
# Ver qué usuario estás usando actualmente
aws sts get-caller-identity

# Ver permisos del usuario
aws iam get-user --user-name terraform-deployer

# Verificar políticas asignadas
aws iam list-attached-user-policies --user-name terraform-deployer
```
