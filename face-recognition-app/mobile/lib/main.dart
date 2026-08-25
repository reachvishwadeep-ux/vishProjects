import 'package:flutter/material.dart';

import 'api_client.dart';
import 'image_source.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(FaceRecApp(api: ApiClient(), images: ImageSourceService()));
}

class FaceRecApp extends StatelessWidget {
  const FaceRecApp({super.key, required this.api, required this.images});

  final ApiClient api;
  final ImageSourceService images;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Face Recognition',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: HomeScreen(api: api, images: images),
    );
  }
}
