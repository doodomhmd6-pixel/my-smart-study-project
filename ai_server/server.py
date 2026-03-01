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
    return "<h1>Smart Study AI Server is Running</h1><p>Connected to Gemini API</p>"

@app.route('/api/process-text', methods=['POST'])
def process_text_endpoint():
    try:
        data = request.json
        text = data.get('text', '')
        card_type = data.get('card_type', 'text') # Default to 'text'
        if not text:
            return jsonify({'error': 'No text provided'}), 400
        return generate_flashcards_with_gemini(text, is_image=False, card_type=card_type)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

@app.route('/api/process-image', methods=['POST'])
def process_image_endpoint():
    try:
        card_type = request.form.get('card_type', 'text') # For multipart form, use request.form
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
        return jsonify({'error': 'API Key not configured'}), 500
    
    model_names = []
    if is_image: # For image processing, prefer models with vision capabilities
        model_names = ['gemini-2.0-flash', 'gemini-flash-latest', 'gemini-pro-vision', 'gemini-pro']
    else: # For text processing, standard models are fine
        model_names = ['gemini-2.0-flash', 'gemini-flash-latest', 'gemini-pro']

    selected_model_name = None
    for m_name in model_names:
        try:
            model = genai.GenerativeModel(m_name)
            # Check if model supports generate_content (vision models often do)
            if hasattr(model, 'generate_content'): # Basic check for method existence
                 selected_model_name = m_name
                 break
        except Exception as e:
            print(f"Warning: Model {m_name} failed to load: {e}")
            continue
    
    if not selected_model_name:
        return jsonify({'error': 'No suitable Gemini model found for generation'}), 500

    # Dynamic prompt based on card_type
    prompt = """
    أنت خبير في إنشاء المحتوى التعليمي. 
    قم باستخراج المعلومات الهامة من المدخل وحولها إلى مجموعة بطاقات تعليمية.
    اجعل الإجابات باللغة العربية.
    يجب أن تكون الإجابة بصيغة JSON فقط، وهي عبارة عن قائمة من الكائنات.
    """

    if card_type == 'text':
        prompt += """
        التنسيق المطلوب لبطاقة نصية: [
          {"question": "سؤال", "answer": "إجابة", "answerType": "text"}
        ]
        """
    elif card_type == 'multipleChoice':
        prompt += """
        التنسيق المطلوب لبطاقة اختيار من متعدد (يجب أن تتضمن 4 خيارات على الأقل ومؤشر الإجابة الصحيحة):
        [
          {"question": "سؤال", "options": ["خيار1", "خيار2", "خيار3", "خيار4"], "correctOptionIndex": 0, "answerType": "multipleChoice"}
        ]
        """
    elif card_type == 'trueFalse':
        prompt += """
        التنسيق المطلوب لبطاقة صح/خطأ (يجب أن تتضمن الخيارين "صح" و "خطأ" ومؤشر الإجابة الصحيحة):
        [
          {"question": "سؤال", "options": ["صح", "خطأ"], "correctOptionIndex": 0, "answerType": "trueFalse"}
        ]
        """
    else:
        return jsonify({'error': f'Unsupported card type: {card_type}'}), 400

    final_prompt = f"{prompt}\n\nالمحتوى: {input_data}"

    try:
        model = genai.GenerativeModel(selected_model_name)
        if is_image:
            response = model.generate_content([prompt, input_data])
        else:
            response = model.generate_content(final_prompt)
        
        content = response.text.strip()
        if '```json' in content:
            content = content.split('```json')[1].split('```')[0].strip()
        elif '```' in content:
            content = content.split('```')[1].split('```')[0].strip()
            
        flashcard_data = json.loads(content)
        
        final_flashcards = []
        for fc in flashcard_data:
            # Ensure options and correctOptionIndex are set for non-text types
            options = fc.get('options', [])
            correct_index = fc.get('correctOptionIndex', None)
            answer_text = fc.get('answer', '') # Only for text cards
            
            if card_type == 'trueFalse' and not options:
                options = ['صح', 'خطأ'] # Ensure fixed options for true/false if missing

            final_flashcards.append({
                'id': f'ai_{os.urandom(3).hex()}', 
                'question': fc['question'], 
                'answer': answer_text, 
                'category': 'ذكاء اصطناعي', # يمكن تغيير هذا لاحقاً
                'answerType': card_type,
                'options': options,
                'correctOptionIndex': correct_index,
            })
        
        return jsonify({'success': True, 'flashcards': final_flashcards})

    except Exception as e:
        print(f"Gemini generation error: {str(e)}")
        return jsonify({'error': f"Gemini Error: {str(e)}"}), 500

if __name__ == '__main__':
    app.run(debug=False, host='0.0.0.0', port=int(os.environ.get('PORT', 5000)))
