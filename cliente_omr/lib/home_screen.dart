import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  File? _imagen;
  bool _cargando = false;
  String _resultado = "Presiona la cámara para empezar";

  // TU URL DE RENDER (Asegúrate que termine en /procesar)
  final String apiUrl = "https://omr-api-clay.onrender.com/procesar";

  // 1. Función para tomar foto
  Future<void> _tomarFoto() async {
    final picker = ImagePicker();
    // Bajamos la calidad al 50% para que suba rápido a la nube
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 90,
    );

    if (pickedFile != null) {
      setState(() {
        _imagen = File(pickedFile.path);
        _resultado = "Imagen lista. Enviando al servidor...";
      });
      // Inmediatamente enviamos a calificar
      _enviarAlServidor(_imagen!);
    }
  }

  // 2. Función para enviar a Render (API)
  Future<void> _enviarAlServidor(File imageFile) async {
    setState(() {
      _cargando = true;
    });

    try {
      // Preparamos el envío
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));

      // Adjuntamos la imagen con el nombre 'file' (igual que en Python)
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      // Enviamos
      var response = await request.send();

      // Leemos respuesta
      if (response.statusCode == 200) {
        var responseData = await response.stream.bytesToString();
        var json = jsonDecode(responseData);

        setState(() {
          // Formateamos el texto para que se vea bonito
          _resultado =
              "✅ CALIFICACIÓN EXITOSA\n\n"
              "Código Alumno: ${json['codigo_alumno']}\n"
              "Respuestas: ${json['respuestas']}\n"
              "Estado: ${json['status']}";
        });
      } else {
        setState(() {
          _resultado = "❌ Error del servidor: ${response.statusCode}";
        });
      }
    } catch (e) {
      setState(() {
        _resultado = "❌ Error de conexión: $e";
      });
    } finally {
      setState(() {
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Escáner OMR Escolar")),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          children: [
            // Área de Imagen
            Expanded(
              flex: 2,
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _imagen == null
                    ? const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.camera_alt, size: 60, color: Colors.grey),
                          Text("Toma una foto al examen"),
                        ],
                      )
                    : Image.file(_imagen!, fit: BoxFit.contain),
              ),
            ),

            const SizedBox(height: 20),

            // Área de Resultados
            Expanded(
              flex: 1,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(15),
                color: Colors.black12,
                child: SingleChildScrollView(
                  child: Text(
                    _resultado,
                    style: const TextStyle(fontSize: 16, fontFamily: 'Courier'),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Botón Gigante
            SizedBox(
              width: double.infinity,
              height: 60,
              child: ElevatedButton.icon(
                onPressed: _cargando ? null : _tomarFoto,
                icon: _cargando
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    : const Icon(Icons.camera),
                label: Text(
                  _cargando ? "PROCESANDO EN NUBE..." : "ESCANEAR AHORA",
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
