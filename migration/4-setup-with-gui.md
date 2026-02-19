# Ejecutar Migración con Cliente GUI (Sin PostgreSQL local)

## Opción 1: DBeaver (Recomendado) 🦫

### Instalar
```powershell
winget install dbeaver.dbeaver
```

O descarga desde: https://dbeaver.io/download/

### Usar

1. **Crear conexión a RDS:**
   - Host: `ocai-medical-db.copmy0ewmif4.us-east-1.rds.amazonaws.com`
   - Port: `5432`
   - Database: `n8n_db`
   - Username: `postgres`
   - Password: [tu password del terraform.tfvars]

2. **Ejecutar scripts SQL:**
   - File → Open SQL Script
   - Selecciona: `pipelines/ddl.sql`
   - Click en "Execute" (Ctrl+Enter)
   - Repetir para cada archivo en este orden:
     1. `ddl.sql`
     2. `clinic_onboarding.sql`
     3. `clinic_onboarding_sp.sql`
     4. `clinic_onboarding_trigger.sql`

3. **Verificar:**
   - En el Database Navigator, expande: n8n_db → Schemas → medical → Tables
   - Deberías ver todas las tablas creadas

### Ventajas
- ✓ GUI visual para ver datos
- ✓ No instala servidor PostgreSQL
- ✓ Solo instala el driver JDBC
- ✓ Útil para debugging

## Opción 2: pgAdmin 🐘

### Instalar
```powershell
winget install PostgreSQL.pgAdmin
```

O descarga desde: https://www.pgadmin.org/download/

### Usar

1. **Agregar servidor:**
   - Right click "Servers" → Register → Server
   - General Tab:
     - Name: `OCAI RDS`
   - Connection Tab:
     - Host: `ocai-medical-db.copmy0ewmif4.us-east-1.rds.amazonaws.com`
     - Port: `5432`
     - Maintenance database: `n8n_db`
     - Username: `postgres`
     - Password: [tu password]
     - Save password: ✓

2. **Ejecutar scripts:**
   - Click derecho en la base de datos → Query Tool
   - Abre cada archivo SQL y ejecútalo en orden
   - O usa: Tools → Query Tool → Open file

## Opción 3: Azure Data Studio (Si ya lo tienes)

1. Instala la extensión PostgreSQL
2. Conecta a RDS
3. Ejecuta los scripts

## Opción 4: VS Code con extensión PostgreSQL

```powershell
# Instalar extensión
code --install-extension ckolkman.vscode-postgres
```

1. Conecta a RDS desde VS Code
2. Ejecuta los scripts directamente

## ⚠️ Importante: Security Group

Para conectar desde tu PC (con cualquier herramienta GUI), necesitas:

1. **Obtener tu IP pública:**
   ```powershell
   curl https://api.ipify.org
   ```

2. **Agregar tu IP al Security Group de RDS:**
   - AWS Console → RDS → Databases → ocai-medical-db
   - Click en el Security Group (ej: ocai-rds-sg)
   - Inbound rules → Edit inbound rules
   - Add rule:
     - Type: PostgreSQL
     - Port: 5432
     - Source: My IP (o pega tu IP)
     - Description: "Mi PC para desarrollo"

3. **Test de conexión:**
   - En DBeaver/pgAdmin, click en "Test Connection"
   - Debería conectar exitosamente

## Comparación de Opciones

| Opción | Instala | Complejidad | Mejor para |
|--------|---------|-------------|------------|
| Ejecutar desde EC2 | Nada | Baja | Producción, seguridad |
| DBeaver | Solo GUI | Baja | Desarrollo, visualización |
| pgAdmin | Solo GUI | Media | Administración DB |
| Docker | Docker | Media | No instalar nada permanente |
| psql local | Cliente CLI | Baja | Automatización, scripts |

## Mi Recomendación

1. **Para esta migración inicial**: Usa EC2 (más seguro, no abres RDS a Internet)
2. **Para desarrollo diario**: Instala DBeaver (más cómodo que CLI)
3. **Para automatización futura**: Instala solo `psql` (winget install PostgreSQL.PostgreSQL)
