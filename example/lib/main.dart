import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_photo_library_example/presentation/providers/gallery_provider.dart';
import 'package:flutter_photo_library_example/presentation/screens/gallery_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => GalleryProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Native Gallery Example',
        theme: ThemeData(
          brightness: Brightness.dark,
          primaryColor: Colors.deepPurpleAccent,
          scaffoldBackgroundColor: const Color(0xFF0F0F1A),
        ),
        home: const GalleryScreen(),
      ),
    );
  }
}
