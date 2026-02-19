# Instalar PostgreSQL Client en Windows

Tienes 3 opciones para instalar el cliente PostgreSQL (`psql`) en Windows:

## Opción 1: Winget (Más Rápida) ⚡

```powershell
winget install PostgreSQL.PostgreSQL
```

**Después de instalar:**
1. Cierra y reabre PowerShell/Git Bash
2. Verifica: `psql --version`
3. Si no funciona, reinicia el PC

**Ubicación por defecto:**
- `C:\Program Files\PostgreSQL\16\bin\psql.exe`

## Opción 2: Instalador Oficial (Más Control) 🎯

1. **Descarga el instalador:**
   - https://www.enterprisedb.com/downloads/postgres-postgresql-downloads
   - Selecciona PostgreSQL 16.x para Windows x86-64

2. **Durante la instalación:**
   - ✓ Command Line Tools (necesario)
   - ✗ PostgreSQL Server (NO necesario si solo quieres el cliente)
   - ✗ Stack Builder (NO necesario)
   - ✗ pgAdmin (NO necesario)

3. **Agregar al PATH (si no se agregó automáticamente):**
   ```powershell
   # En PowerShell como Administrador
   $pgPath = "C:\Program Files\PostgreSQL\16\bin"
   [Environment]::SetEnvironmentVariable("Path", $env:Path + ";$pgPath", "Machine")
   ```

4. **Reinicia PowerShell/Git Bash** y verifica:
   ```bash
   psql --version
   ```

## Opción 3: Chocolatey 🍫

Si tienes Chocolatey instalado:

```powershell
choco install postgresql
```

Luego reinicia PowerShell/Git Bash.

## Opción 4: Solo el Cliente (Sin Servidor) 📦

Si solo quieres `psql` sin instalar todo PostgreSQL:

1. Descarga PostgreSQL Binaries:
   - https://www.enterprisedb.com/download-postgresql-binaries

2. Extrae el ZIP y copia solo:
   ```
   postgresql-16.x-windows-x64-binaries.zip
   └── pgsql/
       └── bin/
           ├── psql.exe
           ├── libpq.dll
           └── (otros archivos necesarios)
   ```

3. Copia la carpeta `bin/` a `C:\PostgreSQL\bin\`

4. Agrega al PATH:
   ```powershell
   [Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\PostgreSQL\bin", "User")
   ```

## Opción 5: Docker (Sin Instalar Nada en Windows) 🐳

Si tienes Docker Desktop instalado, puedes usar un contenedor con PostgreSQL client:

```bash
# Navega a la carpeta migration
cd migration

# Ejecuta el script usando Docker
bash 2-setup-rds-docker.sh ocai-medical-db.copmy0ewmif4.us-east-1.rds.amazonaws.com postgres n8n_db
```

Ver instrucciones en `2-setup-rds-docker.sh`

## Verificar Instalación

```bash
# Ver versión
psql --version

# Debería mostrar algo como:
# psql (PostgreSQL) 16.x
```

## Troubleshooting

### "psql no se reconoce como comando"

**Solución 1: Reiniciar terminal**
Cierra y abre nuevamente PowerShell o Git Bash

**Solución 2: Verificar PATH manualmente**
```powershell
# Ver el PATH actual
$env:Path -split ';' | Select-String postgres

# Si no aparece, agrega manualmente:
$env:Path += ";C:\Program Files\PostgreSQL\16\bin"
```

**Solución 3: Usar ruta completa**
```bash
"C:\Program Files\PostgreSQL\16\bin\psql.exe" --version
```

### Error de conexión a RDS

Si instalaste PostgreSQL pero no puedes conectar a RDS:

1. **Verifica tu IP pública:**
   ```bash
   curl https://api.ipify.org
   ```

2. **Agrega tu IP al Security Group de RDS:**
   - AWS Console → RDS → Databases → ocai-medical-db
   - Security group → Inbound rules → Edit
   - Add rule: PostgreSQL (5432) desde tu IP

3. **Verifica credenciales:**
   ```bash
   # Test de conexión
   psql -h ocai-medical-db.copmy0ewmif4.us-east-1.rds.amazonaws.com -U postgres -d n8n_db -c "SELECT 1;"
   ```

## Después de Instalar

Ejecuta el script de migración:

**PowerShell:**
```powershell
cd migration
.\1-setup-rds.ps1 -Host ocai-medical-db.copmy0ewmif4.us-east-1.rds.amazonaws.com -User postgres -Database n8n_db
```

**Git Bash:**
```bash
cd migration
bash 1-setup-rds.sh ocai-medical-db.copmy0ewmif4.us-east-1.rds.amazonaws.com postgres n8n_db
```
