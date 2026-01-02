import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // <--- 1. IMPORTANTE: Agrega esta librería
import 'omr_app.dart';

void main() {
  // 2. Asegura que el motor de Flutter esté listo antes de configurar la pantalla
  WidgetsFlutterBinding.ensureInitialized();

  // 3. Activa el modo inmersivo "Sticky"
  // Esto oculta las barras y solo aparecen si deslizas desde el borde,
  // luego se ocultan solas otra vez.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);

  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: MenuScreen(), // Asegúrate que llame a MenuScreen del omr_app.dart
    ),
  );
}
