"""표준국어대사전 전체 내려받기(XML)에서 고유어 명사만 뽑는다. 결과: ~/mongdol-word-lab/stdict-native-nouns.json
사전 자료는 CC BY-SA 2.0 KR — 저장소에는 올리지 않는다."""
import collections
import glob
import json
import os
import re
import sys
import xml.etree.ElementTree as ET

src = sys.argv[1]
out, types, cats = {}, collections.Counter(), collections.Counter()
for path in sorted(glob.glob(os.path.join(src, "*.xml"))):
    for item in ET.parse(path).getroot().iter("item"):
        info = item.find("word_info")
        if info.findtext("word_unit") != "단어" or info.findtext("word_type") != "고유어":
            continue
        word = re.sub(r"[\d\-^ ]", "", info.findtext("word") or "")
        for pos in info.iter("pos_info"):
            if pos.findtext("pos") != "명사":
                continue
            for sense in pos.iter("sense_info"):
                kind = sense.findtext("type")
                types[kind] += 1
                cat = [c.text for c in sense.iter("cat")]
                cats.update(cat)
                entry = out.setdefault(word, {"word": word, "senses": []})
                entry["senses"].append({"type": kind, "cat": cat, "definition": sense.findtext("definition")})
json.dump(list(out.values()), open(os.path.expanduser("~/mongdol-word-lab/stdict-native-nouns.json"), "w"),
          ensure_ascii=False, indent=0)
print("고유어 명사 표제어", len(out))
print("뜻 갈래", types.most_common())
print("전문 분야 상위", cats.most_common(25))
