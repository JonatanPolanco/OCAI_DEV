import functions_framework
import os
import logging
import json
import re
from datetime import datetime
from flask import jsonify, Request
import pg8000

# Configuración básica de logging (tu estilo)
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Parámetros de conexión con validación en tiempo de carga
DB_IP = os.getenv("DB_IP")
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_PORT = os.getenv("DB_PORT", "5432")

# Validar variables críticas al cargar el módulo
if not all([DB_IP, DB_NAME, DB_USER, DB_PASSWORD]):
    missing = [var for var, val in {
        "DB_IP": DB_IP, "DB_NAME": DB_NAME, "DB_USER": DB_USER, "DB_PASSWORD": DB_PASSWORD
    }.items() if not val]
    raise ValueError(f"Missing required environment variables: {', '.join(missing)}")

def get_direct_connection():
    """Establece una conexión directa a la base de datos (tu función original)"""
    logger.info(f"Conectando a {DB_IP}:{DB_PORT}/{DB_NAME} como {DB_USER}")
    
    return pg8000.connect(
        user=DB_USER,
        password=DB_PASSWORD,
        host=DB_IP,
        port=int(DB_PORT),
        database=DB_NAME,
        timeout=60  # Aumentar timeout para función unificada
    )

def sanitize_phone_number(phone: str) -> str:
    """
    Limpia el número de teléfono, dejando solo dígitos y el prefijo '+'.
    (Tu función original)
    """
    if "+" in phone:
        phone = "+" + phone.replace("+", "")
    
    if phone.startswith("+"):
        return "+" + re.sub(r"[^\d]", "", phone[1:])
    else:
        # MVP: Agregar código país por defecto si no existe
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
                # Validar que sea JSON válido
                json.loads(self_evaluation)
                return self_evaluation
            else:
                # Texto simple, convertir a estructura
                return json.dumps([{
                    "question_id": 1,
                    "response_text": self_evaluation
                }])
        
        # Si es objeto/lista, convertir a JSON
        if isinstance(self_evaluation, list):
            return json.dumps(self_evaluation)
        elif isinstance(self_evaluation, dict):
            return json.dumps([self_evaluation])
        else:
            # Cualquier otro tipo, convertir a texto
            return json.dumps([{
                "question_id": 1,
                "response_text": str(self_evaluation)
            }])
    
    except Exception as e:
        logger.warning(f"Error procesando evaluación: {e}")
        # Fallback: convertir todo a string simple
        return json.dumps([{
            "question_id": 1,
            "response_text": str(self_evaluation)
        }])

def validate_mvp_appointment_data(data: dict) -> tuple[bool, str, dict]:
    """
    Valida los datos para creación de cita MVP
    """
    # Campos mínimos requeridos para MVP
    if not data.get("first_name"):
        return False, "Missing required field: first_name", data

    if not data.get("last_name"):
        return False, "Missing required field: last_name", data
    
    if not data.get("phone"):
        return False, "Missing required field: phone", data
    
    # Sanitizar datos
    sanitized_data = data.copy()
    
    # Parsear nombre
    sanitized_data["first_name"] = data.get("first_name", "").strip()
    sanitized_data["last_name"] = data.get("last_name", "").strip()
    
    # Sanitizar teléfono
    sanitized_data["phone_sanitized"] = sanitize_phone_number(data["phone"])
    
    # Validar teléfono sanitizado
    phone = sanitized_data["phone_sanitized"]
    if not (phone.startswith("+") and 8 <= len(phone) <= 15):
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
    with conn.cursor() as cur:
        try:
            logger.info(f"[{request_id}] Ejecutando función MVP unificada")
            
            # Prueba básica de conexión (mantener tu estilo)
            cur.execute("SELECT 1")
            test_result = cur.fetchone()
            logger.info(f"[{request_id}] Prueba básica exitosa: {test_result}")
            
            # Ejecutar función MVP unificada
            cur.execute("""
                SELECT medical.mvp_create_patient_appointment_evaluation(
                    %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
                ) as result;
            """, (
                sanitized_data["first_name"],                    # p_first_name
                sanitized_data["last_name"],                     # p_last_name
                sanitized_data["phone_sanitized"],               # p_phone_number_str
                sanitized_data.get("birth_date"),                # p_birth_date
                sanitized_data["appointment_timestamp"],         # p_appointment_timestamp
                sanitized_data.get("appointment_reason", "Consulta general"), # p_appointment_reason
                sanitized_data.get("doctor_id", 1),             # p_doctor_id
                sanitized_data.get("clinic_id", 1),             # p_clinic_id
                sanitized_data["evaluation_responses"],          # p_evaluation_responses
                sanitized_data.get("sessionId"),                # p_session_id
                "ai_agent"                                       # p_data_source
            ))
            
            result = cur.fetchone()[0]
            
            # Manejar resultado
            if result.get("success"):
                conn.commit()
                logger.info(f"[{request_id}] MVP función ejecutada exitosamente")
            else:
                conn.rollback()
                logger.error(f"[{request_id}] MVP función falló: {result.get('error')}")
            
            return result
            
        except Exception as e:
            conn.rollback()
            logger.error(f"[{request_id}] Error en función MVP: {str(e)}")
            raise

@functions_framework.http
def handle_mvp_appointment_creation(request: Request):
    """
    Cloud Function HTTP para creación MVP de paciente + cita + evaluación
    (Ajustado desde tu función original)
    """
    start_time = datetime.now()
    request_id = f"mvp_{start_time.strftime('%Y%m%d%H%M%S')}_{id(request):x}"
    
    logger.info(f"[{request_id}] Procesando solicitud MVP de creación de cita")
    
    # CORS headers
    cors_headers = {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Methods": "POST, OPTIONS",
        "Access-Control-Allow-Headers": "Content-Type, Authorization"
    }
    
    if request.method == "OPTIONS":
        return "", 204, cors_headers
    
    if request.method != "POST":
        logger.warning(f"[{request_id}] Método no permitido: {request.method}")
        return jsonify({"error": "Only POST method allowed"}), 405
    
    try:
        # Obtener datos (las variables ya están validadas al cargar el módulo)
        data = request.get_json()
        if not data:
            logger.warning(f"[{request_id}] No se proporcionaron datos JSON")
            return jsonify({"error": "No JSON data provided"}), 400
        
        logger.info(f"[{request_id}] Datos recibidos: {json.dumps(data, default=str)}")
        
        # Validar datos MVP
        valid, msg, sanitized_data = validate_mvp_appointment_data(data)
        if not valid:
            logger.warning(f"[{request_id}] Datos inválidos: {msg}")
            return jsonify({"error": msg}), 400
        
        # Establecer conexión (tu estilo original)
        logger.info(f"[{request_id}] Estableciendo conexión a la base de datos")
        conn_start = datetime.now()
        conn = None
        try:
            conn = get_direct_connection()
            conn_end = datetime.now()
            logger.info(f"[{request_id}] Conexión establecida en {(conn_end - conn_start).total_seconds():.3f} segundos")
            
            # Ejecutar función MVP unificada
            operation_start = datetime.now()
            result = create_mvp_appointment(conn, sanitized_data, request_id)
            operation_end = datetime.now()
            
            logger.info(f"[{request_id}] Operación MVP completada en {(operation_end - operation_start).total_seconds():.3f} segundos")
            
            # Respuesta exitosa (tu estilo original)
            end_time = datetime.now()
            total_time = (end_time - start_time).total_seconds()
            
            # Agregar metadata de tu estilo original
            response_data = {
                **result,  # Incluir resultado de la función PostgreSQL
                "request_id": request_id,
                "processing_time_seconds": round(total_time, 3),
                "mvp_version": "v1.0"
            }
            
            status_code = 200 if result.get("success") else 500
            
            if result.get("success"):
                logger.info(f"[{request_id}] Operación MVP completada exitosamente en {total_time:.3f} segundos")
            else:
                logger.error(f"[{request_id}] Operación MVP falló en {total_time:.3f} segundos")
            
            return jsonify(response_data), status_code, cors_headers
            
        finally:
            if conn:
                conn.close()
                logger.info(f"[{request_id}] Conexión cerrada")
    
    except Exception as e:
        end_time = datetime.now()
        total_time = (end_time - start_time).total_seconds()
        
        logger.exception(f"[{request_id}] Error general después de {total_time:.3f} segundos: {str(e)}")
        return jsonify({
            "error": "Internal server error", 
            "details": str(e),
            "request_id": request_id,
            "processing_time_seconds": round(total_time, 3),
            "mvp_version": "v1.0"
        }), 500, cors_headers