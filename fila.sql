-- ════════════════════════════════════════════════════════════════
--  FILA DO BALCÃO — Bon Vivant
--  Rodar UMA VEZ no Supabase: SQL Editor → New query → colar tudo → Run.
--
--  ANTES DE RODAR: troque o PIN do balcão na linha marcada com  <<< PIN
--  (mínimo 6 caracteres; é o que a atendente digita para abrir a tela do balcão).
--
--  Segurança: as tabelas ficam fechadas (RLS ligado e sem regras).
--  Ninguém lê nada direto: tudo passa pelas funções abaixo.
--  - Cliente: só entra na fila e vê a própria posição (pelo código do celular dele).
--  - TV: só vê o número chamado (sem nomes nem telefones).
--  - Balcão: vê nomes e telefones, mas só com o PIN.
--  Telefones são apagados sozinhos depois de 2 dias.
--
--  Pode rodar de novo sem perder nada (não apaga dados nem troca o PIN já salvo).
-- ════════════════════════════════════════════════════════════════

create table if not exists fila_config (
  id          int primary key default 1 check (id = 1),
  atual       int not null default 0,
  chamado_em  timestamptz not null default now(),
  aviso       int not null default 2,
  max_senha   int not null default 99,
  pin         text not null,
  ultimas     int[] not null default '{}'
);

insert into fila_config (id, pin)
values (1, 'TROQUE-ESTE-PIN')          -- <<< PIN: troque pelo PIN do balcão antes de rodar
on conflict (id) do nothing;

create table if not exists fila_clientes (
  id          uuid primary key default gen_random_uuid(),
  token       uuid not null unique default gen_random_uuid(),
  senha       int not null,
  nome        text not null,
  tel         text not null,
  status      text not null default 'aguardando'
              check (status in ('aguardando','avisado','atendido','removido')),
  origem      text not null default 'qr',
  criado_em   timestamptz not null default now(),
  avisado_em  timestamptz
);
create index if not exists fila_clientes_criado_idx on fila_clientes (criado_em);

alter table fila_config   enable row level security;
alter table fila_clientes enable row level security;
revoke all on fila_config, fila_clientes from anon, authenticated;


-- ── Ajudantes ───────────────────────────────────────────────────
-- Quantas pessoas estão na frente de uma senha (o papel volta para 0 depois do máximo)
create or replace function fila_frente(p_senha int, p_atual int, p_max int)
returns int language sql immutable as $$
  select (((p_senha - p_atual - 1) % (p_max + 1)) + (p_max + 1)) % (p_max + 1);
$$;

-- Foi criado hoje (horário de Brasília)?
create or replace function fila_hoje(p_quando timestamptz)
returns boolean language sql stable as $$
  select (p_quando at time zone 'America/Sao_Paulo')::date
       = (now()    at time zone 'America/Sao_Paulo')::date;
$$;

create or replace function fila__checar_pin(p_pin text)
returns void language plpgsql security definer set search_path = public as $$
begin
  if exists (select 1 from fila_config where id = 1 and pin = 'TROQUE-ESTE-PIN') then
    raise exception 'O PIN do balcão ainda não foi definido no Supabase.';
  end if;
  if not exists (select 1 from fila_config where id = 1 and pin = p_pin) then
    perform pg_sleep(1);  -- atrasa quem tenta adivinhar
    raise exception 'PIN incorreto.';
  end if;
end $$;

create or replace function fila__estado()
returns json language sql stable security definer set search_path = public as $$
  select json_build_object(
    'atual', c.atual, 'chamado_em', c.chamado_em, 'aviso', c.aviso,
    'max_senha', c.max_senha, 'ultimas', c.ultimas,
    'clientes', coalesce((
      select json_agg(json_build_object(
               'id', f.id, 'senha', f.senha, 'nome', f.nome, 'tel', f.tel,
               'status', f.status, 'origem', f.origem, 'criado_em', f.criado_em,
               'frente', fila_frente(f.senha, c.atual, c.max_senha))
             order by fila_frente(f.senha, c.atual, c.max_senha))
      from fila_clientes f
      where f.status in ('aguardando','avisado') and fila_hoje(f.criado_em)
    ), '[]'::json))
  from fila_config c where c.id = 1;
$$;

create or replace function fila__inserir(p_senha int, p_nome text, p_tel text, p_origem text)
returns fila_clientes language plpgsql security definer set search_path = public as $$
declare c fila_config; n text; t text; r fila_clientes;
begin
  select * into c from fila_config where id = 1;
  n := left(btrim(coalesce(p_nome, '')), 40);
  t := regexp_replace(coalesce(p_tel, ''), '\D', '', 'g');
  if length(t) > 11 and left(t, 2) = '55' then t := substr(t, 3); end if;

  if p_senha is null or p_senha < 0 or p_senha > c.max_senha then
    raise exception 'Confira o número da senha (de 0 a %).', c.max_senha;
  end if;
  if n = '' then raise exception 'Digite o nome.'; end if;
  if length(t) not in (10, 11) then
    raise exception 'Confira o celular: DDD + número, ex.: (41) 99999-0000.';
  end if;
  if p_senha = c.atual then
    raise exception 'A senha % já está sendo chamada agora. Vá até o balcão.', p_senha;
  end if;
  if exists (select 1 from fila_clientes
             where senha = p_senha and status in ('aguardando','avisado') and fila_hoje(criado_em)) then
    raise exception 'A senha % já tem um WhatsApp cadastrado. Se for a sua, fale com o balcão.', p_senha;
  end if;
  if (select count(*) from fila_clientes where fila_hoje(criado_em)) >= 600 then
    raise exception 'Limite de cadastros do dia atingido. Fale com o balcão.';
  end if;

  insert into fila_clientes (senha, nome, tel, origem)
  values (p_senha, n, t, p_origem) returning * into r;
  return r;
end $$;


-- ── Funções públicas (cliente e TV) ─────────────────────────────
create or replace function fila_publico()
returns json language sql stable security definer set search_path = public as $$
  select json_build_object('atual', atual, 'chamado_em', chamado_em, 'ultimas', ultimas,
                           'aviso', aviso, 'max_senha', max_senha)
  from fila_config where id = 1;
$$;

create or replace function fila_entrar(p_senha int, p_nome text, p_tel text)
returns json language plpgsql security definer set search_path = public as $$
declare r fila_clientes;
begin
  r := fila__inserir(p_senha, p_nome, p_tel, 'qr');
  return json_build_object('token', r.token);
end $$;

create or replace function fila_minha(p_token uuid)
returns json language sql stable security definer set search_path = public as $$
  select json_build_object(
    'senha', f.senha, 'nome', split_part(f.nome, ' ', 1), 'status', f.status,
    'atual', c.atual, 'chamado_em', c.chamado_em, 'aviso', c.aviso,
    'frente', fila_frente(f.senha, c.atual, c.max_senha),
    'hoje', fila_hoje(f.criado_em))
  from fila_clientes f, fila_config c
  where f.token = p_token and c.id = 1;
$$;

create or replace function fila_sair(p_token uuid)
returns void language sql security definer set search_path = public as $$
  update fila_clientes set status = 'removido'
  where token = p_token and status in ('aguardando','avisado');
$$;


-- ── Funções do balcão (pedem o PIN) ─────────────────────────────
create or replace function fila_balcao(p_pin text)
returns json language plpgsql security definer set search_path = public as $$
begin
  perform fila__checar_pin(p_pin);
  return fila__estado();
end $$;

-- p_passos = 1 chama a próxima; -1 volta uma
create or replace function fila_chamar(p_pin text, p_passos int)
returns json language plpgsql security definer set search_path = public as $$
declare c fila_config; n int; novo int;
begin
  perform fila__checar_pin(p_pin);
  select * into c from fila_config where id = 1 for update;
  n := c.max_senha + 1;
  novo := (((c.atual + sign(p_passos)::int) % n) + n) % n;

  update fila_config set
    atual = novo,
    chamado_em = now(),
    ultimas = case when p_passos > 0 then (array[c.atual] || c.ultimas)[1:3]
                   else coalesce(c.ultimas[2:4], '{}') end
  where id = 1;

  if p_passos > 0 then
    update fila_clientes set status = 'atendido'
    where senha = novo and status in ('aguardando','avisado') and fila_hoje(criado_em);
  else
    update fila_clientes
    set status = case when avisado_em is null then 'aguardando' else 'avisado' end
    where senha = c.atual and status = 'atendido' and fila_hoje(criado_em);
  end if;

  delete from fila_clientes where criado_em < now() - interval '2 days';
  return fila__estado();
end $$;

-- Toca o aviso na TV de novo, sem mudar o número
create or replace function fila_rechamar(p_pin text)
returns json language plpgsql security definer set search_path = public as $$
begin
  perform fila__checar_pin(p_pin);
  update fila_config set chamado_em = now() where id = 1;
  return fila__estado();
end $$;

-- Ajustes: corrigir o número atual, quando avisar e o maior número do papel
create or replace function fila_ajustar(p_pin text, p_atual int, p_aviso int, p_max int)
returns json language plpgsql security definer set search_path = public as $$
declare c fila_config; pulo int;
begin
  perform fila__checar_pin(p_pin);
  select * into c from fila_config where id = 1 for update;
  if p_max is not null and p_max between 9 and 9999 then c.max_senha := p_max; end if;
  if p_aviso is not null and p_aviso between 1 and 20 then c.aviso := p_aviso; end if;

  if p_atual is not null and p_atual between 0 and c.max_senha and p_atual <> c.atual then
    pulo := fila_frente(p_atual, c.atual, c.max_senha) + 1;   -- quantas senhas andou para frente
    if pulo <= (c.max_senha + 1) / 2 then                       -- pulo para frente: quem ficou para trás já foi
      update fila_clientes set status = 'atendido'
      where status in ('aguardando','avisado') and fila_hoje(criado_em)
        and fila_frente(senha, c.atual, c.max_senha) < pulo;
    end if;
    c.atual := p_atual;
    c.chamado_em := now();
  end if;

  update fila_config set atual = c.atual, aviso = c.aviso, max_senha = c.max_senha,
                         chamado_em = c.chamado_em where id = 1;
  return fila__estado();
end $$;

create or replace function fila_cadastrar(p_pin text, p_senha int, p_nome text, p_tel text)
returns json language plpgsql security definer set search_path = public as $$
begin
  perform fila__checar_pin(p_pin);
  perform fila__inserir(p_senha, p_nome, p_tel, 'balcao');
  return fila__estado();
end $$;

create or replace function fila_marcar(p_pin text, p_id uuid, p_status text)
returns json language plpgsql security definer set search_path = public as $$
begin
  perform fila__checar_pin(p_pin);
  if p_status = 'avisado' then
    update fila_clientes set status = 'avisado', avisado_em = now() where id = p_id;
  elsif p_status = 'removido' then
    update fila_clientes set status = 'removido' where id = p_id;
  else
    raise exception 'Ação inválida.';
  end if;
  return fila__estado();
end $$;


-- ── Quem pode chamar o quê ──────────────────────────────────────
revoke execute on function fila__checar_pin(text)                  from public, anon, authenticated;
revoke execute on function fila__estado()                          from public, anon, authenticated;
revoke execute on function fila__inserir(int, text, text, text)    from public, anon, authenticated;

grant execute on function fila_publico()                           to anon, authenticated;
grant execute on function fila_entrar(int, text, text)             to anon, authenticated;
grant execute on function fila_minha(uuid)                         to anon, authenticated;
grant execute on function fila_sair(uuid)                          to anon, authenticated;
grant execute on function fila_balcao(text)                        to anon, authenticated;
grant execute on function fila_chamar(text, int)                   to anon, authenticated;
grant execute on function fila_rechamar(text)                      to anon, authenticated;
grant execute on function fila_ajustar(text, int, int, int)        to anon, authenticated;
grant execute on function fila_cadastrar(text, int, text, text)    to anon, authenticated;
grant execute on function fila_marcar(text, uuid, text)            to anon, authenticated;

-- Conferência: deve mostrar 1 linha com atual = 0
select atual, aviso, max_senha, (pin <> 'TROQUE-ESTE-PIN') as pin_definido from fila_config;
