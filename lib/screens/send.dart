import 'package:camera/camera.dart';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocode/geocode.dart';
import 'package:path_provider/path_provider.dart';
import '../components/list.dart';
import '../model/detection.dart';
import '../services/upload_service.dart';
import 'detection.dart';
import 'package:image/image.dart' as Img;

const styleUrl =
    "https://tiles.stadiamaps.com/tiles/alidade_smooth_dark/{z}/{x}/{y}{r}.png";
const apiKey = "bcc0c4b5-37fb-4c61-a683-34ce8700b556";

class SendScreen extends StatefulWidget {
  final List<CameraDescription>? cameras;

  const SendScreen({this.cameras, Key? key}) : super(key: key);

  @override
  State<SendScreen> createState() => _SendScreenState();
}

class _SendScreenState extends State<SendScreen> {
  GeoCode geoCode = GeoCode();
  CameraController? _controller;
  XFile? _pictureFile;
  bool _showImage = false;
  bool _isFlashOn = false; // Add this line
  Position? currentPosition;
  LatLng? _currentLatLng;
  String? _selectedTypeDetection;
  late Detection detection;
  String _userId = '';
  final myBox = Hive.box('myBox');
  late String storedToken;

  String serverMessage = '';
  bool _isLoading = false;

  // Add this method
  void _toggleFlash() {
    if (_controller != null && _controller!.value.isInitialized) {
      setState(() {
        _isFlashOn = !_isFlashOn;
        _controller!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
      });
    }
  }

  Future<void> clearHiveBox(String boxName) async {
    var box = await Hive.openBox(boxName);
    await box.clear();
  }

  Future<Uint8List> compressImage(File file) async {
    Uint8List imageData = await file.readAsBytes();

    Img.Image image = Img.decodeImage(imageData)!;
    Img.Image resizedImage = Img.copyResize(image, width: image.width ~/ 2);

    Uint8List compressedImageData = Uint8List.fromList(Img.encodePng(resizedImage));

    return compressedImageData;
  }

  Future<void> _initCamera() async {
    final cameras = await availableCameras();
    final firstCamera = cameras.first;
    _controller = CameraController(
      firstCamera,
      ResolutionPreset.max,
    );
    _controller!.initialize().then((_) {
      if (!mounted) {
        return;
      }
      // Update the flash mode based on the _isFlashOn variable
      _controller!.setFlashMode(_isFlashOn ? FlashMode.torch : FlashMode.off);
      setState(() {});
    }).catchError((error) {
      print('Camera initialization error: $error');
    });
  }

  Future<File> _createTempFile(Uint8List imageData) async {
    final tempDir = await getTemporaryDirectory();
    final tempPath = tempDir.path;
    final tempFile = File('$tempPath/temp_image.png');
    await tempFile.writeAsBytes(imageData);
    return tempFile;
  }

  Future<void> _upload() async {
    await _getLocation();
    if (_pictureFile != null &&
        _selectedTypeDetection != null &&
        _currentLatLng != null) {
      final File image = File(_pictureFile!.path);
      Uint8List compressedImageData = await compressImage(image);
      final File compressedImageFile = await _createTempFile(compressedImageData);
      final Map<String, dynamic> response = await UploadService.uploadImage(
          compressedImageFile,
          _userId,
          _selectedTypeDetection!,
          _currentLatLng.toString()
      );
      print('Response status: ${response['status']}');
      print('Response data: ${response['data']}');
      print('Response message: ${response['message']}');
      if (response['status'] == "OK") {
        serverMessage = response['message'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(serverMessage),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.green,
          ),
        );
        final Map<String, dynamic> detectionData = response['data'];
        detection = Detection.fromJson(detectionData);
        print('image: ${response['image']}');
        String byteData = '';
        if (response['image'] != null) {
          byteData = response['image'];
        }

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => DetectionScreen(
              detection: detection,
              imageData: byteData,
            ),
          ),
        );
      } else {
        serverMessage = response['message'];
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(serverMessage),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.red,
          ),
        );
      }
    } else {
      if (_selectedTypeDetection == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select a type of detection.'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.red,
          ),
        );
      }
      if (_pictureFile == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please select or take a picture.'),
            duration: Duration(seconds: 1),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> getImageFromGallery() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);
    setState(() {
      _pictureFile = XFile(pickedFile!.path);
      _showImage = true;
    });
  }

  Future<void> _getLocation() async {
    try {
      Position position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.best
      ).timeout(Duration(seconds: 5));
      setState(() {
        _currentLatLng = LatLng(position.latitude, position.longitude);
      });

      if (kDebugMode) {
        print(
            'Latitude: ${position.latitude}, Longitude: ${position.longitude}'
        );
      }
    } catch (e) {
      print("Error getting current location: $e");
    }
  }

  @override
  void initState() {
    super.initState();
    _initCamera();
    _userId = myBox.get('userId', defaultValue: '');
    if (widget.cameras != null && widget.cameras!.isNotEmpty) {
      _controller = CameraController(
        widget.cameras![0],
        ResolutionPreset.max,
      );
      _controller!.initialize().then((_) {
        if (!mounted) {
          return;
        }
        setState(() {});
      }).catchError((error) {
        if (kDebugMode) {
          print('Camera initialization error: $error');
        }
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  void deactivate() {
    super.deactivate();
    _controller?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBodyWithMap(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildBodyWithMap() {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Send Detection'),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: Center(
                child: SizedBox(
                  height: 400,
                  width: 400,
                  child: _controller != null && _controller!.value.isInitialized
                      ? CameraPreview(_controller!)
                      : const CircularProgressIndicator(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          if (_controller != null &&
                              _controller!.value.isInitialized) {
                            setState(() {
                              _showImage = false;
                            });

                            try {
                              final pictureFile =
                              await _controller!.takePicture();
                              setState(() {
                                _pictureFile = pictureFile;
                                _showImage = true;
                              });
                            } on CameraException catch (e) {
                              print('Error taking picture: $e');
                            }
                          }
                        },
                        child: const Text('Capture Image'),
                      ),
                      ElevatedButton(
                        onPressed: getImageFromGallery,
                        child: const Text('Gallery'),
                      ),
                      ElevatedButton(
                        onPressed: _toggleFlash,
                        child: Text(_isFlashOn ? 'Flash On' : 'Flash Off'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: SizedBox(
                    width: MediaQuery.of(context).size.width * 0.8,
                    child: DropdownButton<String>(
                      isExpanded: true,
                      hint: const Text('Chọn loại hư hỏng đường'),
                      value: _selectedTypeDetection,
                      onChanged: (String? newValue) {
                        setState(() {
                          _selectedTypeDetection = newValue;
                        });
                      },
                      items: listTypeCar
                          .map<DropdownMenuItem<String>>((String value) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
            if (_showImage && _pictureFile != null)
              Column(
                children: [
                  Image.file(
                    File(_pictureFile!.path),
                    height: 200,
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        _showImage = false;
                        _pictureFile = null;
                      });
                    },
                    child: Text('Clear Image'),
                  ),
                ],
              ),
            const SizedBox(height: 10),
            Stack(
              children: [
                ElevatedButton(
                  onPressed: () async {
                    if (!_isLoading) {
                      setState(() {
                        _isLoading = true;
                      });
                      await _upload();
                      setState(() {
                        _isLoading = false;
                      });
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content:
                          Text('Please fill in all fields and choose image!'),
                          duration: Duration(seconds: 2),
                          backgroundColor: Colors.red,
                        ),
                      );
                    }
                  },
                  child: const Text('Upload'),
                ),
                if (_isLoading)
                  Positioned.fill(
                    child: Container(
                      color: Colors.black.withOpacity(0.5),
                      child: Center(
                        child: CircularProgressIndicator(),
                      ),
                    ),
                  ),
              ],
            )
          ],
        ),
      ),
    );
  }
}
