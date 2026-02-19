-- Script de prueba para la vista v_agent_context

-- 1. Crear la vista
\i agent_context_view.sql

-- 2. Verificar que la vista existe
SELECT
    table_name,
    table_type
FROM information_schema.tables
WHERE table_schema = 'medical'
  AND table_name = 'v_agent_context';

-- 3. Ver la estructura de la vista
\d+ medical.v_agent_context

-- 4. Probar la vista con datos existentes
-- Ver todas las clínicas disponibles
SELECT
    clinic_id,
    clinic_name,
    clinic_phone,
    branch_name,
    city,
    country
FROM medical.v_agent_context;

-- 5. Buscar por teléfono de clínica (ejemplo de uso real)
-- Reemplazar con un número real de tu base de datos
SELECT
    clinic_name,
    clinic_phone,
    branch_name,
    city,
    address,
    subscription_plan,
    subscription_status
FROM medical.v_agent_context
WHERE clinic_phone = '+573001234567';

-- 6. Ver horarios de atención formateados
SELECT
    clinic_name,
    clinic_phone,
    jsonb_pretty(working_hours::jsonb) AS horarios
FROM medical.v_agent_context
LIMIT 1;

-- 7. Ver doctores y especialidades formateados
SELECT
    clinic_name,
    clinic_phone,
    jsonb_pretty(doctors::jsonb) AS doctores
FROM medical.v_agent_context
LIMIT 1;

-- 8. Ver preguntas de evaluación formateadas
SELECT
    clinic_name,
    clinic_phone,
    evaluation_template_name,
    jsonb_pretty(evaluation_questions::jsonb) AS preguntas
FROM medical.v_agent_context
LIMIT 1;

-- 9. Contar clínicas disponibles para el agente
SELECT
    COUNT(*) AS total_clinicas_activas,
    COUNT(DISTINCT clinic_phone) AS total_telefonos_unicos,
    COUNT(DISTINCT city) AS total_ciudades
FROM medical.v_agent_context;

-- 10. Ver resumen de datos disponibles por clínica
SELECT
    clinic_name,
    clinic_phone,
    CASE WHEN working_hours IS NOT NULL THEN 'Sí' ELSE 'No' END AS tiene_horarios,
    CASE WHEN doctors IS NOT NULL THEN 'Sí' ELSE 'No' END AS tiene_doctores,
    CASE WHEN evaluation_questions IS NOT NULL THEN 'Sí' ELSE 'No' END AS tiene_evaluacion,
    subscription_status
FROM medical.v_agent_context
ORDER BY clinic_name;

-- 11. Extraer información específica de los JSON
-- Obtener lista de especialidades disponibles en una clínica
SELECT
    clinic_name,
    jsonb_array_elements(doctors::jsonb)->>'full_name' AS doctor_name,
    jsonb_array_elements(
        jsonb_array_elements(doctors::jsonb)->'specialties'
    )->>'specialty_name' AS specialty
FROM medical.v_agent_context
WHERE clinic_phone = '+573001234567';

-- 12. Ver horarios en formato legible
SELECT
    clinic_name,
    jsonb_array_elements(working_hours::jsonb)->>'day_name' AS dia,
    jsonb_array_elements(working_hours::jsonb)->>'opening_time' AS apertura,
    jsonb_array_elements(working_hours::jsonb)->>'closing_time' AS cierre
FROM medical.v_agent_context
WHERE clinic_phone = '+573001234567'
ORDER BY (jsonb_array_elements(working_hours::jsonb)->>'day_of_week')::int;
