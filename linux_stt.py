import sys
import speech_recognition as sr

def transcribe_audio(file_path):
    recognizer = sr.Recognizer()
    try:
        with sr.AudioFile(file_path) as source:
            audio_data = recognizer.record(source)
        
        # Use offline Sphinx engine
        text = recognizer.recognize_sphinx(audio_data)
        print(text)
    except sr.UnknownValueError:
        print("") # Return empty explicitly
    except sr.RequestError as e:
        print(f"Error: {e}")
    except Exception as e:
        print(f"Error: {e}")

if __name__ == "__main__":
    if len(sys.argv) > 1:
        transcribe_audio(sys.argv[1])
    else:
        print("Error: No audio file provided.")
