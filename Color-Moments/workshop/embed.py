"""3단계 후보 — 이미지 인코더로 사진 값을 뽑는다. 결과: ~/mongdol-word-lab/emb-<이름>.npz (keys, x)
실행: python embed.py <이름> — mobileclip2-s0 | mobileclip2-s2 (연구용 라이선스라 앱엔 못 넣는다)
  상업 가능: siglip2-b16 · tinyclip-8m · tinyclip-39m · dinov2-s · mnv4-m · clip-b32-laion"""
import glob
import os
import sys
import time

import numpy as np
import torch
from PIL import Image

LAB = os.path.expanduser("~/mongdol-word-lab")
name = sys.argv[1]
device = "mps" if torch.backends.mps.is_available() else "cpu"

if name.startswith("mobileclip2"):
    import open_clip
    arch = {"mobileclip2-s0": "MobileCLIP2-S0", "mobileclip2-s2": "MobileCLIP2-S2"}[name]
    model, _, preprocess = open_clip.create_model_and_transforms(arch, pretrained="dfndr2b")
    model.eval().to(device)
    encoder = model.visual
    encode = lambda batch: model.encode_image(batch)
elif name == "clip-b32-laion":
    import open_clip
    model, _, preprocess = open_clip.create_model_and_transforms("ViT-B-32", pretrained="laion2b_s34b_b79k")
    model.eval().to(device)
    encoder = model.visual
    encode = lambda batch: model.encode_image(batch)
elif name.startswith("tinyclip"):
    from transformers import CLIPImageProcessor, CLIPModel
    repo = {"tinyclip-8m": "wkcn/TinyCLIP-ViT-8M-16-Text-3M-YFCC15M",
            "tinyclip-39m": "wkcn/TinyCLIP-ViT-39M-16-Text-19M-YFCC15M"}[name]
    model = CLIPModel.from_pretrained(repo).eval().to(device)
    processor = CLIPImageProcessor.from_pretrained(repo)
    encoder = model.vision_model
    preprocess = lambda img: processor(images=img, return_tensors="pt")["pixel_values"][0]
    encode = lambda batch: model.get_image_features(pixel_values=batch)
elif name == "dinov2-s":
    from transformers import AutoImageProcessor, AutoModel
    model = AutoModel.from_pretrained("facebook/dinov2-small").eval().to(device)
    processor = AutoImageProcessor.from_pretrained("facebook/dinov2-small")
    encoder = model
    preprocess = lambda img: processor(images=img, return_tensors="pt")["pixel_values"][0]
    encode = lambda batch: model(pixel_values=batch).pooler_output
elif name == "mnv4-m":
    import timm
    model = timm.create_model("mobilenetv4_conv_medium.e500_r256_in1k", pretrained=True, num_classes=0).eval().to(device)
    cfg = timm.data.resolve_data_config({}, model=model)
    preprocess = timm.data.create_transform(**cfg)
    encoder = model
    encode = lambda batch: model(batch)
else:
    from transformers import AutoImageProcessor, AutoModel
    repo = "google/siglip2-base-patch16-224"
    model = AutoModel.from_pretrained(repo).eval().to(device)
    processor = AutoImageProcessor.from_pretrained(repo)
    encoder = model.vision_model
    preprocess = lambda img: processor(images=img, return_tensors="pt")["pixel_values"][0]
    encode = lambda batch: model.get_image_features(pixel_values=batch)

params = sum(p.numel() for p in encoder.parameters())
print(f"{name}: 이미지 인코더 {params / 1e6:.1f}M 개 ≈ float16 {params * 2 / 1e6:.0f}MB · int8 {params / 1e6:.0f}MB", flush=True)

paths = sorted(glob.glob(f"{LAB}/photos/*.jpg")) + sorted(glob.glob(f"{LAB}/photos-train/*.jpg"))
keys, out = [], []
t = time.time()
with torch.no_grad():
    for i in range(0, len(paths), 32):
        chunk = paths[i:i + 32]
        batch = torch.stack([preprocess(Image.open(p).convert("RGB")) for p in chunk]).to(device)
        feats = encode(batch)
        feats = getattr(feats, "pooler_output", feats)
        out.append(torch.nn.functional.normalize(feats.float(), dim=-1).cpu().numpy())
        keys += [os.path.basename(p)[:-4] for p in chunk]
x = np.concatenate(out)
np.savez(f"{LAB}/emb-{name}.npz", keys=np.array(keys), x=x)
print(f"{len(keys)}장 · {x.shape[1]}차원 · {time.time() - t:.0f}초", flush=True)
