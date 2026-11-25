/* ══════════════════════════════════════════════════════════
   CONFIGURAÇÃO DA FILA — Bon Vivant
   Enquanto SUPABASE_URL estiver vazio, tudo roda em MODO DEMONSTRAÇÃO:
   os dados ficam só neste navegador (bom para testar abrindo
   balcão, TV e cliente em abas diferentes do mesmo computador).
   ══════════════════════════════════════════════════════════ */
window.FILA_CONFIG = {
  // Mesmo projeto Supabase da precificação. Apague os dois valores (deixe '') para voltar ao modo demonstração.
  SUPABASE_URL:      'https://oyurrybsrwmhxeuzomfx.supabase.co',
  SUPABASE_ANON_KEY: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im95dXJyeWJzcndtaHhldXpvbWZ4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODE5ODMwNjUsImV4cCI6MjA5NzU1OTA2NX0.Iq-tn5oQSp46ljc8rkYf81znVYryMPTo7oM3Kkniqok',
  NOME_LOJA:         'Bon Vivant',
  // Endereço público do site (o que vai no QR code). Vazio = usa o endereço atual.
  URL_PUBLICA:       ''
};
