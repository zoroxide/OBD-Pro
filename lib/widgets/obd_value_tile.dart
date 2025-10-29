import 'package:flutter/material.dart';

class OBDValueTile extends StatelessWidget {
  final String name;
  final dynamic value;

  const OBDValueTile(this.name, this.value, {super.key});

  @override
  Widget build(BuildContext context) {
    final display = value == null
        ? '--'
        : (value is double ? value.toStringAsFixed(1) : value.toString());

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              name,
              style: const TextStyle(fontSize: 13, color: Colors.grey),
            ),
            const SizedBox(height: 8),
            Text(
              display,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
