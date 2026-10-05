"""사전 후보 고르기 페이지 — 맥스튜디오 안에서만(127.0.0.1:8766). 실행: python3 pick_words.py
갈래별로 넘기며 단어마다 넣기·빼기. 고른 것은 ~/mongdol-word-lab/word-picks.json 에 쌓인다."""
import json
import os
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

LAB = os.path.expanduser("~/mongdol-word-lab")
words = json.load(open(f"{LAB}/dict-candidates.json"))
PICKS = f"{LAB}/word-picks.json"
picks = json.load(open(PICKS)) if os.path.exists(PICKS) else {}
ORDER = ["모임·사람", "빛·하늘", "먹는 일", "마음·순간", "날씨", "계절", "때", "집·살림", "길·마을",
         "물·땅", "꽃·풀·나무", "동물", "일·놀이", "물건"]

PAGE = """<!doctype html><meta charset=utf-8><meta name=viewport content="width=device-width,initial-scale=1">
<title>몽돌 단어 고르기</title>
<style>
body{font:16px -apple-system,sans-serif;margin:0;background:#f6f4ef;color:#222}
main{max-width:760px;margin:auto;padding:16px}
nav{display:flex;flex-wrap:wrap;gap:6px;position:sticky;top:0;background:#f6f4ef;padding:8px 0;z-index:1}
nav button{font:inherit;font-size:14px;border:1px solid #ccc;background:#fff;border-radius:16px;padding:4px 10px}
nav button.on{background:#222;color:#fff}
.w{background:#fff;border-radius:10px;padding:10px 12px;margin:8px 0;display:grid;grid-template-columns:1fr auto;gap:4px 10px}
.w b{font-size:19px}.w .d{color:#555;font-size:14px;grid-column:1}.w .y{color:#999;font-size:13px;grid-column:1}
.w .bt{grid-row:1/4;grid-column:2;display:flex;flex-direction:column;gap:6px;justify-content:center}
.bt button{font:inherit;border:1px solid #ccc;background:#fff;border-radius:8px;padding:6px 12px}
.bt button.on[data-v=in]{background:#cfe8d4}.bt button.on[data-v=out]{background:#eee;color:#999}
.w.out b{color:#aaa}
#sum{color:#777;font-size:14px;margin:4px 0}
</style><main><nav id=nav></nav><div id=sum></div><div id=list></div></main>
<script>
let words=[],picks={},cat=null;const ORDER=__ORDER__;
async function save(){await fetch('/p',{method:'POST',body:JSON.stringify(picks)})}
function nav(){const n=document.getElementById('nav');n.innerHTML='';for(const c of ORDER){const ws=words.filter(w=>w.cat===c);
const done=ws.filter(w=>picks[w.word]).length;const b=document.createElement('button');b.textContent=c+' '+done+'/'+ws.length;
if(c===cat)b.className='on';b.onclick=()=>{cat=c;show();scrollTo(0,0)};n.appendChild(b)}}
function show(){nav();const ws=words.filter(w=>w.cat===cat);const L=document.getElementById('list');L.innerHTML='';
const ins=Object.values(picks).filter(v=>v==='in').length;
document.getElementById('sum').textContent='넣은 단어 전체 '+ins+'개 · 이 갈래에서 넣기 '+ws.filter(w=>picks[w.word]==='in').length;
for(const w of ws){const d=document.createElement('div');d.className='w'+(picks[w.word]==='out'?' out':'');
d.innerHTML='<b>'+w.word+'</b><div class=d>'+w.def+'</div><div class=y>'+w.why+'</div>';
const bt=document.createElement('div');bt.className='bt';
for(const [k,t] of [['in','넣기'],['out','빼기']]){const b=document.createElement('button');b.textContent=t;b.dataset.v=k;
if(picks[w.word]===k)b.classList.add('on');b.onclick=()=>{picks[w.word]===k?delete picks[w.word]:picks[w.word]=k;save();show()};bt.appendChild(b)}
d.appendChild(bt);L.appendChild(d)}}
(async()=>{words=await (await fetch('/words')).json();picks=await (await fetch('/picks')).json();cat=ORDER[0];show()})();
</script>""".replace("__ORDER__", json.dumps(ORDER, ensure_ascii=False))


class H(BaseHTTPRequestHandler):
    def send(self, body, kind):
        data = body.encode()
        self.send_response(200)
        self.send_header("Content-Type", kind)
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        if self.path == "/":
            self.send(PAGE, "text/html; charset=utf-8")
        elif self.path == "/words":
            self.send(json.dumps(words, ensure_ascii=False), "application/json")
        elif self.path == "/picks":
            self.send(json.dumps(picks, ensure_ascii=False), "application/json")
        else:
            self.send_error(404)

    def do_POST(self):
        global picks
        picks = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        json.dump(picks, open(PICKS, "w"), ensure_ascii=False, indent=0)
        self.send("ok", "text/plain")

    def log_message(self, *a):
        pass


print("→ http://127.0.0.1:8766  (끝낼 땐 Ctrl+C)")
ThreadingHTTPServer(("127.0.0.1", 8766), H).serve_forever()
