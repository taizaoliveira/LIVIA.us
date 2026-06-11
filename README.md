# LIVIA.us — PWA com banco compartilhado (Supabase)

App instalavel (PWA) de acesso as UBS de Itacoatiara/AM. Agora todos os
testadores compartilham o MESMO banco de dados (Supabase), e o chat funciona
em tempo real entre dispositivos diferentes.

## Passo a passo (uma vez so)

### 1. Crie o projeto no Supabase
1. Acesse https://supabase.com e crie uma conta (gratis).
2. New project. Escolha um nome e uma senha de banco. Aguarde subir.

### 2. Crie as tabelas e os dados
1. No menu lateral, abra **SQL Editor**.
2. Abra o arquivo `supabase_setup.sql` deste pacote, copie tudo e cole no editor.
3. Clique em **Run**. Deve aparecer "Success".

### 3. Pegue suas chaves
1. Va em **Project Settings > API**.
2. Copie o **Project URL** e a chave **anon public**.

### 4. Configure o app
1. Abra o arquivo `index.html` num editor de texto.
2. Logo no inicio do script, substitua:
   ```
   const SUPABASE_URL = 'COLE_SUA_URL_AQUI';
   const SUPABASE_ANON_KEY = 'COLE_SUA_ANON_KEY_AQUI';
   ```
   pelos seus valores reais.
3. Salve.

### 5. Publique e envie o link
- **Netlify Drop (mais facil):** acesse https://app.netlify.com/drop e arraste
  a pasta `livia-pwa` inteira. Sai um link HTTPS na hora.
- **GitHub Pages:** suba os arquivos num repositorio, ative em Settings > Pages.
- Envie o link. No celular, "Adicionar a tela inicial" instala como app.

> O PWA precisa de HTTPS (Netlify e GitHub Pages ja fornecem). Abrir o arquivo
> direto do computador (file://) nao registra o service worker nem conecta bem.

## Contas de teste (ja criadas pelo SQL)
- Cidadao: cidadao@livia.us / 123456
- Enfermeiro: COREN 123456-AM / enf123 (aba Profissional)
- Coordenador: coordenador@livia.us / admin123
- Visitante: botao "Entrar como visitante"

## Agora os dados sao compartilhados
- Um post aprovado pelo coordenador aparece no feed de todos os testadores.
- O chat e em tempo real entre o cidadao e o enfermeiro, em aparelhos diferentes.
- Novos cadastros valem para todo mundo.

## Seguranca (importante saber)
Este modelo foi pensado para TESTE/ACADEMICO. O login e cadastro passam por
funcoes do banco que nunca expoem a senha ao app, mas as senhas ficam
guardadas em texto na tabela `usuarios` e os papeis (quem pode publicar ou
aprovar) sao controlados pelo app, nao pelo banco. Para producao real, o
proximo passo seria usar o Supabase Auth com senhas criptografadas e regras
de acesso por papel (RLS por usuario). Posso te ajudar com isso se precisar.

## Observacoes
- Dados das UBS (nomes, enderecos, coordenadas) sao ficticios, so para teste.
- Mapa via OpenStreetMap. Comandos de voz funcionam melhor no Chrome.
- A tela offline mostra o app, mas os dados precisam de internet (banco na nuvem).

## Arquivos
- index.html .............. o aplicativo (cole suas chaves aqui)
- supabase_setup.sql ...... script para criar o banco no Supabase
- manifest.webmanifest .... identidade do PWA
- sw.js ................... service worker (cache offline do app)
- icons/ .................. icones do app
