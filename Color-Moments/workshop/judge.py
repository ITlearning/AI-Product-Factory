"""블라인드 판정 페이지 — 맥스튜디오 안에서만 연다(127.0.0.1). 실행: python3 judge.py → http://127.0.0.1:8765
사진마다 갈래(규칙·선생들)가 고른 단어를 섞어 한 번씩만 보이고, 판정은 ~/mongdol-word-lab/verdicts.json 에 쌓는다."""
import json
import os
import random
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

LAB = os.path.expanduser("~/mongdol-word-lab")
rows = json.load(open(f"{LAB}/eval.json"))
words = {w["id"]: w for w in json.load(open(f"{LAB}/words.json"))}
by_word = {w["word"]: w for w in words.values()}
# 사전에서 더한 말(id 가 d- 로 시작) — judge 조건이 아직 없어 allowed 에 없다.
if os.path.exists(f"{LAB}/words-expanded.json"):
    words.update({w["id"]: w for w in json.load(open(f"{LAB}/words-expanded.json")) if w["new"]})
VERDICTS = f"{LAB}/verdicts.json"
verdicts = json.load(open(VERDICTS)) if os.path.exists(VERDICTS) else {}


def items():
    arms = sorted(d for d in os.listdir(f"{LAB}/answers") if not d.startswith("."))
    out = []
    for r in rows:
        picks = {}
        if r["rule"]:
            picks.setdefault(r["rule"], []).append("rule")
        for arm in arms:
            p = f"{LAB}/answers/{arm}/{r['key']}.json"
            if os.path.exists(p):
                a = json.load(open(p))
                if (a.get("id") or "").startswith("d-"):
                    picks.setdefault(a["id"], []).append(arm)
                    continue
                w = by_word.get(a.get("word", "").strip())
                if w and w["id"] in r["allowed"]:
                    picks.setdefault(w["id"], []).append(arm)
        ids = list(picks)
        random.Random("judge:" + r["key"]).shuffle(ids)
        weather = r.get("weather") or ""
        out.append({"key": r["key"], "when": f"{r['local']} {r['partOfDay']} {weather}".strip(),
                    "words": [{"id": i, "word": words[i]["word"], "meaning": words[i]["meaning"]} for i in ids]})
    random.Random("judge-order").shuffle(out)
    return out


PAGE = """<!doctype html><meta charset=utf-8><meta name=viewport content="width=device-width,initial-scale=1">
<title>몽돌 단어 판정</title>
<style>
body{font:16px -apple-system,sans-serif;margin:0;background:#f6f4ef;color:#222}
main{max-width:720px;margin:auto;padding:16px}
img{width:100%;max-height:62vh;object-fit:contain;border-radius:10px;background:#ddd}
.top{display:flex;justify-content:space-between;color:#777;font-size:14px;margin:6px 0 12px}
.w{background:#fff;border-radius:10px;padding:10px 12px;margin:8px 0;display:flex;align-items:center;gap:8px;flex-wrap:wrap}
.w b{font-size:20px;min-width:5em}.w span{flex:1;color:#666;font-size:14px}
button{font:inherit;border:1px solid #ccc;background:#fff;border-radius:8px;padding:6px 10px}
button.on[data-v=good]{background:#cfe8d4}button.on[data-v=meh]{background:#f2e6c4}button.on[data-v=bad]{background:#f1cfcf}
nav{display:flex;gap:8px;margin-top:12px}nav button{flex:1;padding:10px}
textarea{width:100%;box-sizing:border-box;font:inherit;margin-top:8px;border-radius:8px;border:1px solid #ccc;padding:8px}
</style><main><div class=top><span id=pos></span><span id=when></span></div><img id=img><div id=ws></div>
<textarea id=note rows=2 placeholder="이 사진에 더 맞는 말이 있으면 (선택)"></textarea>
<nav><button id=prev>← 이전</button><button id=next>다음 →</button></nav></main>
<script>
let items=[],v={},i=0;
const L={good:'맞음',meh:'애매',bad:'틀림'};
async function save(){await fetch('/v',{method:'POST',body:JSON.stringify(v)})}
function show(){const it=items[i];document.getElementById('img').src='/p/'+it.key+'.jpg';
document.getElementById('pos').textContent=(i+1)+' / '+items.length+' · 남은 사진 '+items.filter(x=>x.words.some(w=>!(v[x.key]||{})[w.id])).length;
document.getElementById('when').textContent=it.when;const ws=document.getElementById('ws');ws.innerHTML='';
const mine=v[it.key]||(v[it.key]={});document.getElementById('note').value=mine._note||'';
for(const w of it.words){const d=document.createElement('div');d.className='w';d.innerHTML='<b>'+w.word+'</b><span>'+w.meaning+'</span>';
for(const k of ['good','meh','bad']){const b=document.createElement('button');b.textContent=L[k];b.dataset.v=k;if(mine[w.id]===k)b.className='on';
b.onclick=()=>{mine[w.id]=k;save();show()};d.appendChild(b)}ws.appendChild(d)}}
document.getElementById('note').onchange=e=>{(v[items[i].key]||(v[items[i].key]={}))._note=e.target.value;save()};
document.getElementById('prev').onclick=()=>{if(i>0){i--;show()}};
document.getElementById('next').onclick=()=>{if(i<items.length-1){i++;show()}};
(async()=>{items=await (await fetch('/items')).json();v=await (await fetch('/verdicts')).json();
i=Math.max(0,items.findIndex(x=>x.words.some(w=>!(v[x.key]||{})[w.id])));show()})();
</script>"""


class H(BaseHTTPRequestHandler):
    def send(self, body, kind):
        data = body.encode() if isinstance(body, str) else body
        self.send_response(200)
        self.send_header("Content-Type", kind)
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == "/":
            self.send(PAGE, "text/html; charset=utf-8")
        elif self.path == "/items":
            self.send(json.dumps(items(), ensure_ascii=False), "application/json")
        elif self.path == "/verdicts":
            self.send(json.dumps(verdicts, ensure_ascii=False), "application/json")
        elif self.path.startswith("/p/") and "/" not in self.path[3:] and self.path.endswith(".jpg"):
            self.send(open(f"{LAB}/photos/{self.path[3:]}", "rb").read(), "image/jpeg")
        else:
            self.send_error(404)

    def do_POST(self):
        global verdicts
        verdicts = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        json.dump(verdicts, open(VERDICTS, "w"), ensure_ascii=False, indent=1)
        self.send("ok", "text/plain")

    def log_message(self, *a):
        pass


print("→ http://127.0.0.1:8765")
ThreadingHTTPServer(("127.0.0.1", 8765), H).serve_forever()
