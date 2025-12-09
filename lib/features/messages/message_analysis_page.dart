
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';

import '../../services/message_analysis_service.dart';

class MessageAnalysisPage extends StatefulWidget {
  const MessageAnalysisPage({super.key});

  @override
  _MessageAnalysisPageState createState() => _MessageAnalysisPageState();
}

class _MessageAnalysisPageState extends State<MessageAnalysisPage> {
  final TextEditingController _controller = TextEditingController();

  Future<void> _analyze() async {
    final l10n = AppLocalizations.of(context)!;
    final analysisService = Provider.of<MessageAnalysisService>(context, listen: false);
    if (_controller.text.isNotEmpty) {
      try {
        await analysisService.analyzeMessage(_controller.text);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.analysisError(e.toString()))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final analysisService = Provider.of<MessageAnalysisService>(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.messageAnalysis),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _controller,
              decoration: InputDecoration(
                labelText: l10n.enterMessageHint,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _analyze,
              child: Text(l10n.analyze),
            ),
            const SizedBox(height: 16),
            if (analysisService.isLoading)
              const CircularProgressIndicator()
            else if (analysisService.analysisResult != null)
              Expanded(
                child: ListView(
                  children: [
                    Text(
                      l10n.analysisResults,
                      style: Theme.of(context).textTheme.headline6,
                    ),
                    const SizedBox(height: 8),
                    Text(analysisService.analysisResult!),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
