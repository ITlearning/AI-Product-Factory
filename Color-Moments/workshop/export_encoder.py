"""TinyCLIP 이미지 인코더 → Core ML(int8). 정규화·L2 는 모델 안, 리사이즈는 앱 WordImage."""
import sys

import coremltools as ct
import coremltools.optimize.coreml as cto
import torch
from transformers import CLIPModel

REPO = {"8m": "wkcn/TinyCLIP-ViT-8M-16-Text-3M-YFCC15M", "39m": "wkcn/TinyCLIP-ViT-39M-16-Text-19M-YFCC15M"}[sys.argv[1]]
MEAN = torch.tensor([0.48145466, 0.4578275, 0.40821073]).view(1, 3, 1, 1)
STD = torch.tensor([0.26862954, 0.26130258, 0.27577711]).view(1, 3, 1, 1)


class Encoder(torch.nn.Module):
    def __init__(self, clip):
        super().__init__()
        self.clip = clip

    def forward(self, x):
        x = (x / 255.0 - MEAN) / STD
        e = self.clip.get_image_features(pixel_values=x)
        e = getattr(e, "pooler_output", e)  # transformers 5 는 텐서 대신 ModelOutput 을 돌려준다(pooler_output 이 투영된 512)
        return torch.nn.functional.normalize(e, dim=-1)


model = Encoder(CLIPModel.from_pretrained(REPO)).eval()
traced = torch.jit.trace(model, torch.rand(1, 3, 224, 224) * 255)
ml = ct.convert(traced, inputs=[ct.ImageType(name="image", shape=(1, 3, 224, 224), color_layout=ct.colorlayout.RGB)],
                outputs=[ct.TensorType(name="embedding")], minimum_deployment_target=ct.target.iOS18)
ml = cto.linear_quantize_weights(ml, cto.OptimizationConfig(global_config=cto.OpLinearQuantizerConfig(mode="linear_symmetric")))
ml.short_description = f"TinyCLIP {sys.argv[1]} image encoder (MIT) — 몽돌 단어"
ml.save(sys.argv[2])
