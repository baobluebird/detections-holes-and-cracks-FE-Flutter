import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:safe_street/ipconfig/ip.dart';
import 'package:safe_street/screens/detection.dart';
import 'package:http/http.dart' as http;
import '../model/detection.dart';
import '../services/detection_service.dart';
import 'package:intl/intl.dart';

import 'detection_for_detail.dart';

class CrackScreen extends StatefulWidget {
  const CrackScreen({Key? key}) : super(key: key);

  @override
  State<CrackScreen> createState() => _CrackScreenState();
}

class _CrackScreenState extends State<CrackScreen> {
  List<dynamic>? _detections;
  late Detection? detection;
  int total = 0;

  Future<void> _getListCarDuringParking() async {
    final Map<String, dynamic> response = await getListCracksService.getListCracks();
    if (response['status'] == 'OK') {
      if (response['data'] is String && response['data'] == 'null') {
        setState(() {
          _detections = [];
        });
      } else {
        setState(() {
          _detections = response['data'];
          total = response['total'];
        });
      }
    } else {
      print('Error occurred: ${response['message']}');
    }
  }

  Future<void> _getDetailCrack(String id) async {
    final Map<String, dynamic> response = await getDetailCrackService.getDetailCrack(id);
    if (response['status'] == 'OK') {
      final Map<String, dynamic> detectionData = response['data'];
      detection = Detection.fromJson(detectionData);

      String? imageData; // Đổi imageData thành kiểu String có thể null
      if (response['image'] != null) {
        imageData = response['image'];
      }
      if (imageData != null) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => DetectionForDetailScreen(
              detection: detection,
              imageData: imageData!,
            ),
          ),
        );
      }
    } else {
      print('Error occurred: ${response['message']}');
    }
  }

  Future<void> _deleteCrack(String id) async {
    final response = await http.delete(
      Uri.parse('$ip/detection/delete-crack/$id'),
    );

    if (response.statusCode == 200) {
      setState(() {
        _detections!.removeWhere((crack) => crack['_id'] == id);
        total--;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Crack deleted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete crack.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _getListCarDuringParking();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _detections == null
          ? const Center(child: CircularProgressIndicator())
          : _detections!.isEmpty
          ? const Center(child: Text('No detection available'))
          : ListView.builder(
        itemCount: _detections!.length,
        itemBuilder: (BuildContext context, int index) {
          final crack = _detections![index];
          return GestureDetector(
            onTap: () {
              _getDetailCrack(crack['_id']);
            },
            child: Container(
              margin: const EdgeInsets.all(8.0),
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.blue),
                borderRadius: BorderRadius.circular(8.0),
              ),
              child: Row(
                children: [
                  Image.network(
                    crack['image'],
                    width: 50,
                    height: 50,
                    errorBuilder: (context, error, stackTrace) {
                      return const Icon(Icons.error);
                    },
                  ),
                  const SizedBox(width: 10), // thêm khoảng trống giữa hình ảnh và thông tin
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Id Crack: ${crack['_id']}'),
                        Text('User Id post: ${crack['user']}'),
                        Text('Location: ${crack['location']}'),
                        Text('Address: ${crack['address']}'),
                        Text('Description: ${crack['description']}'),
                        Text('Time detect: ${DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.parse(crack['createdAt']))}'),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      _deleteCrack(crack['_id']);
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (BuildContext context) {
              return AlertDialog(
                title: const Text('Total Cracks'),
                content: Text('Total number of cracks: $total'),
                actions: <Widget>[
                  TextButton(
                    child: const Text('OK'),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              );
            },
          );
        },
        child: const Icon(Icons.info),
      ),
    );
  }
}
