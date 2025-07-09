import os
import psycopg2
from flask import Flask, request, jsonify
import logging as logger
from dotenv import load_dotenv

# Cargar variables de entorno desde el archivo .env
load_dotenv()


# Configuración de la base de datos
DB_HOST = os.getenv('DB_HOST')
DB_PORT = os.getenv('DB_PORT')
DB_NAME = os.getenv('DB_NAME')
DB_USER = os.getenv('DB_USER')
DB_PASSWORD = os.getenv('DB_PASSWORD')

# Conectar a PostgreSQL
def get_db_connection():
    conn = psycopg2.connect(
        host=DB_HOST,
        port=DB_PORT,
        dbname=DB_NAME,
        user=DB_USER,
        password=DB_PASSWORD
    )
    return conn
def test_postgres_connection():
    """
    Attempts to connect to the PostgreSQL database using credentials from the .env file.
    Logs success or failure.
    """
    try:
        conn = psycopg2.connect(
            host=DB_HOST,
            port=DB_PORT,
            dbname=DB_NAME,
            user=DB_USER,
            password=DB_PASSWORD
        )
        logger.info("✅ Successfully connected to PostgreSQL database.")
        conn.close()
    except Exception as e:
        logger.error("❌ Failed to connect to PostgreSQL.")
        logger.error(f"Error: {e}")

# Run the test
test_postgres_connection()