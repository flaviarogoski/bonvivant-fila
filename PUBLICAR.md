# Fila do balcão Bon Vivant: como colocar no ar

São 4 telas, todas na mesma pasta:

| Tela | Arquivo | Onde fica |
|---|---|---|
| Cliente | `index.html` | No celular do cliente, aberta pelo QR code |
| Balcão | `balcao.html` | No tablet, celular ou computador da atendente (pede o PIN) |
| TV | `tv.html` | Na TV da loja, no lugar do painel eletrônico |
| Cartaz | `qrcode.html` | Para imprimir o QR code e deixar no balcão |

O banco é o **mesmo Supabase da precificação**. A fila usa tabelas próprias e não mexe em nada da precificação. O `config.js` já está preenchido com o endereço e a chave.

---

## 1. Criar a fila no Supabase (uma vez só)

1. Abra o arquivo **`fila.sql`** no Bloco de Notas.
2. Procure a linha com `TROQUE-ESTE-PIN` e troque pelo **PIN do balcão**: no mínimo 6 números, que só a equipe vai saber. Exemplo: `'482915'`.
3. No Supabase, entre no projeto da precificação → **SQL Editor** → **New query**.
4. Cole todo o conteúdo do `fila.sql` e clique em **Run**.
5. No final deve aparecer uma linha com `pin_definido = true`.

> Para trocar o PIN depois, rode no SQL Editor: `update fila_config set pin = 'NOVO-PIN';`

## 2. Publicar no GitHub Pages

O processo é o mesmo da precificação, mas num **repositório novo**, para não misturar os dois:

1. No GitHub, clique em **+ → New repository**. Use o nome `bonvivant-fila`, marque **Public** e clique em **Create**.
2. Clique em **uploading an existing file** e arraste **tudo** da pasta `BonVivant Fila`: os arquivos `.html`, `.js`, `.css` e `.png` e a pasta `fontes`. O `fila.sql` e este `PUBLICAR.md` podem ir junto ou ficar de fora. Depois clique em **Commit changes**.
3. Vá em **Settings → Pages**, escolha a branch **main** e a pasta **/ (root)**, e clique em **Save**.
4. Depois de 1 ou 2 minutos, aparece o endereço, algo como `https://SEU-USUARIO.github.io/bonvivant-fila/`.

Os endereços ficam assim:
- Cliente: `.../bonvivant-fila/`
- Balcão: `.../bonvivant-fila/balcao.html`
- TV: `.../bonvivant-fila/tv.html`
- Cartaz: `.../bonvivant-fila/qrcode.html`

## 3. Montar a TV

- Pode ser uma Smart TV com navegador, ou uma TV comum com um **Fire TV Stick** ou parecido, usando o navegador Silk ou outro.
- Abra o endereço da **TV** e salve nos favoritos.
- **Toque na tela uma vez** (ou aperte OK no controle) para ligar o som. A TV fica em tela cheia, toca um "plim" e fala "Senha 42" a cada chamada.
- Nas configurações da TV, **desligue o modo de economia de energia e o descanso de tela**.
- O QR code para os clientes já aparece na própria TV.

## 4. Montar o balcão

- Abra o endereço do **Balcão** no aparelho da atendente e digite o PIN. O aparelho guarda o PIN, então só precisa digitar uma vez.
- O aparelho precisa ter o **WhatsApp Business da loja**: o app no tablet ou celular, ou o WhatsApp Web no computador.
- Imprima o **Cartaz** (A5) e deixe no balcão, ao lado da máquina de senhas.

## 5. Antes de usar com clientes: teste completo

1. Abra a **TV**, o **Balcão** e, no seu celular, leia o QR code.
2. No celular, cadastre uma senha 3 números à frente da atual, com o seu WhatsApp.
3. No balcão, aperte **Chamar próxima**. A TV deve trocar o número e tocar o som.
4. Quando o aviso amarelo aparecer, toque em **Enviar WhatsApp** e envie. A mensagem deve chegar no seu celular.
5. Depois do teste, ajuste o número atual em **Ajustes** para bater com o papel.

## No dia a dia

- **A cada cliente:** apertar **Chamar próxima**. No computador, a barra de espaço também chama.
- **Aviso amarelo:** tocar em **Enviar WhatsApp** e depois em enviar no WhatsApp.
- **O número errou:** use **Ajustes → Corrigir número atual**, ou o botão **Voltar uma**.
- **O papel volta para 00 depois de 99?** O sistema já entende isso. Se o papel de vocês vai até outro número, ajuste em **Ajustes → Maior número do papel**.
- **Telefones:** são apagados sozinhos depois de 2 dias. A fila de WhatsApp recomeça a cada dia.
