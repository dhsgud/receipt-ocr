import ollama

res = ollama.chat(
    model="glm-ocr",
    messages=[
        {
            "role": "user",
            "content": "이미지 안의 모든 텍스트를 JSON으로 반환해줘.",
            "images": ["C:\Users\ikm11\Desktop\receipt-ocr\ocr_benchmark\images\KakaoTalk_20260121_141718080_01.jpg"],  # 혹은 base64 문자열
        }
    ],
)

print(res["message"]["content"])
