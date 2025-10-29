import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import '../models/obd_model.dart';

class AIPage extends StatefulWidget {
  const AIPage({super.key});

  @override
  State<AIPage> createState() => _AIPageState();
}

class _AIPageState extends State<AIPage> {
  bool _loading = false;
  String? _result;
  bool _thinkingMode = false;

  Future<void> _analyze() async {
    final model = Provider.of<OBDModel>(context, listen: false);
    final dtcs = model.dtcs;
    final values = Map<String, dynamic>.from(model.values);

    if (dtcs.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('No DTCs to analyze')));
      return;
    }

    final prompt = StringBuffer();
    prompt.writeln(
      'You are a car mechanic and there\'s someone who needs your help.',
    );
    prompt.writeln(
      'I will give you this car owner\'s OBD-II DTCs and a snapshot of live data from their stationary car.',
    );
    prompt.writeln(
      'Please help them using this data, explain simply what each DTC likely means, and state whether it is critical to visit a mechanic.',
    );
    prompt.writeln('\nDTCs:');
    for (final d in dtcs) {
      prompt.writeln('- $d');
    }
    prompt.writeln('\nLive snapshot:');
    values.forEach((k, v) => prompt.writeln('- $k: $v'));

    setState(() {
      _loading = true;
      _result = null;
    });

    try {
      final dio = Dio();

      final geminiKey = 'AIzaSyBxyd5wKIP3BMaQJfIVSkY5WS5mB8j-h0M';

      dio.options.headers['Content-Type'] = 'application/json';
      dio.options.headers['x-goog-api-key'] = geminiKey;

      final systemInstr = StringBuffer();
      systemInstr.writeln(
        'You are a car mechanic and an expert in vehicle diagnostics. Be concise and explain in simple terms.',
      );

      final body = <String, dynamic>{
        'system_instruction': {
          'parts': [
            {'text': systemInstr.toString()},
          ],
        },
        'contents': [
          {
            'parts': [
              {'text': prompt.toString()},
            ],
          },
        ],
      };

      if (_thinkingMode) {
        body['generationConfig'] = {
          'thinkingConfig': {'thinkingBudget': 0},
        };
      }

      final url =
          'https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-pro:generateContent';
      final res = await dio.post(url, data: body);
      final data = res.data;

      String extractFromGemini(dynamic data) {
        if (data == null) return '';
        if (data is Map && data['candidates'] != null) {
          final candidates = data['candidates'];
          if (candidates is List && candidates.isNotEmpty) {
            final sb = StringBuffer();
            for (final c in candidates) {
              if (c is Map) {
                if (c['content'] is List) {
                  for (final part in c['content']) {
                    if (part is Map && part['text'] != null) {
                      sb.writeln(part['text'].toString());
                    }
                    if (part is Map &&
                        part['type'] == 'output_text' &&
                        part['text'] != null) {
                      sb.writeln(part['text'].toString());
                    }
                  }
                }
                if (c['output'] is Map && c['output']['content'] is List) {
                  for (final part in c['output']['content']) {
                    if (part is Map && part['text'] != null) {
                      sb.writeln(part['text'].toString());
                    }
                  }
                }
              }
            }
            final s = sb.toString().trim();
            if (s.isNotEmpty) return s;
          }
        }

        if (data is Map && data['output'] != null) {
          final output = data['output'];
          if (output is List && output.isNotEmpty) {
            final first = output.first;
            if (first is Map && first['content'] is List) {
              final sb = StringBuffer();
              for (final c in first['content']) {
                if (c is Map && c['text'] != null) {
                  sb.writeln(c['text'].toString());
                }
              }
              final s = sb.toString().trim();
              if (s.isNotEmpty) return s;
            }
          }
        }

        if (data is List) return data.join('\n');
        return data.toString();
      }

      final text = extractFromGemini(data);
      if (!mounted) return;
      setState(() => _result = text);
    } catch (e) {
      if (!mounted) return;
      setState(() => _result = 'Error: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI Assistant')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CheckboxListTile(
              value: _thinkingMode,
              onChanged: (v) => setState(() => _thinkingMode = v ?? false),
              title: const Text('Enable thinking mode (Gemini)'),
              subtitle: const Text(
                'When enabled, Gemini will run its internal thinking (may increase latency).',
              ),
            ),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _loading ? null : _analyze,
              child: _loading
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        SizedBox(width: 8),
                        Text('Thinking...'),
                      ],
                    )
                  : const Text('Analyze DTCs'),
            ),
            const SizedBox(height: 12),
            if (_result != null) ...[
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      // limit height to half the screen so very long outputs scroll
                      maxHeight: MediaQuery.of(context).size.height * 0.5,
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(_result ?? ''),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Copy output',
                    icon: const Icon(Icons.copy),
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: _result ?? ''));
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    },
                  ),
                  IconButton(
                    tooltip: 'Clear',
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(() => _result = null),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
