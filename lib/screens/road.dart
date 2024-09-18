import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:safe_street/ipconfig/ip.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import 'package:safe_street/screens/road_detail.dart';

class MaintainRoadScreen extends StatefulWidget {
  const MaintainRoadScreen({Key? key}) : super(key: key);

  @override
  State<MaintainRoadScreen> createState() => _MaintainRoadState();
}

class _MaintainRoadState extends State<MaintainRoadScreen> {
  List<dynamic>? _maintainRoads;
  int _total = 0;

  Future<void> _fetchData() async {
    var url = Uri.parse('$ip/detection/get-maintain-road');
    var response = await http.get(url);

    if (response.statusCode == 200) {
      final data = json.decode(response.body)['data'];
      setState(() {
        _maintainRoads = data;
        _total = data.length;
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to fetch routes from server')));
    }
  }

  Future<void> _deleteMaintainRoad(String id) async {
    final response = await http.delete(
      Uri.parse('$ip/detection/delete-maintain/$id'),
    );

    if (response.statusCode == 200) {
      setState(() {
        _maintainRoads!.removeWhere((road) => road['_id'] == id);
        _total--;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Maintain road deleted successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete maintain road.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _maintainRoads == null
          ? const Center(child: CircularProgressIndicator())
          : _maintainRoads!.isEmpty
          ? const Center(child: Text('No maintain roads available'))
          : ListView.builder(
        itemCount: _maintainRoads!.length,
        itemBuilder: (BuildContext context, int index) {
          final road = _maintainRoads![index];
          return GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MaintainRoadDetailScreen(
                    sourceName: road['sourceName'],
                    destinationName: road['destinationName'],
                    locationA: _parseLatLng(road['locationA']),
                    locationB: _parseLatLng(road['locationB']),
                    dateMaintain: road['dateMaintain'],
                    createdAt: road['createdAt'],
                    updatedAt: road['updatedAt'],
                  ),
                ),
              );
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
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Source: ${road['sourceName']}'),
                        Text('Destination: ${road['destinationName']}'),
                        Text('Location A: ${road['locationA']}'),
                        Text('Location B: ${road['locationB']}'),
                        Text('Date Maintain: ${road['dateMaintain']} days ${DateFormat('yyyy/MM/dd ').format(DateTime.parse(road['createdAt']))} - ${DateFormat('yyyy/MM/dd ').format(DateTime.parse(road['updatedAt']))}'),

                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () {
                      _deleteMaintainRoad(road['_id']);
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
                title: const Text('Total Maintain Roads'),
                content: Text('Total number of maintain roads: $_total'),
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

  LatLng _parseLatLng(String latLngString) {
    final parts = latLngString.replaceAll('LatLng(', '').replaceAll(')', '').split(',');
    return LatLng(double.parse(parts[0]), double.parse(parts[1]));
  }
}
