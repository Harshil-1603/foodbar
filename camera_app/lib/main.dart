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
  bool _isLoading = false;
  bool _productNotFound = false;
  String? productImageUrl;
  List<String>? tracesTags;

  Future<void> fetchProduct(String barcode) async {
    setState(() {
      _isLoading = true;
      _productNotFound = false; // Reset on new scan
      productImageUrl = null; // Reset image on new scan
    });
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
          productImageUrl = product['image_front_url'] as String?;
          // Store traces_tags for internal use, not displayed on frontend
          if (product['traces_tags'] is List) {
            tracesTags = List<String>.from(product['traces_tags']);
          } else {
            tracesTags = null;
          }
        });
      } else {
        setState(() {
          productInfo = 'Product not found.';
          _productNotFound = true;
        });
      }
    } else {
      setState(() {
        productInfo = 'Error fetching product data.';
      });
    }
    setState(() {
      _isLoading = false;
    });
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
      title: 'Foodbar Scanner',
      theme: ThemeData(
        primarySwatch: Colors.lightBlue,
        colorScheme: ColorScheme.fromSwatch(primarySwatch: Colors.lightBlue).copyWith(
          secondary: Colors.amberAccent,
        ),
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.lightBlue,
          foregroundColor: Colors.white,
          centerTitle: true,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(15.0),
          ),
          elevation: 5,
          margin: const EdgeInsets.all(10.0),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            foregroundColor: Colors.white,
            backgroundColor: Colors.lightBlue,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10.0),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
            textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
      ),
      home: Scaffold(
        appBar: AppBar(title: const Text('Foodbar Scanner')),
        body: Stack(
          children: [
            Positioned.fill(
              child: MobileScanner(
                controller: MobileScannerController(
                  detectionSpeed: DetectionSpeed.normal,
                  facing: CameraFacing.back,
                  torchEnabled: false,
                ),
                onDetect: (capture) {
                  final barcodes = capture.barcodes;
                  if (barcodes.isNotEmpty && barcodeResult == null && !_isLoading) { // Only process if no barcode is currently being displayed and not loading
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
            if (barcodeResult == null && !_isLoading && !_productNotFound) // Display instruction overlay only when camera is active and nothing is scanned/loading/not found
              Positioned.fill(
                child: Container(
                  color: Colors.black.withOpacity(0.6),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Icon(Icons.qr_code_scanner, color: Colors.white, size: 80), // Changed icon for clarity
                      SizedBox(height: 20),
                      Text(
                        'Scan a barcode to get product info',
                        style: TextStyle(fontSize: 22, color: Colors.white, fontWeight: FontWeight.bold),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 10),
                      Text(
                        'Align the barcode within the camera frame.',
                        style: TextStyle(fontSize: 16, color: Colors.white70),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Column(
                children: [
                  if (_isLoading)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: CircularProgressIndicator(),
                    ) // Show loading indicator
                  else if (barcodeResult != null)
                    Card(
                      margin: const EdgeInsets.all(16.0),
                      elevation: 4.0,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (productImageUrl != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 10.0),
                                child: Image.network(
                                  productImageUrl!,
                                  height: 150,
                                  fit: BoxFit.contain,
                                  errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image, size: 100, color: Colors.grey),
                                ),
                              ),
                            Text(
                              'Scanned Barcode: $barcodeResult',
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                            ),
                            const SizedBox(height: 10),
                            if (productInfo != null)
                              Text(
                                'Product: $productInfo',
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: Colors.black87),
                              ),
                            const SizedBox(height: 10),
                            if (ingredientsText != null)
                              SizedBox(
                                height: 100, // Fixed height for ingredients list
                                child: SingleChildScrollView(
                                  child: Text(
                                    'Ingredients:\n$ingredientsText',
                                    style: const TextStyle(fontSize: 16, color: Colors.black54),
                                    textAlign: TextAlign.start,
                                  ),
                                ),
                              ),
                            const SizedBox(height: 10),
                            if (nutriments != null)
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Nutritional Value (per 100g):',
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black),
                                  ),
                                  if (nutriments!['energy-kcal_100g'] != null) 
                                    ListTile(
                                      dense: true,
                                      title: const Text('Energy'),
                                      trailing: Text('${nutriments!['energy-kcal_100g']} kcal'),
                                    ),
                                  if (nutriments!['proteins_100g'] != null)
                                    ListTile(
                                      dense: true,
                                      title: const Text('Proteins'),
                                      trailing: Text('${nutriments!['proteins_100g']} ${nutriments!['proteins_unit'] ?? 'g'}'),
                                    ),
                                  if (nutriments!['fat_100g'] != null)
                                    ListTile(
                                      dense: true,
                                      title: const Text('Fat'),
                                      trailing: Text('${nutriments!['fat_100g']} ${nutriments!['fat_unit'] ?? 'g'}'),
                                    ),
                                  if (nutriments!['carbohydrates_100g'] != null)
                                    ListTile(
                                      dense: true,
                                      title: const Text('Carbohydrates'),
                                      trailing: Text('${nutriments!['carbohydrates_100g']} ${nutriments!['carbohydrates_unit'] ?? 'g'}'),
                                    ),
                                  if (nutriments!['sugars_100g'] != null)
                                    ListTile(
                                      dense: true,
                                      title: const Text('Sugars'),
                                      trailing: Text('${nutriments!['sugars_100g']} ${nutriments!['sugars_unit'] ?? 'g'}'),
                                    ),
                                  if (nutriments!['salt_100g'] != null)
                                    ListTile(
                                      dense: true,
                                      title: const Text('Salt'),
                                      trailing: Text('${nutriments!['salt_100g']} ${nutriments!['salt_unit'] ?? 'g'}'),
                                    ),
                                ],
                              ),
                            const SizedBox(height: 20),
                            Center(
                              child: ElevatedButton(
                                onPressed: () {
                                  setState(() {
                                    barcodeResult = null;
                                    productInfo = null;
                                    ingredientsText = null;
                                    nutriments = null;
                                    _productNotFound = false; // Reset when scanning new barcode
                                    productImageUrl = null; // Clear image on new scan
                                    tracesTags = null; // Clear tracesTags on new scan
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Theme.of(context).colorScheme.primary,
                                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10.0),
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                                  textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                                child: const Text('Scan New Barcode'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (_productNotFound)
                    Card(
                      margin: const EdgeInsets.all(16.0),
                      elevation: 4.0,
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Column(
                          children: const [
                            Icon(Icons.warning_amber, color: Colors.orange, size: 40),
                            SizedBox(height: 10),
            Text(
                              'No product found for this barcode.',
                              style: TextStyle(fontSize: 18, color: Colors.orange),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
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
