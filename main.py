from fastapi import FastAPI, File, UploadFile
import cv2
import numpy as np
# El error probablemente estaba en la linea siguiente (import io o similar incompleto)
from omr_core import procesar_imagen_desde_servidor

app = FastAPI()

@app.get("/")
def read_root():
    return {"mensaje": "Servidor OMR funcionando correctamente"}

@app.post("/procesar")
async def procesar_examen(file: UploadFile = File(...)):
    try:
        # 1. Leer los bytes de la imagen
        contents = await file.read()
        
        # 2. Convertir a matriz numpy
        nparr = np.frombuffer(contents, np.uint8)
        
        # 3. Decodificar imagen para OpenCV
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        if img is None:
             return {"status": "error", "detalle": "El archivo no es una imagen valida"}

        # 4. Procesar
        codigo, respuestas = procesar_imagen_desde_servidor(img)

        return {
            "status": "exito",
            "codigo_alumno": codigo,
            "respuestas": respuestas
        }
    except Exception as e:
        return {"status": "error", "detalle": str(e)}