"""v6 블라인드 판정 페이지 — 맥스튜디오 안에서만 연다(127.0.0.1).
실행: python3 judge.py [--port 8766] [--arms qwen35-v4,.student-coreml-8m-v6] [--sets mongdol,fresh30] → http://127.0.0.1:8766
사진마다 갈래(지금 규칙 + --arms 의 answers/ 폴더들)가 고른 v6 단어를 모아 같은 id 는 한 번만, 섞어서 보인다. 갈래 이름은 화면에 없다.
판정은 $MONGDOL_LAB(기본 ~/mongdol-word-lab)/verdicts-v6.json 에 {key: {v6id: good|meh|bad, _note}} 로 쌓는다.
그 파일이 없으면 처음 한 번 옛 verdicts.json 의 판정을 단어 글자로 v6 id 에 옮겨 씨앗으로 쓴다.
python3 judge.py --report — 서버 대신 set·갈래마다 맞음/틀림/결 있고 맞음 표와 학생 「최근 14장 피하기」·fresh500 다양성을 찍고 끝낸다."""
import argparse
import glob
import json
import os
import random
from collections import Counter
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

HERE = os.path.dirname(os.path.abspath(__file__))
LAB = os.path.expanduser(os.environ.get("MONGDOL_LAB", "~/mongdol-word-lab"))
VERDICTS = f"{LAB}/verdicts-v6.json"
words = {w["id"]: w for w in json.load(open(f"{HERE}/../Shared/Word/words.json"))["words"]}
by_word = {w["word"]: i for i, w in words.items()}
plain = {t for line in open(f"{HERE}/plain_words.txt") if not line.startswith("#") for t in line.split()}


def load_rows():
    rows = []
    for name in ("eval.json", "fresh.json"):
        p = f"{LAB}/v6/{name}"
        if os.path.exists(p):
            rows += json.load(open(p))
    return rows


def answer(arm, key):
    p = f"{LAB}/answers/{arm}/{key}.json"
    return json.load(open(p)) if os.path.exists(p) else None


def pick(arm, r):
    """갈래가 이 행에서 고른 v6 id. 선생 id 는 d-·옛 id 일 수 있어 글자로만 찾는다."""
    if arm == "rule":
        return r["rule"] if r["rule"] in words else None
    a = answer(arm, r["key"])
    return by_word.get((a.get("word") or "").strip()) if a else None


def seed_verdicts():
    old_path = f"{LAB}/verdicts.json"
    old = json.load(open(old_path)) if os.path.exists(old_path) else {}
    old_word = {}
    for p in sorted(glob.glob(f"{LAB}/words-expanded*.json")):
        old_word.update({w["id"]: w["word"] for w in json.load(open(p))})
    if os.path.exists(f"{LAB}/words.json"):
        old_word.update({w["id"]: w["word"] for w in json.load(open(f"{LAB}/words.json"))})
    out, moved, dropped = {}, 0, 0
    for key, vs in old.items():
        mine = {}
        for oid, v in vs.items():
            if oid == "_note":
                if v:
                    mine["_note"] = v
                continue
            nid = by_word.get((old_word.get(oid) or "").strip())
            if nid and nid not in mine:
                mine[nid] = v
                moved += 1
            else:
                dropped += 1
        if mine:
            out[key] = mine
    json.dump(out, open(VERDICTS, "w"), ensure_ascii=False, indent=1)
    print(f"옛 판정 씨앗: {moved}개 옮김, {dropped}개 버림 → {VERDICTS}")
    return out


def items(rows, arms):
    out = []
    for r in rows:
        ids = []
        for arm in ["rule"] + arms:
            i = pick(arm, r)
            if i and i not in ids:
                ids.append(i)
        random.Random("judge-v6:" + r["key"]).shuffle(ids)
        weather = r.get("weather") or ""
        out.append({"key": r["key"], "when": f"{r['local']} {r['partOfDay']} {weather}".strip(),
                    "words": [{"id": i, "word": words[i]["word"], "meaning": words[i]["meaning"]} for i in ids]})
    random.Random("judge-v6-order").shuffle(out)
    return out


def report(rows, arms, verdicts):
    bar = {"mongdol": 7, "fresh30": 5}
    ok = lambda b: "✓" if b else " "
    for s, bad_max in bar.items():
        rs = [r for r in rows if r["set"] == s]
        print(f"\n[{s}] {len(rs)}장 — 기준: 맞음 ≥70%, 틀림 ≤{bad_max}, 결 있고 맞음 ≥40%")
        print(f"{'갈래':<36}{'답':>5}{'판정':>6}{'맞음%':>9}{'틀림':>6}{'결맞음%':>9}")
        for arm in ["rule"] + arms:
            got = [(r, i) for r in rs if (i := pick(arm, r))]
            judged = [(r, i, verdicts[r["key"]][i]) for r, i in got if verdicts.get(r["key"], {}).get(i)]
            n = len(judged)
            good = sum(v == "good" for _, _, v in judged)
            bad = sum(v == "bad" for _, _, v in judged)
            rich = sum(v == "good" and words[i]["word"] not in plain for _, i, v in judged)
            gp, rp = (100 * good / n, 100 * rich / n) if n else (0, 0)
            print(f"{arm:<36}{len(got):>5}{n:>6}{gp:>7.0f}%{ok(n and gp >= 70)}{bad:>5}{ok(n and bad <= bad_max)}"
                  f"{rp:>7.0f}%{ok(n and rp >= 40)}")
    mongdol = sorted((r for r in rows if r["set"] == "mongdol"), key=lambda r: r["local"])
    fresh500 = [r for r in rows if r["set"] == "fresh500"]
    for arm in arms:
        ranked = [(a or {}).get("ranked") for a in (answer(arm, r["key"]) for r in mongdol)]
        if not any(ranked):
            continue
        recent, picked = [], Counter()
        for rk in ranked:
            if not rk:
                continue
            w = next((i for i in rk if i not in recent), rk[0])
            picked[w] += 1
            recent = (recent + [w])[-14:]
        top, cnt = picked.most_common(1)[0]
        print(f"\n[{arm}] 최근 14장 피하기(mongdol {sum(picked.values())}장): 가장 많이 나온 말 "
              f"{words.get(top, {}).get('word', top)} {cnt}번 {ok(cnt <= 4)} (기준 ≤4)")
        firsts = Counter(a["id"] for r in fresh500 if (a := answer(arm, r["key"])) and a.get("ranked") is not None and a.get("id"))
        if firsts:
            n = sum(firsts.values())
            share = 100 * sum(c for _, c in firsts.most_common(20)) / n
            print(f"  fresh500 {n}장: 1등 서로 다른 말 {len(firsts)}개, 상위 20개 비중 {share:.0f}% {ok(share <= 50)} (기준 ≤50%)")


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


def serve(port, rows, arms, verdicts):
    state = {"v": verdicts}

    class H(BaseHTTPRequestHandler):
        def send(self, body, kind):
            data = body.encode() if isinstance(body, str) else body
            self.send_response(200)
            self.send_header("Content-Type", kind)
            self.end_headers()
            self.wfile.write(data)

        def do_GET(self):
            name = self.path[3:]
            if self.path == "/":
                self.send(PAGE, "text/html; charset=utf-8")
            elif self.path == "/items":
                self.send(json.dumps(items(rows, arms), ensure_ascii=False), "application/json")
            elif self.path == "/verdicts":
                self.send(json.dumps(state["v"], ensure_ascii=False), "application/json")
            elif self.path.startswith("/p/") and "/" not in name and name.endswith(".jpg"):
                p = f"{LAB}/{'photos-fresh' if name.startswith('n-') else 'photos'}/{name}"
                if os.path.exists(p):
                    self.send(open(p, "rb").read(), "image/jpeg")
                else:
                    self.send_error(404)
            else:
                self.send_error(404)

        def do_POST(self):
            state["v"] = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
            json.dump(state["v"], open(VERDICTS, "w"), ensure_ascii=False, indent=1)
            self.send("ok", "text/plain")

        def log_message(self, *a):
            pass

    print(f"사진 {len(rows)}장, 갈래 rule{''.join(',' + a for a in arms)} → http://127.0.0.1:{port}")
    ThreadingHTTPServer(("127.0.0.1", port), H).serve_forever()


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--port", type=int, default=8766)
    ap.add_argument("--arms", default="")
    ap.add_argument("--sets", default="mongdol,fresh30")
    ap.add_argument("--report", action="store_true")
    args = ap.parse_args()
    arms = [a for a in args.arms.split(",") if a]
    rows = load_rows()
    verdicts = json.load(open(VERDICTS)) if os.path.exists(VERDICTS) else seed_verdicts()
    if args.report:
        report(rows, arms, verdicts)
    else:
        sets = set(args.sets.split(","))
        serve(args.port, [r for r in rows if r["set"] in sets], arms, verdicts)
