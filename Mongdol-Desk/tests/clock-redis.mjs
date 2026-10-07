// 시계 달린 메모리 Redis — Mongdol-ENFP-Web/tests/clock-redis.mjs 를 옮겨 와 정렬 집합을 더했다.
export class ClockRedis {
  constructor() { this.t = 0; this.kv = new Map(); this.exp = new Map(); this.z = new Map(); }
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
  async mget(...ks) { return Promise.all(ks.map((k) => this.get(k))); }
  // 정렬 집합(TTL 없음) — 건의하기 색인이 쓴다. zrange 는 순위(rank) 범위와 { rev } 만.
  async zadd(k, ...entries) { const z = this.z.get(k) ?? new Map(); this.z.set(k, z); for (const { score, member } of entries) z.set(member, score); return entries.length; }
  async zcard(k) { return this.z.get(k)?.size ?? 0; }
  async zrem(k, ...ms) { const z = this.z.get(k); let n = 0; for (const m of ms) n += +(z?.delete(m) ?? 0); return n; }
  async zrange(k, start, stop, o = {}) {
    const rows = [...(this.z.get(k) ?? new Map())].sort((a, b) => a[1] - b[1]).map(([m]) => m);
    if (o.rev) rows.reverse();
    return rows.slice(start, stop < 0 ? rows.length + stop + 1 : stop + 1);
  }
  keys() { return [...this.kv.keys()].filter((k) => this.alive(k)).concat([...this.z.keys()].filter((k) => this.z.get(k).size)); }
}
