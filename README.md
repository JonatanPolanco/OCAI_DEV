## Resumen de Estrategia y Arquitectura

### Estrategia General

Este desarrollo se centra en la creación robusta de citas médicas (MVP), asegurando una operación atómica y consistente a través de funciones unificadas y validación exhaustiva. La función principal en Python (`handle_mvp_appointment_creation`) expone una API HTTP que procesa solicitudes JSON, valida y sanitiza entradas, y ejecuta operaciones PostgreSQL atomizadas mediante funciones unificadas en PL/pgSQL.

### Arquitectura Técnica

* **Backend**: Cloud Function (Python + Flask)

  * Recibe solicitudes HTTP POST.
  * Valida y sanitiza datos obligatorios (nombres, teléfono, citas, evaluación).
  * Realiza conexión directa a PostgreSQL usando `pg8000`.
  * Invoca funciones unificadas PL/pgSQL para transacciones seguras.

* **Base de Datos**: PostgreSQL

  * Esquema principal: `medical`
  * Tablas: `patient`, `appointment`, `clinic`, `doctor`, `chat_history`, `evaluation_response`, entre otras.
  * Índices únicos y checks de integridad para evitar datos duplicados y garantizar consistencia.
  * Funciones PL/pgSQL para operaciones atómicas tipo UPSERT, asegurando operaciones idempotentes.
  * **Función orquestadora (`mvp_create_patient_appointment_evaluation`)**:

    * Coordina llamadas a funciones individuales (paciente, cita, evaluación).
    * Previene condiciones de carrera (race conditions) mediante secuenciación explícita y comprobaciones intermedias.
    * Garantiza atomicidad y consistencia transaccional, manejando errores y realizando rollback automático si ocurre alguna excepción.

### Flujo de Datos

1. **Validación**: Datos mínimos requeridos se validan y sanitizan.
2. **Conexión**: Se establece una conexión segura con PostgreSQL.
3. **Operación Unificada (Transacción)**:

   * UPSERT de paciente (`upsert_patient`).
   * Creación opcional de historial de chat (`chat_history`).
   * UPSERT de cita (`upsert_appointment`).
   * Registro condicional de respuestas de evaluación (`upsert_evaluation_response`).
4. **Respuesta**: Retorna JSON estructurado con resultados y metadatos.

### Observabilidad

* Logging detallado en cada paso, identificadores únicos por solicitud (`request_id`).
* Métricas integradas para seguimiento de rendimiento (tiempos de ejecución).

### Ventajas

* Operaciones seguras, rápidas y resilientes.
* Manejo explícito de errores y excepciones.
* Fácil escalabilidad y mantenimiento.
