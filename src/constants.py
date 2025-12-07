from dotenv import load_dotenv
import os

load_dotenv()


class Constants:

    API_NAME = "Armazem do Neca - API"
    API_VERSION = "1.0.0"
    API_DESCR =  "API para gerenciamento do Armazem"

    IS_PRODUCTION = os.getenv("ENV", "DEV").lower().upper() == "PROD"

    REFRESH_TOKEN_EXPIRE_DAYS = 15
    ACCESS_TOKEN_EXPIRE_HOURS = 3
    SECRET_KEY = os.getenv("SECRET_KEY")
    ALGORITHM = os.getenv("ALGORITHM")

    MAX_BODY_SIZE = 20 * 1024 * 1024
    MAX_REQUESTS = 300 if os.getenv("ENV", "DEV") == "PROD" else 999_999_999
    WINDOW = 30

    PERMISSIONS_POLICY_HEADER = (
        "geolocation=(), "
        "microphone=(), "
        "camera=(), "
        "payment=(), "
        "usb=(), "
        "magnetometer=(), "
        "gyroscope=(), "
        "accelerometer=()"
    )
    
    SENSITIVE_PATHS = ["/auth/", "/admin/"]