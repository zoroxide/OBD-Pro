import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
// import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import '../models/obd_model.dart';
import '../core/ai_service.dart';

class AIPage extends StatefulWidget {
  const AIPage({super.key});

  @override
  State<AIPage> createState() => _AIPageState();
}

class _AIPageState extends State<AIPage> {
  bool _loading = false;
  String? _result;
  // Enable Gemini "thinking" by default per user request.
  final bool _thinkingMode = true;
  String _language = 'English';
  String _expertise = 'Simple'; // Simple | Enthusiast | Expert

  Future<void> _analyze() async {
    final model = Provider.of<OBDModel>(context, listen: false);
    final dtcs = model.dtcs;
    final values = Map<String, dynamic>.from(model.values);

    final prompt = StringBuffer();

    if (dtcs.isEmpty) {
      // When there are no DTCs, ask the model to introduce itself and say a useful OBD fact
      prompt.writeln(
        'Hello AI, please introduce yourself briefly (1-2 sentences) and then state one interesting, concise fact about OBD-II diagnostics that a car owner might find useful.',
      );
      // include a tiny context of available live values so the assistant knows there is no fault data
      prompt.writeln(
        '\nNote: there are currently no DTCs recorded for this vehicle.',
      );
      prompt.writeln('\nLive snapshot:');
      values.forEach((k, v) => prompt.writeln('- $k: $v'));
    } else {
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
    }

    setState(() {
      _loading = true;
      _result = null;
    });

    try {
      final geminiKey = 'AIzaSyBxyd5wKIP3BMaQJfIVSkY5WS5mB8j-h0M';

      final systemInstr = StringBuffer();
      systemInstr.writeln(
        'You are a car mechanic and an expert in vehicle diagnostics. Be concise and explain in simple terms.',
      );
      // Add language preference to system instruction
      final langLabel = _language == 'Egyptian Arabic'
          ? 'Egyptian Arabic (colloquial)'
          : _language;
      systemInstr.writeln('Respond in $langLabel.');

      // Tailor explanation depth based on user-selected expertise.
      switch (_expertise) {
        case 'Simple':
          systemInstr.writeln(
            'Audience level: Beginner driver with no mechanical background. Avoid jargon; define any technical term briefly. Provide clear, actionable next steps they can safely attempt and highlight when professional help is required.',
          );
          break;
        case 'Enthusiast':
          systemInstr.writeln(
            'Audience level: Car enthusiast familiar with basic tools and common components. Provide moderate technical detail, list probable causes ordered by likelihood, include DIY diagnostic checks and when escalation is needed.',
          );
          break;
        case 'Expert':
          systemInstr.writeln(
            'Audience level: Professional technician. Use precise automotive terminology. Provide detailed diagnostic pathways, underlying subsystem interactions, typical failure modes, recommended test values/pids, and advanced verification steps.',
          );
          break;
      }

      final ai = AIService(apiKey: geminiKey);
      final resp = await ai.generateContent(
        systemInstruction: systemInstr.toString(),
        prompt: prompt.toString(),
        model: 'gemini-2.5-pro',
        enableThinking: _thinkingMode,
        thinkingBudget: -1,
        enableWebSearch: true,
      );

      if (!mounted) return;
      setState(() => _result = resp['text']?.toString() ?? '');
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
            Row(
              children: [
                const Text('Response language:'),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _language,
                  items: const [
                    DropdownMenuItem(value: 'English', child: Text('English')),
                    DropdownMenuItem(value: 'Arabic', child: Text('Arabic')),
                    DropdownMenuItem(
                      value: 'Egyptian Arabic',
                      child: Text('Egyptian Arabic'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _language = v ?? 'English'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Mode:'),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: _expertise,
                  items: const [
                    DropdownMenuItem(value: 'Simple', child: Text('Simple')),
                    DropdownMenuItem(
                      value: 'Enthusiast',
                      child: Text('Enthusiast'),
                    ),
                    DropdownMenuItem(value: 'Expert', child: Text('Expert')),
                  ],
                  onChanged: (v) => setState(() => _expertise = v ?? 'Simple'),
                ),
              ],
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
                      child: _result == null || _result!.isEmpty
                          ? const SizedBox.shrink()
                          : MarkdownBody(data: _result ?? ''),
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
