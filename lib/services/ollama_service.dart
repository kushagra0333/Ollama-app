import 'dart:convert';
import 'package:http/http.dart' as http;

class OllamaService {
  final String baseUrl = 'http://127.0.0.1:11434/api';

  Future<bool> checkStatus() async {
    try {
      final response = await http.get(Uri.parse('http://127.0.0.1:11434/'));
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }

  Future<List<String>> getModels() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/tags'));
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final models = (data['models'] as List)
            .map((model) => model['name'] as String)
            .toList();
        return models;
      }
    } catch (e) {
      print('Error fetching models: $e');
    }
    return [];
  }

  Stream<String> generateResponse(String model, String prompt) async* {
    final request = http.Request('POST', Uri.parse('$baseUrl/generate'))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({
        'model': model,
        'prompt': prompt,
      });

    try {
      final response = await http.Client().send(request);
      
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        // Ollama streams JSON lines
        final lines = chunk.split('\n');
        for (final line in lines) {
          if (line.trim().isEmpty) continue;
          
          try {
            final data = jsonDecode(line);
            if (data['response'] != null) {
              yield data['response'];
            }
          } catch (e) {
            print('Error parsing stream chunk: $e');
          }
        }
      }
    } catch (e) {
      print('Error generating response: $e');
      yield '\n\n[Connection Error: Ensure Ollama is running]';
    }
  }

  /// Pulls a model from the Ollama library, yielding fractional progress (0.0 to 1.0)
  Stream<double> pullModel(String name) async* {
    final request = http.Request('POST', Uri.parse('\$baseUrl/pull'))
      ..headers['Content-Type'] = 'application/json'
      ..body = jsonEncode({'name': name});

    try {
      final response = await http.Client().send(request);
      
      await for (final chunk in response.stream.transform(utf8.decoder)) {
        final lines = chunk.split('\n');
        for (final line in lines) {
          if (line.trim().isEmpty) continue;
          
          try {
            final data = jsonDecode(line);
            if (data['status'] == 'success') {
              yield 1.0;
            } else if (data['total'] != null && data['completed'] != null) {
              final total = data['total'] as int;
              final completed = data['completed'] as int;
              if (total > 0) {
                yield completed / total;
              }
            }
          } catch (e) {
            print('Error parsing pull stream chunk: $e');
          }
        }
      }
    } catch (e) {
      print('Error pulling model: $e');
      yield -1.0; // Signal failure
    }
  }
}
