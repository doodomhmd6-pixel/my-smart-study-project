from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import json
from datetime import datetime
import pytesseract
from PIL import Image
import io
import cv2
import numpy as np
import google.generativeai as genai

# --- Configurations ---
# Tesseract configuration
pytesseract.pytesseract.tesseract_cmd = r'C:\Program Files\Tesseract-OCR\tesseract.exe'

# Google AI (Gemini) configuration
# IMPORTANT: Store your API key securely as an environment variable named 'GEMINI_API_KEY'.
# Do NOT hardcode your API key directly in the code.
GEMINI_API_KEY = os.environ.get('GEMINI_API_KEY')
if GEMINI_API_KEY is None:
    # Handle the case where the API key is not set. You might want to raise an error or log a warning.
    # For now, we'll print a warning and proceed, but Gemini functionality will likely fail.
    print("WARNING: GEMINI_API_KEY environment variable not set. Gemini functionality may fail.")
    # You could optionally set a placeholder or exit if the key is critical:
    # raise ValueError("GEMINI_API_KEY environment variable not set.")
else:
    genai.configure(api_key=GEMINI_API_KEY)


app = Flask(__name__)
CORS(app)  # Allow cross-origin requests

@app.route('/api/health', methods=['GET'])
def health_check():
    return jsonify({'status': 'healthy', 'server': 'local'})

@app.route('/api/process-text', methods=['POST'])
def process_text_endpoint():
    """Processes text using the Gemini API."""
    try:
        data = request.json
        text = data.get('text', '')
        if not text:
            return jsonify({'error': 'No text provided'}), 400
        
        return generate_flashcards_with_gemini(text, 'gemini_text')
        
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/process-image', methods=['POST'])
def process_image_endpoint():
    """Processes an image to extract text and then uses Gemini to create flashcards."""
    try:
        if 'image' not in request.files:
            return jsonify({'error': 'No image file found'}), 400

        file = request.files['image']
        if file.filename == '':
            return jsonify({'error': 'No image file selected'}), 400

        image_bytes = file.read()
        nparr = np.frombuffer(image_bytes, np.uint8)
        img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)

        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        blurred = cv2.GaussianBlur(gray, (5, 5), 0)
        binary_img = cv2.threshold(blurred, 0, 255, cv2.THRESH_BINARY + cv2.THRESH_OTSU)[1]
        
        custom_config = r'--oem 3 --psm 3 -l ara+eng'
        extracted_text = pytesseract.image_to_string(binary_img, config=custom_config)

        if not extracted_text.strip():
            return jsonify({'error': 'Could not extract any text from the image'}), 400

        return generate_flashcards_with_gemini(extracted_text, 'gemini_ocr')

    except Exception as e:
        return jsonify({'error': str(e)}), 500

def generate_flashcards_with_gemini(text, source):
    """Uses the Gemini API to generate high-quality flashcards from text."""
    if GEMINI_API_KEY is None:
        return jsonify({'error': 'Gemini API key is not configured. Please set the GEMINI_API_KEY environment variable.'}), 500

    try:
        model_to_use = None
        flash_model = None
        pro_model = None
        print("--- Searching for a compatible Gemini Model ---")
        for m in genai.list_models():
            if 'generateContent' in m.supported_generation_methods:
                print(f"Found compatible model: {m.name}")
                if 'flash' in m.name:
                    flash_model = m.name
                if 'pro' in m.name and not pro_model:
                    pro_model = m.name

        if flash_model:
            model_to_use = flash_model
        elif pro_model:
            model_to_use = pro_model

        if not model_to_use:
            raise Exception("No compatible Gemini models found. Check your API key and permissions.")

        print(f"--- Using model: {model_to_use} ---")
        model = genai.GenerativeModel(model_to_use)
        
        prompt = f"""You are an expert assistant for creating educational materials. 
        From the following text, generate a list of flashcards in a valid JSON format. 
        Each flashcard in the list should be an object with exactly two keys: \"question\" and \"answer\".
        Make the questions and answers clear and concise.
        
        Text: \"{text}\""""

        response = model.generate_content(prompt)
        
        cleaned_response = response.text.strip().replace('```json', '').replace('```', '')
        flashcard_data = json.loads(cleaned_response)
        
        final_flashcards = [
            {
                'id': f'gemini_{i}',
                'question': fc['question'],
                'answer': fc['answer'],
                'difficulty': 3, 
                'category': 'Gemini'
            } for i, fc in enumerate(flashcard_data)
        ]

        return jsonify({
            'success': True,
            'flashcards': final_flashcards,
            'count': len(final_flashcards),
            'source': source
        })

    except Exception as e:
        print(f"[Gemini Error] {str(e)}")
        return jsonify({'error': f"Failed to generate flashcards with Gemini: {str(e)}"}), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    print(f"=" * 50)
    print(f"🚀 AI Server running on port {port}")
    print("=" * 50)
    
    app.run(debug=True, host='0.0.0.0', port=port)
