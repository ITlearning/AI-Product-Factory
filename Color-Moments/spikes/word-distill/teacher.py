"""로컬 선생(mlx-vlm) — prompts/<key>.txt + photos/<key>.jpg → answers/<name>/<key>.json
실행: python teacher.py <hf 모델 id> <이름> [키 파일]"""
import json
import os
import re
import sys
import time

from mlx_vlm import apply_chat_template, generate, load
from mlx_vlm.utils import load_config

LAB = os.path.expanduser("~/mongdol-word-lab")
model_id, name = sys.argv[1], sys.argv[2]
keys = open(sys.argv[3] if len(sys.argv) > 3 else f"{LAB}/keys.txt").read().split()
out = f"{LAB}/answers/{name}"
os.makedirs(out, exist_ok=True)

model, processor = load(model_id)
config = load_config(model_id)

for key in keys:
    path = f"{out}/{key}.json"
    if os.path.exists(path):
        continue
    question = open(f"{LAB}/{os.environ.get('PROMPTS', 'prompts')}/{key}.txt").read()
    prompt = apply_chat_template(processor, config, question, num_images=1, enable_thinking=False)
    t = time.time()
    result = generate(model, processor, prompt, image=[f"{LAB}/photos/{key}.jpg"], max_tokens=300, temperature=0.0)
    text = getattr(result, "text", result)
    found = re.search(r"\{.*\}", text, re.S)
    try:
        answer = json.loads(found.group(0)) if found else {}
    except json.JSONDecodeError:
        answer = {}
    answer["raw"] = text
    answer["seconds"] = round(time.time() - t, 1)
    json.dump(answer, open(path, "w"), ensure_ascii=False)
    print(key, answer.get("word"), answer["seconds"], flush=True)
