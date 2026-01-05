-- ============================================
-- MIGRATION 004: Sample data (DEV ONLY)
-- ============================================

-- ⚠️ NÃO criar usuários auth aqui
-- Usuários devem ser criados via Dashboard Auth

-- Exemplo: criar warehouses, produtos, etc
INSERT INTO public.warehouses (name, code)
VALUES ('Armazém Central', 'CENTRAL')
ON CONFLICT DO NOTHING;

INSERT INTO public.products (sku, name)
VALUES ('PROD-001', 'Produto de Teste')
ON CONFLICT DO NOTHING;
