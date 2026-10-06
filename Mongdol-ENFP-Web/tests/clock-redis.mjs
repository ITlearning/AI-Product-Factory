// 시계 달린 메모리 Redis — 서버 시험과 브라우저 확인이 같이 쓴다.
export class ClockRedis {
  constructor() { this.t = 0; this.kv = new Map(); this.exp = new Map(); }
  tick(sec) { this.t += sec * 1000; }
  alive(k) {
    const e = this.exp.get(k);
    if (e != null && e <= this.t) { this.kv.delete(k); this.exp.delete(k); }
    return this.kv.has(k);
  }
  async get(k) { return this.alive(k) ? this.kv.get(k) : null; }
  async set(k, v, o = {}) {
    if (o.nx && this.alive(k)) return null;
    this.kv.set(k, v);
    if (o.ex) this.exp.set(k, this.t + o.ex * 1000); else this.exp.delete(k);
    return 'OK';
  }
  async del(...ks) { let n = 0; for (const k of ks) if (this.alive(k)) { this.kv.delete(k); this.exp.delete(k); n++; } return n; }
  async exists(...ks) { return ks.filter((k) => this.alive(k)).length; }
  async expire(k, s) { if (!this.alive(k)) return 0; this.exp.set(k, this.t + s * 1000); return 1; }
  async incr(k) { const n = Number((await this.get(k)) ?? 0) + 1; this.kv.set(k, n); return n; }
  keys() { return [...this.kv.keys()].filter((k) => this.alive(k)); }
}
