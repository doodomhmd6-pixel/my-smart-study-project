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
    return """
    <html>
        <head><title>Smart Study AI Server</title></head>
        <body style="font-family: sans-serif; text-align: center; padding-top: 50px;">
            <h1 style="color: #2196F3;">🚀 سيرفر ذاكرتي الذكية يعمل بنجاح!</h1>
            <p>هذا السيرفر مخصص لمعالجة طلبات تطبيق الاندرويد عبر الذكاء الاصطناعي.</p>
            <div style="background: #f4f4f4; padding: 20px; display: inline-block; border-radius: 10px;">
                <b>الحالة:</b> متصل بـ Gemini AI <br>
                <b>الموديل:</b> Gemini 1.5 Flash
            </div>
        </body>
    </html>
    """

@app.route('/api/health', methods=['GET'])
def health_check():
    return jsonify({'status': 'healthy', 'server': 'cloud_ready'})

@app.route('/api/process-text', methods=['POST'])
def process_text_endpoint():
    try:
        data = request.json
        text = data.get('text', '')
        if not text:
            return jsonify({'error': 'No text provided'}), 400
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
        return jsonify({'error': f"Image processing failed: {str(e)}"}), 500

def generate_flashcards_with_gemini(input_data, is_image=False):
    if not GEMINI_API_KEY:
        return jsonify({'error': 'API Key not configured on server'}), 500
    try:
        # استخدام gemini-1.5-flash كونه يدعم النصوص والصور معاً وهو سريع جداً
        model = genai.GenerativeModel('gemini-1.5-flash')
        
        prompt = """أنت خبير في إنشاء المحتوى التعليمي. 
        قم باستخراج المعلومات الهامة من هذا المدخل وحولها إلى مجموعة بطاقات تعليمية (Flashcards).
        يجب أن تكون الإجابة بصيغة JSON فقط، وهي عبارة عن قائمة من الكائنات، كل كائن يحتوي على "question" و "answer".
        مثال للتنسيق المطلوب:
        [
          {"question": "ما هي عاصمة فرنسا؟", "answer": "باريس"},
          {"question": "من اكتشف الجاذبية؟", "answer": "إسحاق نيوتن"}
        ]
        اجعل الأسئلة ذكية ومختصرة باللغة العربية."""

        if is_image:
            response = model.generate_content([prompt, input_data])
        else:
            response = model.generate_content(f"{prompt}\n\nالنص المطلوب معالجته:\n{input_data}")
        
        # تنظيف الاستجابة من أي علامات Markdown
        content = response.text.strip()
        if '```json' in content:
            content = content.split('```json')[1].split('```')[0].strip()
        elif '```' in content:
            content = content.split('```')[1].split('```')[0].strip()
            
        flashcard_data = json.loads(content)
        
        final_flashcards = [{
            'id': f'ai_{os.urandom(4).hex()}', 
            'question': fc['question'], 
            'answer': fc['answer'], 
            'category': 'ذكاء اصطناعي'
        } for fc in flashcard_data]
        
        return jsonify({'success': True, 'flashcards': final_flashcards, 'count': len(final_flashcards)})
    except Exception as e:
        print(f"Error: {str(e)}")
        return jsonify({'error': f"Gemini Error: {str(e)}"}), 500

if __name__ == '__main__':
    port = int(os.environ.get('PORT', 5000))
    app.run(debug=False, host='0.0.0.0', port=port)
