import json,urllib.parse,urllib.request,sys,time
def probe(q):
    url=("https://suggestqueries.google.com/complete/search?client=firefox"
         "&hl=ko&gl=kr&ie=utf-8&oe=utf-8&q="+urllib.parse.quote(q))
    try:
        with urllib.request.urlopen(url,timeout=10) as r:
            raw=r.read()
        txt=None
        for enc in ('utf-8','cp949','euc-kr'):
            try: txt=raw.decode(enc); break
            except Exception: pass
        s=json.loads(txt)[1][:8]
    except Exception as e:
        s=[f'(오류 {e})']
    print(f'  「{q}」')
    print('     ', ' · '.join(s) if s else '(제안어 없음)')
for q in sys.argv[1:]:
    probe(q); time.sleep(0.4)
