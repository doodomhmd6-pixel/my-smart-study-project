from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import json
import google.generativeai as genai
from PIL import Image
import io

# --- Configurations ---
GEMINI_API_KEY = os.environ.get('GEMINI_API_KEY')
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)

app = Flask(__name__)
CORS(app)

@app.route('/', methods=['GET'])
def index():
    models_list = []
    if GEMINI_API_KEY:
        try:
            models_list = [m.name for m in genai.list_models()]
        except:
            models_list = ["Could not list models"]
    
    return f"""
    <html>
        <head><title>Smart Study AI Server</title></head>
        <body style="font-family: sans-serif; text-align: center; padding-top: 50px;">
            <h1 style="color: #2196F3;">🚀 سيرفر ذاكرتي الذكية يعمل!</h1>
            <div style="background: #f4f4f4; padding: 20px; display: inline-block; border-radius: 10px; text-align: left;">
                <b>المكتبة:</b> {genai.__version__} <br>
                <b>الموديلات المتاحة:</b> <pre>{json.dumps(models_list, indent=2)}</pre>
            </div>
        </body>
    </html>
    """

@app.route('/api/process-text', methods=['POST'])
def process_text_endpoint():
    try:
        data = request.json
        text = data.get('text', '')
        return generate_flashcards_with_gemini(text, is_image=False)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/process-image', methods=['POST'])
def process_image_endpoint():
    try:
        if 'image' not in request.files:
            return jsonify({'error': 'No image file found'}), 400
        file = request.files['image']
        image_bytes = file.read()
        image = Image.open(io.BytesIO(image_bytes))
        return generate_flashcards_with_gemini(image, is_image=True)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

def generate_flashcards_with_gemini(input_data, is_image=False):
    if not GEMINI_API_KEY:
        return jsonify({'error': 'API Key not configured'}), 500
    
    # قائمة بأسماء الموديلات المحتملة لتجنب خطأ 404
    model_names = ['gemini-1.5-flash', 'gemini-1.5-flash-latest', 'gemini-pro']
    if is_image:
        model_names = ['gemini-1.5-flash', 'gemini-1.5-flash-latest', 'gemini-pro-vision']

    last_error = ""
    for m_name in model_names:
        try:
            model = genai.GenerativeModel(m_name)
            prompt = "قم بإنشاء بطاقات تعليمية JSON تحتوي على question و answer من المحتوى التالي باللغة العربية:"
            
            if is_image:
                response = model.generate_content([prompt, input_data])
            else:
                response = model.generate_content(f"{prompt}\n\n{input_data}")
            
            content = response.text.strip()
            if '```json' in content:
                content = content.split('```json')[1].split('```')[0].strip()
            elif '```' in content:
                content = content.split('```')[1].split('```')[0].strip()
            
            flashcard_data = json.loads(content)
            final_flashcards = [{'id': f'ai_{os.urandom(2).hex()}', 'question': fc['question'], 'answer': fc['answer'], 'category': 'ذكاء اصطناعي'} for fc in flashcard_data]
            return jsonify({'success': True, 'flashcards': final_flashcards})
        except Exception as e:
            last_error = str(e)
            continue # تجربة الموديل التالي إذا فشل الحالي
            
    return jsonify({'error': f"All models failed. Last error: {last_error}"}), 500

if __name__ == '__main__':
    app.run(debug=False, host='0.0.0.0', port=int(os.environ.get('PORT', 5000)))
