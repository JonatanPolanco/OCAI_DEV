"""
AWS Lambda: Appointment Service Store
Migrado desde GCP Cloud Function appointment-service-store.py
Crea paciente + cita + evaluación usando la SP mvp_create_patient_appointment_evaluation
"""

import os
import logging
import json
import re
from datetime import datetime
import pg8000.native

# Configuración de logging
logger = logging.getLogger()
logger.setLevel(logging.INFO)

# Variables de entorno (configurar en Lambda)
DB_HOST = os.getenv("DB_HOST")
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_PORT = os.getenv("DB_PORT", "5432")

# Validar variables críticas al cargar el módulo
if not all([DB_HOST, DB_NAME, DB_USER, DB_PASSWORD]):
    missing = [var for var, val in {
        "DB_HOST": DB_HOST, "DB_NAME": DB_NAME,
        "DB_USER": DB_USER, "DB_PASSWORD": DB_PASSWORD
    }.items() if not val]
    raise ValueError(f"Missing required environment variables: {', '.join(missing)}")


def get_db_connection():
    """Establece conexión a RDS PostgreSQL"""
    logger.info(f"Conectando a {DB_HOST}:{DB_PORT}/{DB_NAME} como {DB_USER}")

    return pg8000.native.Connection(
        user=DB_USER,
        password=DB_PASSWORD,
        host=DB_HOST,
        port=int(DB_PORT),
        database=DB_NAME,
        ssl_context=True,
        timeout=10
    )


def sanitize_phone_number(phone: str) -> str:
    """
    Limpia el número de teléfono, dejando solo dígitos y el prefijo '+'.
    """
    if not phone:
        return None

    if "+" in phone:
        phone = "+" + phone.replace("+", "")

    if phone.startswith("+"):
        return "+" + re.sub(r"[^\d]", "", phone[1:])
    else:
        # Agregar código país por defecto (+57 Colombia)
        clean_phone = re.sub(r"[^\d]", "", phone)
        return f"+57{clean_phone}"


def format_appointment_timestamp(date_str: str, time_str: str) -> str:
    """
    Formatea fecha y hora en timestamp ISO para PostgreSQL
    """
    if not date_str or not time_str:
        return None

    # Asegurar formato de tiempo con segundos
    if len(time_str.split(':')) == 2:
        time_str += ":00"

    return f"{date_str}T{time_str}"


def prepare_evaluation_responses(self_evaluation) -> str:
    """
    Prepara datos de evaluación en formato JSON para PostgreSQL
    """
    if not self_evaluation or self_evaluation in ['No', 'null', 'None', '']:
        return None

    try:
        # Si ya es JSON string, validar y retornar
        if isinstance(self_evaluation, str):
            if self_evaluation.startswith('[') or self_evaluation.startswith('{'):
                json.loads(self_evaluation)  # Validar
                return self_evaluation
            else:
                return json.dumps([{
                    "question_id": 1,
                    "response_text": self_evaluation
                }])

        if isinstance(self_evaluation, list):
            return json.dumps(self_evaluation)
        elif isinstance(self_evaluation, dict):
            return json.dumps([self_evaluation])
        else:
            return json.dumps([{
                "question_id": 1,
                "response_text": str(self_evaluation)
            }])

    except Exception as e:
        logger.warning(f"Error procesando evaluación: {e}")
        return json.dumps([{
            "question_id": 1,
            "response_text": str(self_evaluation)
        }])


def validate_mvp_appointment_data(data: dict) -> tuple:
    """
    Valida los datos para creación de cita MVP
    Returns: (is_valid: bool, error_msg: str, sanitized_data: dict)
    """
    if not data.get("first_name"):
        return False, "Missing required field: first_name", data

    if not data.get("last_name"):
        return False, "Missing required field: last_name", data

    if not data.get("phone"):
        return False, "Missing required field: phone", data

    # Sanitizar datos
    sanitized_data = data.copy()
    sanitized_data["first_name"] = data.get("first_name", "").strip()
    sanitized_data["last_name"] = data.get("last_name", "").strip()
    sanitized_data["phone_sanitized"] = sanitize_phone_number(data["phone"])

    # Validar teléfono sanitizado
    phone = sanitized_data["phone_sanitized"]
    if not (phone and phone.startswith("+") and 8 <= len(phone) <= 15):
        return False, "Invalid phone format after sanitization", sanitized_data

    # Validar fecha de nacimiento si está presente
    if data.get("birth_date"):
        try:
            datetime.strptime(data["birth_date"], "%Y-%m-%d")
        except ValueError:
            return False, "Birth date must be in format YYYY-MM-DD", sanitized_data

    # Formatear timestamp de cita
    appointment_timestamp = format_appointment_timestamp(
        data.get("appointment_date"),
        data.get("appointment_time")
    )
    sanitized_data["appointment_timestamp"] = appointment_timestamp

    # Preparar evaluación
    evaluation_json = prepare_evaluation_responses(data.get("self_evaluation"))
    sanitized_data["evaluation_responses"] = evaluation_json

    return True, "OK", sanitized_data


def create_mvp_appointment(conn, sanitized_data: dict, request_id: str) -> dict:
    """
    Ejecuta la función MVP unificada de PostgreSQL
    """
    try:
        logger.info(f"[{request_id}] Ejecutando función MVP unificada")

        # Prueba básica de conexión
        test_result = conn.run("SELECT 1 as test")
        logger.info(f"[{request_id}] Prueba básica exitosa: {test_result}")

        # Ejecutar función MVP unificada
        result = conn.run("""
            SELECT medical.mvp_create_patient_appointment_evaluation(
                :p1, :p2, :p3, :p4, :p5, :p6, :p7, :p8, :p9, :p10, :p11
            ) as result;
        """,
            p1=sanitized_data["first_name"],
            p2=sanitized_data["last_name"],
            p3=sanitized_data["phone_sanitized"],
            p4=sanitized_data.get("birth_date"),
            p5=sanitized_data["appointment_timestamp"],
            p6=sanitized_data.get("appointment_reason", "Consulta general"),
            p7=sanitized_data.get("doctor_id", 1),
            p8=sanitized_data.get("clinic_id", 1),
            p9=sanitized_data["evaluation_responses"],
            p10=sanitized_data.get("sessionId"),
            p11="ai_agent"
        )

        result_json = result[0][0] if result else {}

        # Manejar resultado
        if result_json.get("success"):
            logger.info(f"[{request_id}] MVP función ejecutada exitosamente")
        else:
            logger.error(f"[{request_id}] MVP función falló: {result_json.get('error')}")

        return result_json

    except Exception as e:
        logger.error(f"[{request_id}] Error en función MVP: {str(e)}", exc_info=True)
        raise


def lambda_handler(event, context):
    """
    AWS Lambda handler para creación MVP de paciente + cita + evaluación
    """
    start_time = datetime.now()
    request_id = context.aws_request_id if context else f"local_{start_time.strftime('%Y%m%d%H%M%S')}"

    logger.info(f"[{request_id}] Procesando solicitud MVP de creación de cita")
    logger.info(f"[{request_id}] Event: {json.dumps(event)}")

    try:
        # Parsear body desde API Gateway
        if isinstance(event.get('body'), str):
            data = json.loads(event['body'])
        else:
            data = event.get('body', event)

        if not data:
            logger.warning(f"[{request_id}] No se proporcionaron datos")
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'POST, OPTIONS',
                    'Access-Control-Allow-Headers': 'Content-Type, Authorization'
                },
                'body': json.dumps({"error": "No data provided"})
            }

        logger.info(f"[{request_id}] Datos recibidos: {json.dumps(data, default=str)}")

        # Validar datos MVP
        valid, msg, sanitized_data = validate_mvp_appointment_data(data)
        if not valid:
            logger.warning(f"[{request_id}] Datos inválidos: {msg}")
            return {
                'statusCode': 400,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*'
                },
                'body': json.dumps({"error": msg})
            }

        # Establecer conexión
        logger.info(f"[{request_id}] Estableciendo conexión a la base de datos")
        conn_start = datetime.now()
        conn = None

        try:
            conn = get_db_connection()
            conn_end = datetime.now()
            logger.info(f"[{request_id}] Conexión establecida en {(conn_end - conn_start).total_seconds():.3f}s")

            # Ejecutar función MVP unificada
            operation_start = datetime.now()
            result = create_mvp_appointment(conn, sanitized_data, request_id)
            operation_end = datetime.now()

            logger.info(f"[{request_id}] Operación MVP completada en {(operation_end - operation_start).total_seconds():.3f}s")

            # Respuesta exitosa
            end_time = datetime.now()
            total_time = (end_time - start_time).total_seconds()

            response_data = {
                **result,
                "request_id": request_id,
                "processing_time_seconds": round(total_time, 3),
                "mvp_version": "v1.0"
            }

            status_code = 200 if result.get("success") else 500

            if result.get("success"):
                logger.info(f"[{request_id}] Operación MVP completada exitosamente en {total_time:.3f}s")
            else:
                logger.error(f"[{request_id}] Operación MVP falló en {total_time:.3f}s")

            return {
                'statusCode': status_code,
                'headers': {
                    'Content-Type': 'application/json',
                    'Access-Control-Allow-Origin': '*',
                    'Access-Control-Allow-Methods': 'POST, OPTIONS',
                    'Access-Control-Allow-Headers': 'Content-Type, Authorization'
                },
                'body': json.dumps(response_data, default=str)
            }

        finally:
            if conn:
                conn.close()
                logger.info(f"[{request_id}] Conexión cerrada")

    except Exception as e:
        end_time = datetime.now()
        total_time = (end_time - start_time).total_seconds()

        logger.exception(f"[{request_id}] Error general después de {total_time:.3f}s: {str(e)}")
        return {
            'statusCode': 500,
            'headers': {
                'Content-Type': 'application/json',
                'Access-Control-Allow-Origin': '*'
            },
            'body': json.dumps({
                "error": "Internal server error",
                "details": str(e),
                "request_id": request_id,
                "processing_time_seconds": round(total_time, 3),
                "mvp_version": "v1.0"
            })
        }
