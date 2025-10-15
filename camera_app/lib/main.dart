import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

List<CameraDescription>? cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  cameras = await availableCameras();
  runApp(const CameraApp());
}

class CameraApp extends StatefulWidget {
  const CameraApp({super.key});

  @override
  State<CameraApp> createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {
  CameraController? controller;
  String? barcodeResult;
  String? productInfo;
  String? ingredientsText;
  Map<String, dynamic>? nutriments;

  Future<void> fetchProduct(String barcode) async {
    final url = Uri.parse('https://world.openfoodfacts.org/api/v0/product/$barcode.json');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data['status'] == 1) {
        final product = data['product'];
        setState(() {
          productInfo = product['product_name'] ?? 'No product name found';
          if (product['brands'] != null) {
            productInfo = '$productInfo by ${product['brands']}';
          }
          ingredientsText = product['ingredients_text_en'] ?? 'No ingredients listed';
          nutriments = product['nutriments'] as Map<String, dynamic>?;
        });
      } else {
        setState(() {
          productInfo = 'Product not found.';
        });
      }
    } else {
      setState(() {
        productInfo = 'Error fetching product data.';
      });
    }
  }

  @override
  void initState() {
    super.initState();
    if (cameras != null && cameras!.isNotEmpty) {
      controller = CameraController(cameras![0], ResolutionPreset.max);
      controller?.initialize().then((_) {
        if (!mounted) {
          return;
        }
        setState(() {});
      }).catchError((Object e) {
        if (e is CameraException) {
          switch (e.code) {
            case 'CameraAccessDenied':
              print('User denied camera access.');
              break;
            default:
              print('Handle other errors.');
              break;
          }
        }
      });
    }
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(title: const Text('Barcode Scanner')),
        body: Column(
          children: [
            Expanded(
              child: MobileScanner(
                controller: MobileScannerController(
                  detectionSpeed: DetectionSpeed.normal,
                  facing: CameraFacing.back,
                  torchEnabled: false,
                ),
                onDetect: (capture) {
                  final barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty && barcodeResult == null) { // Only process if no barcode is currently being displayed
                    final code = barcodes.first.rawValue;
                    if (code != null) {
                      setState(() {
                        barcodeResult = code;
                        productInfo = 'Fetching product info...';
                      });
                      fetchProduct(code);
                    }
                    print('Barcode found! ${barcodes.first.rawValue}');
                  }
                },
              ),
            ),
            if (barcodeResult != null)
              Container(
                padding: const EdgeInsets.all(16.0),
                color: Colors.white,
                child: Column(
                  children: [
                    Text(
                      'Scanned Barcode: $barcodeResult',
                      style: const TextStyle(fontSize: 20, color: Colors.black),
                    ),
                    if (productInfo != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Product: $productInfo',
                          style: const TextStyle(fontSize: 18, color: Colors.black54),
                        ),
                      ),
                    if (ingredientsText != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Ingredients: $ingredientsText',
                          style: const TextStyle(fontSize: 16, color: Colors.black87),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (nutriments != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Column(
                          children: [
                            Text(
                              'Nutritional Value (per 100g):',
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                            ),
                            if (nutriments!['energy-kcal_100g'] != null) Text('Energy: ${nutriments!['energy-kcal_100g']} kcal'),
                            if (nutriments!['proteins_100g'] != null) Text('Proteins: ${nutriments!['proteins_100g']} ${nutriments!['proteins_unit'] ?? 'g'}'),
                            if (nutriments!['fat_100g'] != null) Text('Fat: ${nutriments!['fat_100g']} ${nutriments!['fat_unit'] ?? 'g'}'),
                            if (nutriments!['carbohydrates_100g'] != null) Text('Carbohydrates: ${nutriments!['carbohydrates_100g']} ${nutriments!['carbohydrates_unit'] ?? 'g'}'),
                            if (nutriments!['sugars_100g'] != null) Text('Sugars: ${nutriments!['sugars_100g']} ${nutriments!['sugars_unit'] ?? 'g'}'),
                            if (nutriments!['salt_100g'] != null) Text('Salt: ${nutriments!['salt_100g']} ${nutriments!['salt_unit'] ?? 'g'}'),
                          ],
                        ),
                      ),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          barcodeResult = null;
                          productInfo = null;
                          ingredientsText = null;
                          nutriments = null;
                        });
                      },
                      child: const Text('Scan New Barcode'),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
