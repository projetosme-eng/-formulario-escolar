-- ============================================
-- SCHEMA SUPABASE - Painel Administrativo
-- Formulário Transporte Escolar
-- Execute tudo no SQL Editor do Supabase
-- ============================================

-- 1. Criação da tabela principal (se não existir)
CREATE TABLE IF NOT EXISTS cadastro_transporte (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  created_at TIMESTAMPTZ DEFAULT NOW(),
  responsavel TEXT NOT NULL,
  endereco TEXT NOT NULL,
  aluno TEXT NOT NULL,
  escola TEXT NOT NULL,
  ano TEXT NOT NULL,
  rota TEXT NOT NULL,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION
);

-- 2. Tabela de usuários administradores (gerenciada pelo Supabase Auth)
--    Vamos usar a tabela auth.users já existente do Supabase.

-- 3. Tabela de auditoria (logs de ações dos admins)
CREATE TABLE IF NOT EXISTS admin_logs (
  id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  admin_id UUID REFERENCES auth.users(id),
  acao TEXT NOT NULL,
  detalhes JSONB,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- 4. Ativar Row Level Security
ALTER TABLE cadastro_transporte ENABLE ROW LEVEL SECURITY;
ALTER TABLE admin_logs ENABLE ROW LEVEL SECURITY;

-- 5. Políticas para cadastro_transporte
--    - Qualquer um pode INSERT (formulário público)
--    - Apenas admins autenticados podem SELECT
--    - Apenas admins podem DELETE

CREATE POLICY "insert_publico"
  ON cadastro_transporte FOR INSERT
  TO anon
  WITH CHECK (true);

CREATE POLICY "select_admin"
  ON cadastro_transporte FOR SELECT
  TO authenticated
  USING (auth.role() = 'authenticated');

CREATE POLICY "delete_admin"
  ON cadastro_transporte FOR DELETE
  TO authenticated
  USING (auth.role() = 'authenticated');

-- 6. Políticas para admin_logs
CREATE POLICY "insert_admin_log"
  ON admin_logs FOR INSERT
  TO authenticated
  WITH CHECK (auth.role() = 'authenticated');

CREATE POLICY "select_admin_log"
  ON admin_logs FOR SELECT
  TO authenticated
  USING (auth.role() = 'authenticated');

-- 7. Função para registrar log automaticamente
CREATE OR REPLACE FUNCTION log_admin_action()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO admin_logs (admin_id, acao, detalhes)
  VALUES (
    auth.uid(),
    TG_OP,
    jsonb_build_object(
      'tabela', TG_TABLE_NAME,
      'id', OLD.id,
      'aluno', OLD.aluno
    )
  );
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 8. Trigger para logar deleções
DROP TRIGGER IF EXISTS trg_log_delete ON cadastro_transporte;
CREATE TRIGGER trg_log_delete
  AFTER DELETE ON cadastro_transporte
  FOR EACH ROW
  EXECUTE FUNCTION log_admin_action();

-- 9. Índices para performance
CREATE INDEX IF NOT EXISTS idx_cadastro_created_at ON cadastro_transporte(created_at DESC);
CREATE INDEX IF NOT EXISTS idx_cadastro_escola ON cadastro_transporte(escola);
CREATE INDEX IF NOT EXISTS idx_cadastro_rota ON cadastro_transporte(rota);
CREATE INDEX IF NOT EXISTS idx_cadastro_aluno ON cadastro_transporte(aluno);
