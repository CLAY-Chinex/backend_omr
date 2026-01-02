from fastapi import FastAPI, File, UploadFile
import cv2
import numpy as np

# CORRECCIÓN: Importamos el nombre correcto de la función que definimos en omr_core.py
from omr_core import procesar_imagen_memoria 

app = FastAPI()

@app.get("/")
def read_root():
    return {"mensaje": "API OMR Online v3.0 (Adaptive Threshold)"}

@app.post("/procesar")
async def procesar_examen(file: UploadFile = File(...)):
    try:
        # 1. Leer bytes
        contents = await file.read()
        nparr = np.frombuffer(contents, np.uint8)
        
        # 2. Decodificar (De bytes a Matriz OpenCV)
        # Esto es crucial: omr_core espera una matriz, y esto se la da.
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        if img is None:
             return {"status": "error", "detalle": "Archivo corrupto o no es imagen"}

        # 3. Procesar (Llamamos a la función con el nombre CORRECTO)
        codigo, respuestas = procesar_imagen_memoria(img)

        return {
            "status": "exito",
            "codigo_alumno": codigo,
            "respuestas": respuestas
        }
    except Exception as e:
        # Devolvemos el error exacto para debugging
        return {"status": "error", "detalle": str(e)}