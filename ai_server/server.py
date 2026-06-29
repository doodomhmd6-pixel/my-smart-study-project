from flask import Flask, request, jsonify
from flask_cors import CORS
import os
import json
import google.generativeai as genai
from PIL import Image
import io

# --- الإعدادات والتهيئة ---
# جلب مفتاح واجهة برمجة تطبيقات Gemini من متغيرات البيئة
GEMINI_API_KEY = os.environ.get('GEMINI_API_KEY')
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)

app = Flask(__name__)
CORS(app)  # تفعيل حماية CORS للسماح بالطلبات من تطبيقات الهواتف والمتصفحات الخارجية

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

        # قائمة الموديلات المتاحة لتجربتها بالترتيب في حال فشل أحدها
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
                continue  # الانتقال للموديل التالي في حال حدوث خطأ
                
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
        
        # إرسال بيانات الصورة وهيكلها بالطريقة الصحيحة المتوافقة مع مكتبة Gemini الجديدة
        image_data = {
            'mime_type': file.content_type if file.content_type else 'image/jpeg',
            'data': image_bytes
        }
        
        return generate_flashcards_with_gemini(image_data, is_image=True, card_type=card_type)
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
            يجب أن تكون الإجابة هامة ومطابقة تماماً لصيغة الـ JSON المطلوبة أدناه دون أي كلام خارجي أو علامات markdown.
            
            نوع البطاقات المطلوب: {card_type}
            """
            if card_type == 'text': 
                prompt += 'المطلوب إرجاع مصفوفة بهذا الشكل المباشر: [{"question": "سؤال", "answer": "إجابة"}]'
            elif card_type == 'multipleChoice': 
                prompt += 'المطلوب إرجاع مصفوفة بهذا الشكل المباشر: [{"question": "سؤال", "options": ["خيار1", "خيار2", "خيار3", "خيار4"], "correctOptionIndex": 0}]'
            elif card_type == 'trueFalse': 
                prompt += 'المطلوب إرجاع مصفوفة بهذا الشكل المباشر: [{"question": "سؤال", "options": ["صح", "خطأ"], "correctOptionIndex": 0}]'

            # إجبار النموذج على إرجاع JSON مهيكل مباشرة لتجنب أخطاء التحليل اليدوي
            config = genai.types.GenerationConfig(response_mime_type="application/json")

            if is_image: 
                # تمرير الصورة بالشكل الهيكلي الصحيح للمكتبة
                response = model.generate_content([prompt, input_data], generation_config=config)
            else: 
                response = model.generate_content(f"{prompt}\n\nالمحتوى: {input_data}", generation_config=config)
            
            content = response.text.strip()
            
            # فك ترميز الـ JSON بأمان
            flashcard_data = json.loads(content)
            
            final_flashcards = []
            for fc in flashcard_data:
                final_flashcards.append({
                    'id': f'ai_{os.urandom(3).hex()}', 
                    'question': fc.get('question', ''), 
                    'answer': fc.get('answer', ''), 
                    'category': 'ذكاء اصطناعي',
                    'answerType': card_type,
                    'options': fc.get('options', ['صح', 'خطأ'] if card_type == 'trueFalse' else []),
                    'correctOptionIndex': fc.get('correctOptionIndex', 0),
                })
                
            return jsonify({'success': True, 'flashcards': final_flashcards})
        except Exception as e:
            last_error = str(e)
            continue  # تجربة الموديل التالي في حال حدوث خطأ
            
    return jsonify({'error': f"Gemini Error: {last_error}"}), 500

if __name__ == '__main__':
    # تشغيل السيرفر محلياً على المنفذ 5000
    app.run(debug=False, host='0.0.0.0', port=int(os.environ.get('PORT', 5000)))
