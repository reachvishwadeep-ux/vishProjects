import json
import openai
from dotenv import load_dotenv

load_dotenv()

response_format={
        "type": "json_schema",
        "json_schema": {
            "product_detail": "product_schema",
            "schema": {
                "type": "object",
                "properties": {
                    "official_name": {"type": "string"},
                    "version": {"type": "string"},
                    "patches": {
                        "type": "array",
                        "items": {"type": "string"}
                    }
                },
                "required": ["name", "age"]
            }
        }
    }

#print(json.dumps(response_format, indent=2))
