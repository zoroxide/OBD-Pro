import 'package:dio/dio.dart';

class AIService {
  final Dio _dio;
  final String? apiKey;

  AIService({Dio? dio, this.apiKey}) : _dio = dio ?? Dio();

  /// Generate content from Gemini (GenerateContent)
  /// Returns a map with keys: 'text' (String), 'raw' (original response), 'grounding' (if present)
  Future<Map<String, dynamic>> generateContent({
    required String systemInstruction,
    required String prompt,
    String model = 'gemini-2.5-pro',
    bool enableThinking = true,
    int thinkingBudget = -1,
    bool enableWebSearch = true,
  }) async {
    final body = <String, dynamic>{
      'systemInstruction': {
        'parts': [
          {'text': systemInstruction},
        ],
      },
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
    };

    if (enableWebSearch) {
      body['tools'] = [
        {'googleSearch': {}},
      ];
    }

    if (enableThinking) {
      body['generationConfig'] = {
        'thinkingConfig': {'thinkingBudget': thinkingBudget},
      };
    }

    _dio.options.headers['Content-Type'] = 'application/json';
    if (apiKey != null) _dio.options.headers['x-goog-api-key'] = apiKey;

    final url =
        'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent';
    final res = await _dio.post(url, data: body);
    final data = res.data;

    String extractText(dynamic data) {
      if (data == null) return '';

      // candidates -> content -> parts -> text
      if (data is Map && data['candidates'] != null) {
        final candidates = data['candidates'];
        if (candidates is List && candidates.isNotEmpty) {
          final sb = StringBuffer();
          for (final c in candidates) {
            if (c is Map) {
              final content = c['content'];
              if (content is Map && content['parts'] is List) {
                for (final p in content['parts']) {
                  if (p is Map && p['text'] != null) {
                    sb.writeln(p['text'].toString());
                  }
                }
              } else if (content is List) {
                for (final item in content) {
                  if (item is Map) {
                    if (item['parts'] is List) {
                      for (final p in item['parts']) {
                        if (p is Map && p['text'] != null) {
                          sb.writeln(p['text'].toString());
                        }
                      }
                    } else if (item['text'] != null) {
                      sb.writeln(item['text'].toString());
                    }
                  }
                }
              }

              // fallback to output.content
              if (c['output'] is Map) {
                final out = c['output'];
                if (out['content'] is List) {
                  for (final o in out['content']) {
                    if (o is Map && o['text'] != null) {
                      sb.writeln(o['text'].toString());
                    }
                  }
                }
              }
            }
          }
          final s = sb.toString().trim();
          if (s.isNotEmpty) return s;
        }
      }

      // older style: output -> content -> text
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

    final text = extractText(data);
    dynamic grounding;
    try {
      grounding = data['candidates']?[0]?['groundingMetadata'];
    } catch (_) {
      grounding = null;
    }

    return {'text': text, 'raw': data, 'grounding': grounding};
  }
}
