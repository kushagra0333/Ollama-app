<div align="center">
  <img src="https://upload.wikimedia.org/wikipedia/commons/1/10/Ollama_logo.svg" alt="Ollama Logo" width="100"/>
  <h1>Ollama Linux Desktop App</h1>
  <p><b>A natively compiled, blazing-fast GUI client for local Ollama models on Linux.</b></p>

  [![Flutter](https://img.shields.io/badge/Flutter-02569B?style=for-the-badge&logo=flutter&logoColor=white)](https://flutter.dev/)
  [![Linux Support](https://img.shields.io/badge/Linux-FCC624?style=for-the-badge&logo=linux&logoColor=black)](https://www.linux.org/)
  [![Ollama](https://img.shields.io/badge/Ollama-black?style=for-the-badge&logo=ollama&logoColor=white)](https://ollama.com/)
</div>

<br/>

## ✨ Introduction

**Ollama Linux Desktop App** is a completely native, lightweight Flutter desktop application built specifically for Ubuntu and Linux. It serves as a beautiful frontend interface to your local `ollama` instance, avoiding the bloat and extreme RAM usage of Electron-based apps or browser hubs.

## 🚀 Features

- **Blazing Fast Native Desktop**: Compiled directly to a native Linux x64 binary. No browser wrappers.
- **Auto-Discovery**: Automatically queries and detects locally downloaded models (`/api/tags`).
- **Real-Time Streaming**: Messages generate stream-by-stream identically to ChatGPT.
- **Rich Markdown Support**: Full parsing for Markdown and properly highlighted code-blocks in AI responses.
- **Live Status Monitoring**: Detects if your background Ollama engine goes offline or is active.

---

## 📸 Interface Preview

*(You can add screenshots here by saving images to an `assets/` folder and linking them like `![App Screenshot](./assets/screenshot.png)`)*

---

## 🛠 Prerequisites

Before running the application, you must have the backend AI engine installed:

1. **Install Ollama**:
   ```bash
   curl -fsSL https://ollama.com/install.sh | sh
   ```
2. **Download a Model** (example: LlaMA 3):
   ```bash
   ollama run llama3
   ```
3. *(Development Only)* **Install Flutter**: Make sure Flutter is [installed on your Linux machine](https://docs.flutter.dev/get-started/install/linux).

---

## 💻 Installation & Usage

### Method 1: Running from Source
Clone the repository and run in development mode:
```bash
git clone https://github.com/kushagra0333/Ollama-app.git
cd Ollama-app/linux_ollama_app
flutter run -d linux
```

### Method 2: Building the Native Executable
If you want to create the final, blazing-fast native app bundle that you can double click or pin to your taskbar:
```bash
cd linux_ollama_app
flutter build linux
```
*The compiled standalone program will be found at `build/linux/x64/release/bundle/linux_ollama_app`.*

---

## 🧠 Architecture Overview

This project implements standard Flutter Provider architecture:
- **`OllamaService` (`services/ollama_service.dart`)**: The networking bridge utilizing raw `HTTP` standard packages to ping `127.0.0.1:11434`.
- **`ChatProvider` (`providers/chat_provider.dart`)**: Handing application states (model selection, typing states, message arrays) avoiding UI lag during inference.
- **`MessageBubble` (`widgets/message_bubble.dart`)**: The custom reactive component utilizing `flutter_markdown` for rendering formatting.

---

## 🤝 Contributing
Built entirely in open source. Feel free to open issues or pull requests. 

* **To-Do**: Add automatic "Install Ollama" buttons inside the app if the user doesn't have it.

<div align="center">
  <br/>
  <b>Built for Linux 🐧</b>
</div>
