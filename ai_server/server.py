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
    return "<h1>Smart Study AI Server is Running</h1>"

@app.route('/api/explain', methods=['POST'])
def explain_endpoint():
    try:
        data = request.json
        question = data.get('question', '')
        answer = data.get('answer', '')
        
        if not GEMINI_API_KEY:
            return jsonify({'error': 'API Key not configured on server'}), 500

        # قائمة الموديلات المتاحة
        model_names = ['gemini-1.5-flash', 'gemini-2.0-flash-lite', 'gemini-flash-latest']
        
        last_error = ""
        for m_name in model_names:
            try:
                model = genai.GenerativeModel(m_name)
                prompt = f"""أنت معلم خبير ومبسط للمعلومات. 
                لقد سأل الطالب: "{question}"
                وكانت الإجابة: "{answer}"
                قم بتقديم شرح مبسط، مشوق، وعميق لهذه المعلومة باللغة العربية لمساعدة الطالب على فهمها بدلاً من مجرد حفظها. 
                اجعل الشرح مختصراً ومركزاً في نقاط إذا لزم الأمر."""
                
                response = model.generate_content(prompt)
                return jsonify({'success': True, 'explanation': response.text})
            except Exception as e:
                last_error = str(e)
                continue
                
        return jsonify({'error': f"Gemini Error: {last_error}"}), 500
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/process-text', methods=['POST'])
def process_text_endpoint():
    try:
        data = request.json
        text = data.get('text', '')
        card_type = data.get('card_type', 'text')
        return generate_flashcards_with_gemini(text, is_image=False, card_type=card_type)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/process-image', methods=['POST'])
def process_image_endpoint():
    try:
        card_type = request.form.get('card_type', 'text')
        if 'image' not in request.files:
            return jsonify({'error': 'No image file found'}), 400
        file = request.files['image']
        image_bytes = file.read()
        image = Image.open(io.BytesIO(image_bytes))
        return generate_flashcards_with_gemini(image, is_image=True, card_type=card_type)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

def generate_flashcards_with_gemini(input_data, is_image=False, card_type='text'):
    if not GEMINI_API_KEY:
        return jsonify({'error': 'API Key not configured on server'}), 500
    
    model_names = ['gemini-1.5-flash', 'gemini-2.0-flash-lite', 'gemini-flash-latest']

    last_error = ""
    for m_name in model_names:
        try:
            model = genai.GenerativeModel(m_name)
            prompt = f"""أنت خبير في إنشاء المحتوى التعليمي. 
            قم باستخراج المعلومات الهامة من المدخل وحولها إلى مجموعة بطاقات تعليمية باللغة العربية.
            يجب أن تكون الإجابة بصيغة JSON فقط.
            نوع البطاقات المطلوب: {card_type}
            """
            if card_type == 'text': prompt += '[{"question": "سؤال", "answer": "إجابة"}]'
            elif card_type == 'multipleChoice': prompt += '[{"question": "سؤال", "options": ["خيار1", "خيار2", "خيار3", "خيار4"], "correctOptionIndex": 0}]'
            elif card_type == 'trueFalse': prompt += '[{"question": "سؤال", "options": ["صح", "خطأ"], "correctOptionIndex": 0}]'

            if is_image: response = model.generate_content([prompt, input_data])
            else: response = model.generate_content(f"{prompt}\n\nالمحتوى: {input_data}")
            
            content = response.text.strip()
            if '```json' in content: content = content.split('```json')[1].split('```')[0].strip()
            elif '```' in content: content = content.split('```')[1].split('```')[0].strip()
            
            flashcard_data = json.loads(content)
            final_flashcards = []
            for fc in flashcard_data:
                final_flashcards.append({
                    'id': f'ai_{os.urandom(3).hex()}', 
                    'question': fc['question'], 
                    'answer': fc.get('answer', ''), 
                    'category': 'ذكاء اصطناعي',
                    'answerType': card_type,
                    'options': fc.get('options', ['صح', 'خطأ'] if card_type == 'trueFalse' else []),
                    'correctOptionIndex': fc.get('correctOptionIndex', 0),
                })
            return jsonify({'success': True, 'flashcards': final_flashcards})
        except Exception as e:
            last_error = str(e)
            continue 
            
    return jsonify({'error': f"Gemini Error: {last_error}"}), 500

if __name__ == '__main__':
    app.run(debug=False, host='0.0.0.0', port=int(os.environ.get('PORT', 5000)))
