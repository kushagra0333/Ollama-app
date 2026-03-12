import 'dart:io';

class SystemService {
  /// Checks if the 'ollama' binary exists in the user's PATH
  Future<bool> checkOllamaInstalled() async {
    try {
      final result = await Process.run('which', ['ollama']);
      return result.exitCode == 0 && result.stdout.toString().trim().isNotEmpty;
    } catch (e) {
      print('Error checking if Ollama is installed: $e');
      return false;
    }
  }

  /// Triggers the official Ollama Linux installer script via pkexec 
  /// (prompts user for their sudo password in a graphical window)
  Future<bool> installOllama() async {
    try {
      // Create a temporary script to run the installer
      final tempFile = File('/tmp/install_ollama.sh');
      await tempFile.writeAsString('''#!/bin/bash
curl -fsSL https://ollama.com/install.sh | sh
''');
      await Process.run('chmod', ['+x', '/tmp/install_ollama.sh']);

      // Use pkexec to get a graphical sudo prompt and run the script
      final result = await Process.start('pkexec', ['/tmp/install_ollama.sh']);
      
      final exitCode = await result.exitCode;
      return exitCode == 0;
    } catch (e) {
      print('Error installing Ollama: $e');
      return false;
    }
  }
}
