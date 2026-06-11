-- =====================================================================
-- LIVIA.us — Configuracao do banco de dados no Supabase
-- Cole TODO este conteudo no SQL Editor do Supabase e clique em "Run".
-- Cria as tabelas, as regras de seguranca, as funcoes de login e os
-- dados de teste (UBS, contas e publicacoes).
-- =====================================================================

-- Para recriar do zero, descomente a linha abaixo:
-- drop table if exists mensagens, posts, usuarios, ubs cascade;

-- ------------------------- TABELAS -------------------------
create table if not exists ubs (
  id        text primary key,
  nome      text not null,
  bairro    text,
  lat       double precision,
  lng       double precision,
  endereco  text,
  horario   text,
  servicos  text[] default '{}',
  areas     text[] default '{}'
);

create table if not exists usuarios (
  id          uuid primary key default gen_random_uuid(),
  tipo        text not null check (tipo in ('cidadao','enfermeiro','coordenador')),
  nome        text not null,
  email       text unique,
  coren       text unique,
  ubs_id      text references ubs(id),
  senha       text not null,
  created_at  timestamptz default now()
);

create table if not exists posts (
  id          uuid primary key default gen_random_uuid(),
  tipo        text not null,
  titulo      text not null,
  descricao   text,
  data_evento date,
  local       text references ubs(id),
  publico     text,
  autor_id    uuid,
  autor_nome  text,
  status      text not null default 'pendente',
  created_at  timestamptz default now()
);

create table if not exists mensagens (
  id          uuid primary key default gen_random_uuid(),
  ubs_id      text references ubs(id),
  cidadao_id  uuid,
  autor_id    uuid,
  autor_nome  text,
  tipo        text,
  texto       text not null,
  ts          timestamptz default now()
);

-- ------------------------- SEGURANCA (RLS) -------------------------
alter table ubs       enable row level security;
alter table posts     enable row level security;
alter table mensagens enable row level security;
alter table usuarios  enable row level security;

-- ubs: leitura publica
drop policy if exists ubs_sel on ubs;
create policy ubs_sel on ubs for select using (true);

-- posts: app controla os papeis; liberado para leitura/escrita
drop policy if exists posts_sel on posts;  create policy posts_sel on posts for select using (true);
drop policy if exists posts_ins on posts;  create policy posts_ins on posts for insert with check (true);
drop policy if exists posts_upd on posts;  create policy posts_upd on posts for update using (true);
drop policy if exists posts_del on posts;  create policy posts_del on posts for delete using (true);

-- mensagens: leitura e insercao liberadas
drop policy if exists msg_sel on mensagens; create policy msg_sel on mensagens for select using (true);
drop policy if exists msg_ins on mensagens; create policy msg_ins on mensagens for insert with check (true);

-- usuarios: SEM politicas para anon. A tabela fica protegida e o acesso
-- so acontece pelas funcoes abaixo (a senha nunca e exposta ao app).

-- Privilegios de tabela para o app (papel anon):
grant select on ubs to anon, authenticated;
grant select, insert, update, delete on posts to anon, authenticated;
grant select, insert on mensagens to anon, authenticated;
-- (sem grant em usuarios para anon)

-- ------------------------- FUNCOES DE LOGIN/CADASTRO -------------------------
-- Retornam o usuario SEM a senha. Rodam como SECURITY DEFINER.
create or replace function _user_publico(u usuarios) returns jsonb
language sql stable as $$
  select jsonb_build_object('id',u.id,'tipo',u.tipo,'nome',u.nome,'email',u.email,'coren',u.coren,'ubs_id',u.ubs_id);
$$;

create or replace function login_email(p_email text, p_senha text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare u usuarios;
begin
  select * into u from usuarios where lower(email)=lower(trim(p_email)) and senha=p_senha limit 1;
  if not found then return jsonb_build_object('ok',false); end if;
  return jsonb_build_object('ok',true,'user',_user_publico(u));
end; $$;

create or replace function login_coren(p_coren text, p_senha text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare u usuarios;
begin
  select * into u from usuarios where tipo='enfermeiro' and lower(coren)=lower(trim(p_coren)) and senha=p_senha limit 1;
  if not found then return jsonb_build_object('ok',false); end if;
  return jsonb_build_object('ok',true,'user',_user_publico(u));
end; $$;

create or replace function cadastrar_cidadao(p_nome text, p_email text, p_senha text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare u usuarios;
begin
  if exists(select 1 from usuarios where lower(email)=lower(trim(p_email))) then
    return jsonb_build_object('ok',false,'erro','Ja existe uma conta com este e-mail.');
  end if;
  insert into usuarios(tipo,nome,email,senha)
    values('cidadao',trim(p_nome),trim(p_email),p_senha) returning * into u;
  return jsonb_build_object('ok',true,'user',_user_publico(u));
end; $$;

create or replace function cadastrar_enfermeiro(p_nome text, p_email text, p_coren text, p_ubs text, p_senha text)
returns jsonb language plpgsql security definer set search_path=public as $$
declare u usuarios;
begin
  if exists(select 1 from usuarios where lower(coren)=lower(trim(p_coren))) then
    return jsonb_build_object('ok',false,'erro','Ja existe um enfermeiro com este COREN.');
  end if;
  if exists(select 1 from usuarios where lower(email)=lower(trim(p_email))) then
    return jsonb_build_object('ok',false,'erro','Ja existe uma conta com este e-mail.');
  end if;
  insert into usuarios(tipo,nome,email,coren,ubs_id,senha)
    values('enfermeiro',trim(p_nome),trim(p_email),trim(p_coren),p_ubs,p_senha) returning * into u;
  return jsonb_build_object('ok',true,'user',_user_publico(u));
end; $$;

grant execute on function login_email(text,text)               to anon, authenticated;
grant execute on function login_coren(text,text)               to anon, authenticated;
grant execute on function cadastrar_cidadao(text,text,text)    to anon, authenticated;
grant execute on function cadastrar_enfermeiro(text,text,text,text,text) to anon, authenticated;

-- ------------------------- REALTIME (chat e feed ao vivo) -------------------------
do $$ begin
  alter publication supabase_realtime add table mensagens;
exception when duplicate_object then null; end $$;
do $$ begin
  alter publication supabase_realtime add table posts;
exception when duplicate_object then null; end $$;

-- ------------------------- DADOS DE TESTE -------------------------
insert into ubs (id,nome,bairro,lat,lng,endereco,horario,servicos,areas) values
 ('ubs01','UBS Centro','Centro',-3.1430,-58.4440,'Rua 7 de Setembro, 250 - Centro','Seg a Sex, 7h as 17h', array['Clinica geral','Vacinacao','Curativos','Pre-natal'], array['Centro','Eduardo Braga']),
 ('ubs02','UBS Sao Cristovao','Sao Cristovao',-3.1380,-58.4480,'Av. Mario Andreazza, 1020 - Sao Cristovao','Seg a Sex, 7h as 16h', array['Clinica geral','Odontologia','Vacinacao'], array['Sao Cristovao','Jauary']),
 ('ubs03','UBS Colonia','Colonia',-3.1492,-58.4402,'Rua da Colonia, 88 - Colonia','Seg a Sex, 8h as 17h', array['Clinica geral','Coleta de exames','Pre-natal'], array['Colonia','Tiradentes']),
 ('ubs04','UBS Jardim Adriana','Jardim Adriana',-3.1346,-58.4521,'Rua das Flores, 415 - Jardim Adriana','Seg a Sex, 7h as 17h', array['Clinica geral','Vacinacao','Saude da mulher'], array['Jardim Adriana','Nogueira Junior']),
 ('ubs05','UBS Iraci','Iraci',-3.1521,-58.4468,'Rua Iraci, 33 - Iraci','Seg a Sex, 7h as 16h', array['Clinica geral','Curativos','Vacinacao'], array['Iraci','Pedreiras']),
 ('ubs06','UBS Florestal','Florestal',-3.1408,-58.4361,'Av. Florestal, 700 - Florestal','Seg a Sex, 8h as 18h', array['Clinica geral','Odontologia','Pre-natal','Vacinacao'], array['Florestal','Pirikatuba'])
on conflict (id) do nothing;

insert into usuarios (tipo,nome,email,coren,ubs_id,senha) values
 ('cidadao','Maria Cidada','cidadao@livia.us',null,null,'123456'),
 ('coordenador','Coordenacao Municipal','coordenador@livia.us',null,null,'admin123')
on conflict do nothing;

insert into usuarios (tipo,nome,email,coren,ubs_id,senha) values
 ('enfermeiro','Enf. Marina Souza','enfermeira@livia.us','123456-AM','ubs01','enf123')
on conflict do nothing;

insert into posts (tipo,titulo,descricao,data_evento,local,publico,autor_nome,status,created_at) values
 ('Campanha','Campanha de vacinacao contra a gripe','Vacinacao gratuita para idosos, gestantes e criancas. Leve seu cartao do SUS.', current_date + 5,'ubs01','Idosos, gestantes e criancas','Enf. Marina Souza','aprovado', now() - interval '2 days'),
 ('Mutirao','Mutirao de saude da mulher','Coleta de preventivo e orientacoes sobre saude da mulher. Sem necessidade de agendamento.', current_date + 10,'ubs04','Mulheres a partir de 18 anos','Enf. Marina Souza','aprovado', now() - interval '1 day'),
 ('Comunicado','Horario especial no feriado','A UBS Florestal funcionara em horario reduzido no proximo feriado, das 8h as 12h.', current_date + 3,'ubs06','Comunidade em geral','Enf. Marina Souza','pendente', now());

-- Fim. As tabelas, funcoes e dados de teste estao prontos.
