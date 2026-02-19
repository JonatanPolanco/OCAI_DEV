# Vista v_agent_context

Vista que proporciona contexto completo de la clínica para el agente de IA de WhatsApp.

## Propósito

Esta vista consolida toda la información relevante de una clínica en una sola consulta optimizada para que el agente de IA pueda:

- ✅ Conocer información básica de la clínica y sede
- ✅ Proporcionar horarios de atención
- ✅ Listar doctores disponibles y sus especialidades
- ✅ Aplicar preguntas de evaluación personalizadas
- ✅ Verificar estado de suscripción

## Estructura de Datos

### Campos Principales

```sql
- clinic_id                    -- ID de la clínica
- clinic_name                  -- Nombre de la clínica
- clinic_phone                 -- Teléfono de contacto (WhatsApp)
- clinic_status                -- Estado (active, inactive, maintenance)
- branch_name                  -- Nombre de la sede
- branch_phone_number          -- Teléfono de la sede
- country                      -- País
- city                         -- Ciudad
- address                      -- Dirección completa
- working_hours                -- JSON con horarios de atención
- doctors                      -- JSON con doctores y especialidades
- evaluation_template_name     -- Nombre de plantilla de evaluación
- evaluation_questions         -- JSON con preguntas de evaluación
- subscription_plan            -- Plan de suscripción (Basic, Premium, etc.)
- subscription_status          -- Estado de suscripción
```

### Formato JSON - working_hours

```json
[
  {
    "day_of_week": 1,
    "day_name": "Lunes",
    "opening_time": "08:00:00",
    "closing_time": "18:00:00"
  },
  {
    "day_of_week": 2,
    "day_name": "Martes",
    "opening_time": "08:00:00",
    "closing_time": "18:00:00"
  }
]
```

### Formato JSON - doctors

```json
[
  {
    "doctor_id": 1,
    "first_name": "Juan",
    "last_name": "Pérez",
    "full_name": "Juan Pérez",
    "specialties": [
      {
        "specialty_id": 1,
        "specialty_name": "Cardiología",
        "is_primary": true
      },
      {
        "specialty_id": 2,
        "specialty_name": "Medicina Interna",
        "is_primary": false
      }
    ]
  }
]
```

### Formato JSON - evaluation_questions

```json
[
  {
    "question_id": 1,
    "question_text": "¿Cómo califica la atención recibida?",
    "question_order": 1
  },
  {
    "question_id": 2,
    "question_text": "¿Recomendaría nuestros servicios?",
    "question_order": 2
  }
]
```

## Instalación

### Método 1: Aplicar solo esta vista

```bash
# Conectar a RDS
psql 'host=ocai-medical-db.copmy0ewmif4.us-east-1.rds.amazonaws.com port=5432 user=postgres dbname=n8n_db sslmode=require'

# Ejecutar script
\i pipelines/agent_context_view.sql
```

### Método 2: Aplicar toda la migración

```bash
cd migration
./setup-db.sh  # Ya incluye la vista
```

## Uso en n8n

### Query básica en nodo PostgreSQL

```sql
SELECT * FROM medical.v_agent_context
WHERE clinic_phone = $1;
```

**Configuración del nodo:**
- Query replacement: `{{ $json.metadata.display_phone_number }}`

### Extraer horarios en n8n

```sql
SELECT
    clinic_name,
    working_hours
FROM medical.v_agent_context
WHERE clinic_phone = $1;
```

En n8n, procesar con **Code node**:
```javascript
// Parsear horarios
const workingHours = JSON.parse($json.working_hours);
const today = new Date().getDay(); // 0=Domingo, 1=Lunes...

// Encontrar horario de hoy
const todaySchedule = workingHours.find(h => h.day_of_week === today);

return {
  json: {
    clinic: $json.clinic_name,
    isOpen: todaySchedule ? true : false,
    opening: todaySchedule?.opening_time,
    closing: todaySchedule?.closing_time
  }
};
```

### Listar doctores disponibles

```sql
SELECT
    clinic_name,
    doctors
FROM medical.v_agent_context
WHERE clinic_phone = $1;
```

En n8n, procesar con **Code node**:
```javascript
const doctors = JSON.parse($json.doctors);

// Crear lista de doctores con especialidades
const doctorList = doctors.map(doc => {
  const primarySpecialty = doc.specialties.find(s => s.is_primary);
  return `Dr. ${doc.full_name} - ${primarySpecialty?.specialty_name || 'General'}`;
}).join('\n');

return {
  json: {
    clinic: $json.clinic_name,
    doctorList: doctorList,
    totalDoctors: doctors.length
  }
};
```

## Queries de Ejemplo

### 1. Obtener contexto completo por teléfono

```sql
SELECT * FROM medical.v_agent_context
WHERE clinic_phone = '+573001234567';
```

### 2. Ver horarios formateados

```sql
SELECT
    clinic_name,
    jsonb_pretty(working_hours::jsonb) AS horarios
FROM medical.v_agent_context
WHERE clinic_phone = '+573001234567';
```

### 3. Listar doctores y especialidades

```sql
SELECT
    clinic_name,
    jsonb_array_elements(doctors::jsonb)->>'full_name' AS doctor,
    jsonb_array_elements(
        jsonb_array_elements(doctors::jsonb)->'specialties'
    )->>'specialty_name' AS especialidad
FROM medical.v_agent_context
WHERE clinic_phone = '+573001234567';
```

### 4. Ver preguntas de evaluación

```sql
SELECT
    clinic_name,
    jsonb_array_elements(evaluation_questions::jsonb)->>'question_text' AS pregunta
FROM medical.v_agent_context
WHERE clinic_phone = '+573001234567'
ORDER BY (jsonb_array_elements(evaluation_questions::jsonb)->>'question_order')::int;
```

### 5. Verificar si está abierto hoy

```sql
SELECT
    clinic_name,
    CASE
        WHEN working_hours::jsonb @> jsonb_build_array(
            jsonb_build_object('day_of_week', EXTRACT(ISODOW FROM CURRENT_DATE))
        ) THEN 'Abierto'
        ELSE 'Cerrado'
    END AS estado_hoy
FROM medical.v_agent_context
WHERE clinic_phone = '+573001234567';
```

## Testing

Ejecutar script de prueba:

```bash
psql 'host=...' -f pipelines/test_agent_context_view.sql
```

Esto ejecutará múltiples queries de prueba para verificar que la vista funciona correctamente.

## Performance

### Índices Recomendados

La vista crea automáticamente:
```sql
CREATE INDEX idx_clinic_phone_number ON medical.clinic(phone_number);
```

### Optimizaciones

- La vista solo retorna clínicas activas (`status = 'active'`)
- Solo muestra la sede principal por clínica
- Solo incluye plantillas de evaluación activas
- Solo muestra preguntas de evaluación activas

## Mantenimiento

### Actualizar la vista

Si necesitas modificar la vista:

```sql
-- Eliminar vista existente
DROP VIEW IF EXISTS medical.v_agent_context CASCADE;

-- Recrear con nuevos cambios
\i pipelines/agent_context_view.sql
```

### Verificar integridad

```sql
-- Verificar que todas las clínicas tienen datos completos
SELECT
    clinic_name,
    clinic_phone,
    CASE WHEN working_hours IS NOT NULL THEN '✓' ELSE '✗' END AS horarios,
    CASE WHEN doctors IS NOT NULL THEN '✓' ELSE '✗' END AS doctores,
    CASE WHEN evaluation_questions IS NOT NULL THEN '✓' ELSE '✗' END AS evaluacion
FROM medical.v_agent_context;
```

## Troubleshooting

### Error: "relation medical.v_agent_context does not exist"

**Solución:**
```bash
psql 'host=...' -f pipelines/agent_context_view.sql
```

### Error: "column does not exist"

**Causa:** Falta alguna columna en las tablas base.

**Solución:** Verificar que ejecutaste el DDL completo:
```bash
psql 'host=...' -f pipelines/ddl.sql
```

### Vista retorna datos vacíos

**Causa:** No hay clínicas activas o faltan relaciones.

**Verificar:**
```sql
-- Ver clínicas activas
SELECT * FROM medical.clinic WHERE status = 'active';

-- Ver si tienen sedes
SELECT c.clinic_name, COUNT(cb.id) as branches
FROM medical.clinic c
LEFT JOIN medical.clinic_branch cb ON cb.clinic_id = c.id
GROUP BY c.id, c.clinic_name;
```

## Próximos Pasos

Una vez creada la vista:

1. ✅ Probar con datos reales usando `test_agent_context_view.sql`
2. ✅ Actualizar workflows de n8n para usar la vista
3. ✅ Configurar prompts del agente con información de la vista
4. ✅ Monitorear performance de queries

## Uso en Prompts de IA

Ejemplo de cómo usar esta información en el prompt del agente:

```
Eres un asistente médico virtual para {{ clinic_name }}.

Ubicación: {{ city }}, {{ country }}
Dirección: {{ address }}

Horarios de atención:
{{ working_hours parsed }}

Doctores disponibles:
{{ doctors list }}

Cuando el paciente termine su consulta, haz estas preguntas:
{{ evaluation_questions }}
```

El workflow de n8n puede construir este prompt dinámicamente usando los datos de la vista.
