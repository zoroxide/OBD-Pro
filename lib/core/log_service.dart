// core/log_service.dart
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';

class LogService {
  /// Save logs (list of map rows or list of lists) as CSV and return path
  Future<String> saveCsvFromRows(
    List<List<dynamic>> rows, {
    String? filenamePrefix,
  }) async {
    final dir = await _getExportDirectory();
    final now = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filename = '${filenamePrefix ?? "obd_log"}_$now.csv';
    final file = File('${dir.path}/$filename');
    final csv = const ListToCsvConverter().convert(rows);
    await file.writeAsString(csv);
    return file.path;
  }

  Future<Directory> _getExportDirectory() async {
    Directory base;
    if (Platform.isAndroid) {
      base = (await getExternalStorageDirectory())!;
      // On Android the path might be something like /storage/emulated/0/Android/data/...
      // We'll place logs in the app external dir which is accessible via USB MTP
      final exportDir = Directory('${base.path}/OBD_Logs');
      if (!(await exportDir.exists())) await exportDir.create(recursive: true);
      return exportDir;
    } else {
      base = await getApplicationDocumentsDirectory();
      final exportDir = Directory('${base.path}/OBD_Logs');
      if (!(await exportDir.exists())) await exportDir.create(recursive: true);
      return exportDir;
    }
  }
}
