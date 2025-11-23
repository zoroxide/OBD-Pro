// core/log_service.dart
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:csv/csv.dart';
import 'package:permission_handler/permission_handler.dart';

class LogService {
  /// Save logs (list of map rows or list of lists) as CSV and return path
  Future<String> saveCsvFromRows(
    List<List<dynamic>> rows, {
    String? filenamePrefix,
  }) async {
    // Android storage permission compatibility:
    // - App-specific external dir (getExternalStorageDirectory) usually does NOT
    //   require permissions on modern Android (scoped storage), but older devices do.
    // - If user grants MANAGE_EXTERNAL_STORAGE (Android 11+), save to Download/OBD_Logs
    //   for easier user access.
    // - Fallback to requesting legacy storage permission.
    if (Platform.isAndroid) {
      // Try broad manage external storage first (only meaningful on API >=30).
      final manageStatus = await Permission.manageExternalStorage.status;
      if (!manageStatus.isGranted) {
        // Request if denied (will silently fail on older APIs and just be not granted).
        await Permission.manageExternalStorage.request();
      }

      // If broad access not granted, request legacy storage (READ/WRITE external).
      if (!await Permission.manageExternalStorage.isGranted) {
        final storageStatus = await Permission.storage.status;
        if (!storageStatus.isGranted) {
          final storageResult = await Permission.storage.request();
          if (!storageResult.isGranted) {
            // We still can write to app-specific external dir without permission on newer devices.
            // But if this is an older device that required permission, warn the caller.
            // We do not throw immediately; we proceed but caller can catch and notify user.
            // To force error uncomment next line.
            // throw Exception('Storage permission denied; cannot export CSV.');
          }
        }
      }
    }
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
      // If user granted broad external storage access, prefer common Download location.
      if (await Permission.manageExternalStorage.isGranted) {
        final downloads = Directory('/storage/emulated/0/Download/OBD_Logs');
        if (!(await downloads.exists())) {
          await downloads.create(recursive: true);
        }
        return downloads;
      }
      // Fallback: app-specific external directory (may be under Android/data/...)
      base = (await getExternalStorageDirectory())!;
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
