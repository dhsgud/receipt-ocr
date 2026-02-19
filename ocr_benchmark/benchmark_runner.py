"""
OCR Benchmark Runner - llama.cpp Vision Server
With Accuracy Measurement (CER - Character Error Rate)
"""

import os
import time
import json
import glob
import base64
import requests
from tqdm import tqdm
from PIL import Image
import io

# ============== 설정 ==============
VISION_SERVER_URL = os.environ.get("VISION_SERVER_URL", "http://localhost:408/v1/chat/completions")
VISION_MODEL_NAME = "user-model"
REQUEST_TIMEOUT = 300


def calculate_cer(reference: str, hypothesis: str) -> float:
    """
    Character Error Rate (CER) 계산
    CER = (삽입 + 삭제 + 대체) / 정답 길이
    낮을수록 좋음. 0 = 완벽, 1 = 100% 오류
    """
    # 공백/줄바꿈 정규화
    ref = reference.replace('\n', ' ').replace('\r', '').strip()
    hyp = hypothesis.replace('\n', ' ').replace('\r', '').strip()
    
    # Levenshtein Distance (Edit Distance)
    m, n = len(ref), len(hyp)
    if m == 0:
        return 1.0 if n > 0 else 0.0
    
    dp = [[0] * (n + 1) for _ in range(m + 1)]
    
    for i in range(m + 1):
        dp[i][0] = i
    for j in range(n + 1):
        dp[0][j] = j
    
    for i in range(1, m + 1):
        for j in range(1, n + 1):
            if ref[i-1] == hyp[j-1]:
                dp[i][j] = dp[i-1][j-1]
            else:
                dp[i][j] = 1 + min(dp[i-1][j], dp[i][j-1], dp[i-1][j-1])
    
    return dp[m][n] / m


def run_llama_vision(img_path, server_url=VISION_SERVER_URL, model_name=VISION_MODEL_NAME):
    """llama.cpp 서버에 Vision 요청"""
    start = time.time()
    
    image = Image.open(img_path)
    if image.mode in ('RGBA', 'P'):
        image = image.convert('RGB')
    
    buffered = io.BytesIO()
    image.save(buffered, format="JPEG")
    img_str = base64.b64encode(buffered.getvalue()).decode('utf-8')
    
    prompt = """이 영수증 이미지에 보이는 모든 텍스트를 순서대로 그대로 적어주세요.
- 위에서 아래로, 왼쪽에서 오른쪽 순서로 읽어주세요.
- 숫자, 가격, 날짜 등 모든 정보를 빠뜨리지 말고 적어주세요.
- 형식을 맞추려 하지 말고 보이는 그대로 적어주세요.
- 품목명이 잘려서 보이더라도 보이는 그대로 적어주세요 (예: "신라면멀티" → "신라면멀" 처럼 잘려 보이면 그대로)."""

    payload = {
        "model": model_name,
        "messages": [
            {
                "role": "user",
                "content": [
                    {"type": "text", "text": prompt},
                    {"type": "image_url", "image_url": {"url": f"data:image/jpeg;base64,{img_str}"}}
                ]
            }
        ],
        "temperature": 0.1,
        "max_tokens": 2048,
    }
    
    try:
        response = requests.post(server_url, json=payload, timeout=REQUEST_TIMEOUT)
        if response.status_code != 200:
            return {"time": time.time() - start, "text": "", "error": f"Server error: {response.text}"}
        
        result = response.json()
        text = result['choices'][0]['message']['content']
        end = time.time()
        return {"time": end - start, "text": text}
    except Exception as e:
        return {"time": time.time() - start, "text": "", "error": str(e)}


def load_ground_truth(img_path):
    """
    이미지와 같은 이름의 .txt 파일에서 정답 텍스트 로드
    예: receipt1.jpg -> receipt1.txt
    """
    base = os.path.splitext(img_path)[0]
    txt_path = base + ".txt"
    if os.path.exists(txt_path):
        with open(txt_path, 'r', encoding='utf-8') as f:
            return f.read().strip()
    return None


def main():
    images_dir = "images"
    image_files = glob.glob(os.path.join(images_dir, "*.*"))
    image_files = [f for f in image_files if f.lower().endswith(('.png', '.jpg', '.jpeg', '.webp', '.bmp'))]
    results = {}

    if not image_files:
        print("❌ No images found in 'images' directory.")
        return

    print(f"📷 Found {len(image_files)} images.")
    print(f"🔗 Server: {VISION_SERVER_URL}")
    print("\n💡 Tip: 정확도 측정하려면 이미지와 같은 이름의 .txt 파일에 정답 텍스트를 넣어주세요.")
    print("   예: receipt.jpg → receipt.txt\n")

    total_time = 0
    total_cer = 0
    cer_count = 0

    for img_path in tqdm(image_files, desc="Processing"):
        filename = os.path.basename(img_path)
        print(f"\n{'='*50}")
        print(f"📄 {filename}")
        print('='*50)
        
        result = run_llama_vision(img_path)
        
        if 'error' in result:
            print(f"❌ Error: {result['error']}")
            results[filename] = result
            continue
        
        total_time += result['time']
        
        # 정답 텍스트 확인
        ground_truth = load_ground_truth(img_path)
        
        if ground_truth:
            cer = calculate_cer(ground_truth, result['text'])
            accuracy = (1 - cer) * 100
            result['cer'] = cer
            result['accuracy'] = accuracy
            result['ground_truth'] = ground_truth
            total_cer += cer
            cer_count += 1
            
            print(f"⏱️  Time: {result['time']:.2f}s")
            print(f"✅ Accuracy: {accuracy:.1f}% (CER: {cer:.3f})")
            print(f"\n[정답]:\n{ground_truth[:200]}...")
            print(f"\n[추출]:\n{result['text'][:200]}...")
        else:
            print(f"⏱️  Time: {result['time']:.2f}s")
            print(f"⚠️  No ground truth file found (add {os.path.splitext(filename)[0]}.txt)")
            print(f"\n[추출 텍스트]:\n{result['text']}")
        
        results[filename] = result

    # Save
    with open("benchmark_results.json", "w", encoding="utf-8") as f:
        json.dump(results, f, ensure_ascii=False, indent=4)
    
    # Summary
    print("\n" + "="*60)
    print("📊 BENCHMARK SUMMARY")
    print("="*60)
    print(f"Total images: {len(image_files)}")
    print(f"Total time: {total_time:.2f}s")
    print(f"Avg time per image: {total_time/len(image_files):.2f}s")
    
    if cer_count > 0:
        avg_cer = total_cer / cer_count
        avg_accuracy = (1 - avg_cer) * 100
        print(f"\n🎯 Average Accuracy: {avg_accuracy:.1f}%")
        print(f"📉 Average CER: {avg_cer:.3f}")
    else:
        print("\n⚠️  정확도를 측정하려면 정답 텍스트 파일(.txt)을 추가해주세요.")
    
    print("\n✅ Results saved to benchmark_results.json")


if __name__ == "__main__":
    main()
