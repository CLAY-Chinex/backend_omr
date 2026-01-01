from fastapi import FastAPI, File, UploadFile
import cv2
import 
as np
import io
from omr_core import procesar_imagen_desde_servidor

app = FastAPI()

@app.get("/")
def read_root():
    return {"mensaje": "Servidor OMR funcionando correctamente"}

@app.post("/procesar")
async def procesar_examen(file: UploadFile = File(...)):
    try:
        # 1. Leer los bytes de la imagen que envía el celular
        contents = await file.read()
        
        # 2. Convertir bytes a matriz de imagen (OpenCV)
        nparr = np.frombuffer(contents, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        # 3. Llamar a tu lógica matemática
        codigo, respuestas = procesar_imagen_desde_servidor(img)

        return {
            "status": "exito",
            "codigo_alumno": codigo,
            "respuestas": respuestas
        }
    except Exception as e:
        return {"status": "error", "detalle": str(e)}