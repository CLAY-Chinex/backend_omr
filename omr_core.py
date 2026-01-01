import cv2
import numpy as np

# =============================================================================
#  SECCIÓN 1: UTILIDADES GEOMÉTRICAS
# =============================================================================

def ordenar_puntos(pts):
    rect = np.zeros((4, 2), dtype="float32")
    s = pts.sum(axis=1)
    rect[0] = pts[np.argmin(s)]
    rect[2] = pts[np.argmax(s)]
    diff = np.diff(pts, axis=1)
    rect[1] = pts[np.argmin(diff)]
    rect[3] = pts[np.argmax(diff)]
    return rect


def transformar_perspectiva_dinamica(imagen, puntos_esquinas, tamaño_cuadro_ref):
    rect = ordenar_puntos(puntos_esquinas)
    (tl, tr, br, bl) = rect

    widthA = np.linalg.norm(br - bl)
    widthB = np.linalg.norm(tr - tl)
    maxWidth = int(max(widthA, widthB))

    heightA = np.linalg.norm(tr - br)
    heightB = np.linalg.norm(tl - bl)
    maxHeight = int(max(heightA, heightB))

    margen = int(tamaño_cuadro_ref * 0.52)

    dst = np.array([
        [margen, margen],
        [maxWidth + margen, margen],
        [maxWidth + margen, maxHeight + margen],
        [margen, maxHeight + margen]
    ], dtype="float32")

    M = cv2.getPerspectiveTransform(rect, dst)
    return cv2.warpPerspective(
        imagen, M,
        (maxWidth + margen * 2, maxHeight + margen * 2)
    )

# =============================================================================
#  SECCIÓN 2: DETECCIÓN Y AUTOCORRECCIÓN (VERSIÓN SERVIDOR)
# =============================================================================

def detectar_anchas_y_transformar_desde_cv2(img_cv2):
    img_original = img_cv2.copy()
    gray = cv2.cvtColor(img_original, cv2.COLOR_BGR2GRAY)
    blurred = cv2.GaussianBlur(gray, (5, 5), 0)

    _, thresh = cv2.threshold(blurred, 100, 255, cv2.THRESH_BINARY_INV)
    cnts, _ = cv2.findContours(thresh, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)

    cuadrados = []

    for c in cnts:
        peri = cv2.arcLength(c, True)
        approx = cv2.approxPolyDP(c, 0.04 * peri, True)
        area = cv2.contourArea(c)

        if len(approx) == 4 and area > 50:
            x, y, w, h = cv2.boundingRect(approx)
            if 0.8 <= w / float(h) <= 1.2:
                M = cv2.moments(c)
                if M["m00"] != 0:
                    cx = int(M["m10"] / M["m00"])
                    cy = int(M["m01"] / M["m00"])
                    cuadrados.append((area, [cx, cy], max(w, h)))

    cuadrados.sort(key=lambda x: x[0], reverse=True)
    if len(cuadrados) < 4:
        return None

    pts = np.array([c[1] for c in cuadrados[:4]], dtype="float32")
    tamaño_prom = np.mean([c[2] for c in cuadrados[:4]])

    img_warp = transformar_perspectiva_dinamica(gray, pts, tamaño_prom)

    # ---------- Autocorrección por densidad ----------
    h, w = img_warp.shape
    b = int(0.025 * w)

    zonas = {
        "izq": img_warp[:, :b],
        "der": img_warp[:, w - b:],
        "sup": img_warp[:b, :],
        "inf": img_warp[h - b:, :]
    }

    def tinta(roi):
        bin = cv2.threshold(roi, 0, 255,
                            cv2.THRESH_BINARY_INV | cv2.THRESH_OTSU)[1]
        return cv2.countNonZero(bin)

    dens = {k: tinta(v) for k, v in zonas.items()}
    dominante = max(dens, key=dens.get)

    if dominante == "sup":
        img_warp = cv2.rotate(img_warp, cv2.ROTATE_180)
    elif dominante == "izq":
        img_warp = cv2.rotate(img_warp, cv2.ROTATE_90_COUNTERCLOCKWISE)
    elif dominante == "der":
        img_warp = cv2.rotate(img_warp, cv2.ROTATE_90_CLOCKWISE)

    return img_warp

# =============================================================================
#  SECCIÓN 3: ROIs
# =============================================================================

def visualizar_y_recortar_zonas(img):
    bin = cv2.threshold(img, 0, 255,
                        cv2.THRESH_BINARY_INV | cv2.THRESH_OTSU)[1]
    H, W = img.shape

    def roi(x1, x2, y1, y2):
        return {
            'x': int(W * x1),
            'y': int(H * y1),
            'w': int(W * (x2 - x1)),
            'h': int(H * (y2 - y1))
        }

    return bin, [
        roi(0.076, 0.243, 0.303, 0.603),
        roi(0.36, 0.49, 0.065, 0.958),
        roi(0.537, 0.667, 0.065, 0.958)
    ]

# =============================================================================
#  SECCIÓN 4: LECTURA
# =============================================================================

def evaluar_bloque(img, preguntas=30, opciones=5):
    H, W = img.shape
    step_y, step_x = H / preguntas, W / opciones
    res = []

    for i in range(preguntas):
        fila = []
        for j in range(opciones):
            celda = img[
                int(i * step_y):int((i + 1) * step_y),
                int(j * step_x):int((j + 1) * step_x)
            ]
            fila.append(cv2.countNonZero(celda))

        marcadas = [i for i, v in enumerate(fila) if v > 180]
        res.append(-1 if not marcadas else marcadas[0] if len(marcadas) == 1 else -2)

    return res


def leer_codigo_estudiante(img):
    H, W = img.shape
    step_x, step_y = W / 8, H / 10
    codigo = ""

    for j in range(8):
        col = []
        for i in range(10):
            celda = img[
                int(i * step_y):int((i + 1) * step_y),
                int(j * step_x):int((j + 1) * step_x)
            ]
            col.append(cv2.countNonZero(celda))

        marcadas = [i for i, v in enumerate(col) if v > 180]
        if len(marcadas) == 1:
            codigo += str(marcadas[0])
        elif len(marcadas) == 0:
            codigo += "?"
        else:
            return "INVALIDO"

    return codigo

# =============================================================================
#  🔥 FUNCIÓN FINAL PARA EL SERVIDOR 🔥
# =============================================================================

def procesar_imagen_desde_servidor(img_cv2):
    """
    ENTRADA:
        img_cv2 → Imagen OpenCV (numpy)
    SALIDA:
        (codigo_estudiante, lista_respuestas)
    """

    img_warp = detectar_anchas_y_transformar_desde_cv2(img_cv2)
    if img_warp is None:
        return "ERROR_ANCLAS", []

    img_bin, rois = visualizar_y_recortar_zonas(img_warp)

    roi_c, roi_p1, roi_p2 = rois

    codigo = leer_codigo_estudiante(
        img_bin[roi_c['y']:roi_c['y'] + roi_c['h'],
                roi_c['x']:roi_c['x'] + roi_c['w']]
    )

    if codigo == "INVALIDO":
        return "INVALIDO", []

    r1 = evaluar_bloque(img_bin[
        roi_p1['y']:roi_p1['y'] + roi_p1['h'],
        roi_p1['x']:roi_p1['x'] + roi_p1['w']
    ])

    r2 = evaluar_bloque(img_bin[
        roi_p2['y']:roi_p2['y'] + roi_p2['h'],
        roi_p2['x']:roi_p2['x'] + roi_p2['w']
    ])

    letras = ["A", "B", "C", "D", "E"]
    respuestas = []

    for r in r1 + r2:
        respuestas.append("" if r == -1 else "ANULADA" if r == -2 else letras[r])

    return codigo, respuestas
