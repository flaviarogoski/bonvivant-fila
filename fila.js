/* Fila Bon Vivant — funções compartilhadas pelas 4 telas (cliente, balcão, TV, QR) */
(function () {
  const C = window.FILA_CONFIG || {};
  const DEMO = !C.SUPABASE_URL;

  /* ── formatos ─────────────────────────────────────────── */
  const limpaTel = v => {
    let d = String(v || '').replace(/\D/g, '');
    if (d.length > 11 && d.startsWith('55')) d = d.slice(2);
    return (d.length === 10 || d.length === 11) ? d : null;
  };
  const fmtTel = t => !t ? '' : t.length === 11
    ? `(${t.slice(0, 2)}) ${t.slice(2, 7)}-${t.slice(7)}`
    : `(${t.slice(0, 2)}) ${t.slice(2, 6)}-${t.slice(6)}`;
  const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
  const frente = (s, atual, max) => { const n = max + 1; return (((s - atual - 1) % n) + n) % n; };
  const pessoas = n => n === 0 ? 'ninguém' : n === 1 ? '1 pessoa' : `${n} pessoas`;
  const primeiroNome = s => String(s || '').trim().split(/\s+/)[0] || '';

  const msgAviso = (nome, senha, n) =>
    `Olá, ${primeiroNome(nome)}! Aqui é da ${C.NOME_LOJA || 'Bon Vivant'}. ` +
    `Sua senha ${senha} está chegando: ` +
    (n <= 0 ? 'ela é a próxima' : `falta${n > 1 ? 'm' : ''} ${pessoas(n)} na sua frente`) +
    `. Pode se aproximar do balcão, por favor. Obrigado pela paciência!`;

  const linkWhats = (tel, texto) => `https://wa.me/55${tel}?text=${encodeURIComponent(texto)}`;

  const urlPublica = () => {
    if (C.URL_PUBLICA) return C.URL_PUBLICA;
    const u = new URL('./', location.href); return u.href;
  };

  /* ── servidor (Supabase) ─────────────────────────────── */
  async function rpcSupabase(fn, args) {
    let r;
    try {
      r = await fetch(`${C.SUPABASE_URL.replace(/\/$/, '')}/rest/v1/rpc/${fn}`, {
        method: 'POST',
        headers: {
          apikey: C.SUPABASE_ANON_KEY,
          Authorization: 'Bearer ' + C.SUPABASE_ANON_KEY,
          'Content-Type': 'application/json'
        },
        body: JSON.stringify(args || {})
      });
    } catch (e) {
      throw new Error('Sem internet ou servidor fora do ar. Tentando de novo…');
    }
    const txt = await r.text();
    let j = null; try { j = txt ? JSON.parse(txt) : null; } catch (e) { }
    if (!r.ok) {
      const m = j && (j.message || j.hint);
      if (r.status === 404) throw new Error('A fila ainda não foi instalada no Supabase (falta rodar o fila.sql).');
      throw new Error(m || `Erro do servidor (${r.status}).`);
    }
    return j;
  }

  /* ── modo demonstração (guarda tudo no navegador) ────── */
  const DKEY = 'bvfila-demo-v1';
  const hojeStr = () => new Date().toLocaleDateString('sv-SE', { timeZone: 'America/Sao_Paulo' });
  const uid = () => (crypto.randomUUID ? crypto.randomUUID() : String(Date.now()) + Math.random());
  function dLer() {
    let d = null; try { d = JSON.parse(localStorage.getItem(DKEY)); } catch (e) { }
    if (!d) {
      const agora = new Date().toISOString(), h = hojeStr();
      d = {
        cfg: { atual: 41, chamado_em: agora, aviso: 2, max_senha: 99, pin: '123456', ultimas: [40, 39, 38] },
        cli: [
          { nome: 'Beatriz Souza', tel: '41999110002', senha: 44 },
          { nome: 'Carlos', tel: '41999110003', senha: 46 },
          { nome: 'Marina Lopes', tel: '41999110004', senha: 47 },
          { nome: 'Júlio', tel: '41999110005', senha: 50 }
        ].map(c => ({ ...c, id: uid(), token: uid(), status: 'aguardando', origem: 'qr', criado_em: agora, dia: h }))
      };
      dGravar(d);
    }
    return d;
  }
  function dGravar(d) { try { localStorage.setItem(DKEY, JSON.stringify(d)); } catch (e) { } }
  function dEstado(d) {
    const c = d.cfg, h = hojeStr();
    const clientes = d.cli.filter(x => ['aguardando', 'avisado'].includes(x.status) && x.dia === h)
      .map(x => ({ id: x.id, senha: x.senha, nome: x.nome, tel: x.tel, status: x.status, origem: x.origem, criado_em: x.criado_em, frente: frente(x.senha, c.atual, c.max_senha) }))
      .sort((a, b) => a.frente - b.frente);
    return { atual: c.atual, chamado_em: c.chamado_em, aviso: c.aviso, max_senha: c.max_senha, ultimas: c.ultimas, clientes };
  }
  function dPin(d, p) { if (p !== d.cfg.pin) throw new Error('PIN incorreto.'); }
  function dInserir(d, senha, nome, tel, origem) {
    const c = d.cfg, n = String(nome || '').trim().slice(0, 40), t = limpaTel(tel), h = hojeStr();
    senha = parseInt(senha, 10);
    if (isNaN(senha) || senha < 0 || senha > c.max_senha) throw new Error(`Confira o número da senha (de 0 a ${c.max_senha}).`);
    if (!n) throw new Error('Digite o nome.');
    if (!t) throw new Error('Confira o celular: DDD + número, ex.: (41) 99999-0000.');
    if (senha === c.atual) throw new Error(`A senha ${senha} já está sendo chamada agora. Vá até o balcão.`);
    if (d.cli.some(x => x.senha === senha && ['aguardando', 'avisado'].includes(x.status) && x.dia === h))
      throw new Error(`A senha ${senha} já tem um WhatsApp cadastrado. Se for a sua, fale com o balcão.`);
    const r = { id: uid(), token: uid(), senha, nome: n, tel: t, status: 'aguardando', origem, criado_em: new Date().toISOString(), dia: h };
    d.cli.push(r); return r;
  }
  async function rpcDemo(fn, a) {
    await new Promise(r => setTimeout(r, 120));
    const d = dLer(), c = d.cfg, N = c.max_senha + 1, h = hojeStr();
    let out;
    switch (fn) {
      case 'fila_publico': out = { atual: c.atual, chamado_em: c.chamado_em, ultimas: c.ultimas, aviso: c.aviso, max_senha: c.max_senha }; break;
      case 'fila_entrar': out = { token: dInserir(d, a.p_senha, a.p_nome, a.p_tel, 'qr').token }; break;
      case 'fila_minha': {
        const f = d.cli.find(x => x.token === a.p_token);
        out = f ? { senha: f.senha, nome: primeiroNome(f.nome), status: f.status, atual: c.atual, chamado_em: c.chamado_em, aviso: c.aviso, frente: frente(f.senha, c.atual, c.max_senha), hoje: f.dia === h } : null;
        break;
      }
      case 'fila_sair': { const f = d.cli.find(x => x.token === a.p_token && ['aguardando', 'avisado'].includes(x.status)); if (f) f.status = 'removido'; out = null; break; }
      case 'fila_balcao': dPin(d, a.p_pin); out = dEstado(d); break;
      case 'fila_chamar': {
        dPin(d, a.p_pin); const old = c.atual; const p = Math.sign(a.p_passos);
        c.atual = (((old + p) % N) + N) % N; c.chamado_em = new Date().toISOString();
        c.ultimas = p > 0 ? [old, ...c.ultimas].slice(0, 3) : c.ultimas.slice(1, 4);
        if (p > 0) d.cli.forEach(x => { if (x.senha === c.atual && ['aguardando', 'avisado'].includes(x.status) && x.dia === h) x.status = 'atendido'; });
        else d.cli.forEach(x => { if (x.senha === old && x.status === 'atendido' && x.dia === h) x.status = x.avisado_em ? 'avisado' : 'aguardando'; });
        out = dEstado(d); break;
      }
      case 'fila_rechamar': dPin(d, a.p_pin); c.chamado_em = new Date().toISOString(); out = dEstado(d); break;
      case 'fila_ajustar': {
        dPin(d, a.p_pin);
        if (a.p_max >= 9 && a.p_max <= 9999) c.max_senha = a.p_max;
        if (a.p_aviso >= 1 && a.p_aviso <= 20) c.aviso = a.p_aviso;
        if (a.p_atual != null && a.p_atual >= 0 && a.p_atual <= c.max_senha && a.p_atual !== c.atual) {
          const pulo = frente(a.p_atual, c.atual, c.max_senha) + 1;
          if (pulo <= Math.floor((c.max_senha + 1) / 2))
            d.cli.forEach(x => { if (['aguardando', 'avisado'].includes(x.status) && x.dia === h && frente(x.senha, c.atual, c.max_senha) < pulo) x.status = 'atendido'; });
          c.atual = a.p_atual; c.chamado_em = new Date().toISOString();
        }
        out = dEstado(d); break;
      }
      case 'fila_cadastrar': dPin(d, a.p_pin); dInserir(d, a.p_senha, a.p_nome, a.p_tel, 'balcao'); out = dEstado(d); break;
      case 'fila_marcar': {
        dPin(d, a.p_pin); const f = d.cli.find(x => x.id === a.p_id);
        if (f) { f.status = a.p_status; if (a.p_status === 'avisado') f.avisado_em = new Date().toISOString(); }
        out = dEstado(d); break;
      }
      default: throw new Error('Função desconhecida: ' + fn);
    }
    dGravar(d); return out;
  }

  window.FILA = {
    DEMO, C, limpaTel, fmtTel, esc, frente, pessoas, primeiroNome, msgAviso, linkWhats, urlPublica,
    rpc: (fn, args) => DEMO ? rpcDemo(fn, args || {}) : rpcSupabase(fn, args),
    resetDemo: () => { try { localStorage.removeItem(DKEY); } catch (e) { } }
  };
})();
