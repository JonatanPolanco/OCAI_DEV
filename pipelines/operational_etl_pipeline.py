import functions_framework
import os
import logging
import json
from flask import jsonify, Request
import pg8000  # Importa pg8000 directamente

# Configuración básica de logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Parámetros de conexión
DB_IP = os.getenv("DB_IP")  # IP pública de Cloud SQL
DB_NAME = os.getenv("DB_NAME")
DB_USER = os.getenv("DB_USER")
DB_PASSWORD = os.getenv("DB_PASSWORD")
DB_PORT = os.getenv("DB_PORT", "5432")

def get_direct_connection():
    """Establece una conexión directa a la base de datos"""
    logger.info(f"Conectando a {DB_IP}:{DB_PORT}/{DB_NAME} como {DB_USER}")
    
    return pg8000.connect(
        user=DB_USER,
        password=DB_PASSWORD,
        host=DB_IP,
        port=int(DB_PORT),
        database=DB_NAME,
        timeout=30  # 30 segundos de timeout
    )

def upsert_patient(conn, first_name, last_name, phone_number_str, birth_date, source="ai_agent") -> bool:
    """Ejecuta un upsert del paciente en la base de datos"""
    with conn.cursor() as cur:
        try:
            logger.info(f"Ejecutando upsert para {first_name} {last_name}")
            
            # Consulta simple de prueba primero
            cur.execute("SELECT 1")
            test_result = cur.fetchone()
            logger.info(f"Prueba básica exitosa: {test_result}")
            
            # Ahora la función real
            cur.execute("""
                SELECT medical.upsert_patient(%s, %s, %s, %s, %s);
            """, (first_name, last_name, phone_number_str, birth_date, source))
            conn.commit()
            
            logger.info(f"Upsert exitoso para {first_name} {last_name}")
            return True
        except Exception as e:
            conn.rollback()
            logger.error(f"Error en upsert: {str(e)}")
            raise

@functions_framework.http
def handle_upsert_patient(request: Request):
    """Cloud Function HTTP para upsert de paciente"""
    if request.method != "POST":
        return jsonify({"error": "Only POST method allowed"}), 405
    
    try:
        # Verificar variables de entorno
        if not all([DB_IP, DB_NAME, DB_USER, DB_PASSWORD]):
            missing = [v for v, val in {
                "DB_IP": DB_IP, 
                "DB_NAME": DB_NAME, 
                "DB_USER": DB_USER, 
                "DB_PASSWORD": DB_PASSWORD
            }.items() if not val]
            
            return jsonify({
                "error": "Missing environment variables", 
                "missing": missing
            }), 500
        
        # Obtener datos
        data = request.get_json()
        if not data:
            return jsonify({"error": "No JSON data provided"}), 400
        
        # Validar datos básicos
        required = ["first_name", "last_name", "phone_number_str", "birth_date"]
        missing = [f for f in required if f not in data]
        if missing:
            return jsonify({"error": f"Missing fields: {', '.join(missing)}"}), 400
        
        # Establecer conexión
        logger.info("Estableciendo conexión a la base de datos")
        conn = None
        try:
            conn = get_direct_connection()
            
            # Ejecutar upsert
            upsert_patient(
                conn,
                data["first_name"],
                data["last_name"],
                data["phone_number_str"],
                data["birth_date"],
                data.get("source", "ai_agent")
            )
            
            return jsonify({
                "status": "success",
                "message": f"Patient {data['first_name']} {data['last_name']} upserted"
            }), 200
        finally:
            if conn:
                conn.close()
                logger.info("Conexión cerrada")
    
    except Exception as e:
        logger.exception(f"Error general: {str(e)}")
        return jsonify({
            "error": "Internal server error", 
            "details": str(e)
        }), 500