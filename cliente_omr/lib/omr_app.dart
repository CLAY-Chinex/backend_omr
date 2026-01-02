import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

// ============================================================================
// 1. GESTOR DE BASE DE DATOS LOCAL (Equivalente a GestorClaves en Python)
// ============================================================================
class ExamDatabase {
  static const String _keyData = "omr_exam_keys";

  // Cargar todas las claves guardadas
  static Future<Map<String, List<String>>> loadKeys() async {
    final prefs = await SharedPreferences.getInstance();
    final String? data = prefs.getString(_keyData);
    if (data == null) return {};
    // Decodificamos el JSON guardado
    Map<String, dynamic> jsonMap = jsonDecode(data);
    // Convertimos a Map<String, List<String>>
    Map<String, List<String>> result = {};
    jsonMap.forEach((key, value) {
      result[key] = List<String>.from(value);
    });
    return result;
  }

  // Guardar una nueva clave o actualizar la DB
  static Future<void> saveKey(String name, List<String> answers) async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, List<String>> currentData = await loadKeys();
    currentData[name] = answers;
    await prefs.setString(_keyData, jsonEncode(currentData));
  }

  // Eliminar una clave
  static Future<void> deleteKey(String name) async {
    final prefs = await SharedPreferences.getInstance();
    Map<String, List<String>> currentData = await loadKeys();
    currentData.remove(name);
    await prefs.setString(_keyData, jsonEncode(currentData));
  }
}

// ============================================================================
// 2. PANTALLA MENÚ PRINCIPAL
// ============================================================================
class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(title: const Text("Sistema OMR v3.0"), centerTitle: true),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.qr_code_scanner, size: 80, color: Colors.blueGrey),
            const SizedBox(height: 20),
            const Text(
              "CALIFICADOR DE EXÁMENES",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 40),
            _buildMenuButton(
              context,
              "➕ Crear Nueva Plantilla",
              Colors.blue,
              () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const EditorScreen()),
              ),
            ),
            _buildMenuButton(
              context,
              "📂 Cargar y Calificar",
              Colors.green,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SelectorScreen(mode: 'grade'),
                ),
              ),
            ),
            _buildMenuButton(
              context,
              "🗑️ Borrar Plantillas",
              Colors.red,
              () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const SelectorScreen(mode: 'delete'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton(
    BuildContext context,
    String text,
    Color color,
    VoidCallback onTap,
  ) {
    return Container(
      width: 250,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 15),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        onPressed: onTap,
        child: Text(text),
      ),
    );
  }
}

// ============================================================================
// 3. PANTALLA EDITOR (Crear Plantilla)
// ============================================================================
class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key});
  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  final TextEditingController _nameController = TextEditingController();
  // Inicializamos 60 respuestas con "A" por defecto
  final List<String> _answers = List.generate(60, (index) => "A");
  final List<String> _options = ["A", "B", "C", "D", "E"];

  Future<void> _save() async {
    if (_nameController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Ingresa un nombre")));
      return;
    }
    await ExamDatabase.saveKey(_nameController.text, _answers);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Plantilla Guardada ✅")));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Nueva Plantilla")),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: "Nombre del Examen",
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save),
                  label: const Text("Guardar"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: 60,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, index) {
                return ListTile(
                  leading: CircleAvatar(child: Text("${index + 1}")),
                  title: const Text("Respuesta Correcta:"),
                  trailing: DropdownButton<String>(
                    value: _answers[index],
                    items: _options.map((String value) {
                      return DropdownMenuItem<String>(
                        value: value,
                        child: Text(value),
                      );
                    }).toList(),
                    onChanged: (newValue) {
                      setState(() {
                        _answers[index] = newValue!;
                      });
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// 4. PANTALLA SELECTOR (Listar Claves)
// ============================================================================
class SelectorScreen extends StatefulWidget {
  final String mode; // 'grade' o 'delete'
  const SelectorScreen({super.key, required this.mode});

  @override
  State<SelectorScreen> createState() => _SelectorScreenState();
}

class _SelectorScreenState extends State<SelectorScreen> {
  Map<String, List<String>> _keys = {};

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    var data = await ExamDatabase.loadKeys();
    setState(() {
      _keys = data;
    });
  }

  Future<void> _delete(String key) async {
    await ExamDatabase.deleteKey(key);
    _loadData();
  }

  @override
  Widget build(BuildContext context) {
    bool isGradeMode = widget.mode == 'grade';
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isGradeMode
              ? "Seleccionar para Calificar"
              : "Seleccionar para Borrar",
        ),
        backgroundColor: isGradeMode ? Colors.green : Colors.red,
        foregroundColor: Colors.white,
      ),
      body: _keys.isEmpty
          ? const Center(child: Text("No hay plantillas guardadas"))
          : ListView.builder(
              itemCount: _keys.length,
              itemBuilder: (context, index) {
                String keyName = _keys.keys.elementAt(index);
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  child: ListTile(
                    title: Text(
                      keyName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text("${_keys[keyName]!.length} preguntas"),
                    trailing: Icon(
                      isGradeMode ? Icons.arrow_forward_ios : Icons.delete,
                      color: isGradeMode ? Colors.blue : Colors.red,
                    ),
                    onTap: () {
                      if (isGradeMode) {
                        // IR A CALIFICAR
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => GradingScreen(
                              examName: keyName,
                              correctAnswers: _keys[keyName]!,
                            ),
                          ),
                        );
                      } else {
                        // BORRAR
                        _delete(keyName);
                      }
                    },
                  ),
                );
              },
            ),
    );
  }
}

// ============================================================================
// 5. PANTALLA DE CALIFICACIÓN (Lógica Principal + Cámara)
// ============================================================================
class GradingScreen extends StatefulWidget {
  final String examName;
  final List<String> correctAnswers;

  const GradingScreen({
    super.key,
    required this.examName,
    required this.correctAnswers,
  });

  @override
  State<GradingScreen> createState() => _GradingScreenState();
}

class _GradingScreenState extends State<GradingScreen> {
  File? _image;
  bool _loading = false;

  // Variables para resultados
  String _studentCode = "---";
  double _finalScore = 0.0;
  int _correctCount = 0;
  List<String> _studentAnswers = [];
  bool _hasResults = false;

  final String apiUrl = "https://omr-api-clay.onrender.com/procesar";

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _loading = true;
        _hasResults = false;
      });
      _sendToServer(_image!);
    }
  }

  Future<void> _sendToServer(File imageFile) async {
    try {
      var request = http.MultipartRequest('POST', Uri.parse(apiUrl));
      request.files.add(
        await http.MultipartFile.fromPath('file', imageFile.path),
      );

      var response = await request.send();

      if (response.statusCode == 200) {
        var responseStr = await response.stream.bytesToString();
        var json = jsonDecode(responseStr);

        // -- AQUÍ ESTÁ LA LÓGICA DE COMPARACIÓN (IGUAL QUE PYTHON) --
        List<dynamic> rawAnswers = json['respuestas']; // Viene de la API
        List<String> studentAns = rawAnswers.map((e) => e.toString()).toList();
        String code = json['codigo_alumno'] ?? "No detectado";

        // Calcular nota localmente
        int matches = 0;
        int total = widget.correctAnswers.length; // Usamos 60 por defecto

        for (int i = 0; i < total; i++) {
          // Evitar error si el alumno respondió menos preguntas de las configuradas
          String sAnswer = (i < studentAns.length) ? studentAns[i] : "";
          String cAnswer = widget.correctAnswers[i];

          if (sAnswer == cAnswer && sAnswer.isNotEmpty) {
            matches++;
          }
        }

        double score = (matches / total) * 20.0; // Nota vigesimal

        setState(() {
          _studentCode = code;
          _studentAnswers = studentAns;
          _correctCount = matches;
          _finalScore = score;
          _hasResults = true;
        });
      } else {
        _showError("Error Servidor: ${response.statusCode}");
      }
    } catch (e) {
      _showError("Error Conexión: $e");
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.red));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Calificando: ${widget.examName}")),
      body: Column(
        children: [
          // 1. Cabecera con Nota
          Container(
            padding: const EdgeInsets.all(20),
            color: Colors.blueGrey[50],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Código: $_studentCode",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      "Aciertos: $_correctCount / ${widget.correctAnswers.length}",
                    ),
                  ],
                ),
                Column(
                  children: [
                    const Text(
                      "NOTA FINAL",
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                    Text(
                      _hasResults ? _finalScore.toStringAsFixed(2) : "--",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: _finalScore >= 11 ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // 2. Grilla de Resultados (Visual)
          Expanded(
            child: _hasResults
                ? GridView.builder(
                    padding: const EdgeInsets.all(10),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 5, // 5 columnas
                          childAspectRatio: 0.8,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                    itemCount: widget.correctAnswers.length,
                    itemBuilder: (context, index) {
                      String correct = widget.correctAnswers[index];
                      String student = (index < _studentAnswers.length)
                          ? _studentAnswers[index]
                          : "";
                      bool isCorrect = (student == correct);
                      bool isEmpty = student.isEmpty;

                      Color cardColor = isCorrect
                          ? Colors.green.shade100
                          : (isEmpty
                                ? Colors.grey.shade100
                                : Colors.red.shade100);
                      Color borderColor = isCorrect
                          ? Colors.green
                          : (isEmpty ? Colors.grey : Colors.red);
                      String iconText = isCorrect ? "✔" : (isEmpty ? "∅" : "✖");

                      return Container(
                        decoration: BoxDecoration(
                          color: cardColor,
                          border: Border.all(color: borderColor),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "${index + 1}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              iconText,
                              style: TextStyle(
                                fontSize: 20,
                                color: borderColor,
                              ),
                            ),
                            Text(
                              "Tu: $student",
                              style: const TextStyle(fontSize: 10),
                            ),
                            Text(
                              "Ok: $correct",
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  )
                : Center(
                    child: _loading
                        ? const CircularProgressIndicator()
                        : const Text(
                            "Toma una foto para ver resultados",
                            style: TextStyle(color: Colors.grey),
                          ),
                  ),
          ),

          // 3. Botón de Cámara
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton.icon(
                onPressed: _loading ? null : _takePhoto,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue[800],
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.camera_alt),
                label: Text(_loading ? "PROCESANDO..." : "ESCANEAR AHORA"),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
