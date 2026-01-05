-- ============================================
-- MIGRATION 001: Esquema Inicial do Banco
-- ============================================

-- =========================
-- Tabela de Perfis
-- =========================
CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
    email TEXT UNIQUE NOT NULL,
    full_name TEXT,
    role TEXT DEFAULT 'operator' CHECK (role IN ('admin', 'supervisor', 'operator')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE public.profiles IS 'Perfis de usuários do sistema';
COMMENT ON COLUMN public.profiles.role IS 'admin: acesso total, supervisor: gerência, operator: operações básicas';

-- =========================
-- Tabela de Armazéns
-- =========================
CREATE TABLE IF NOT EXISTS public.warehouses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name TEXT NOT NULL,
    code TEXT UNIQUE NOT NULL,
    address TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES public.profiles(id)
);

COMMENT ON TABLE public.warehouses IS 'Armazéns físicos';

-- =========================
-- Tabela de Produtos
-- =========================
CREATE TABLE IF NOT EXISTS public.products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sku TEXT UNIQUE NOT NULL,
    barcode TEXT,
    name TEXT NOT NULL,
    description TEXT,
    category TEXT,
    unit_of_measure TEXT DEFAULT 'un',
    min_stock INTEGER DEFAULT 10,
    max_stock INTEGER,
    image_url TEXT,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES public.profiles(id)
);

COMMENT ON TABLE public.products IS 'Cadastro de produtos';
COMMENT ON COLUMN public.products.unit_of_measure IS 'Unidade de medida: un, kg, m, l, etc';

-- =========================
-- Tabela de Localizações
-- =========================
CREATE TABLE IF NOT EXISTS public.locations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    warehouse_id UUID REFERENCES public.warehouses(id) ON DELETE CASCADE,
    code TEXT NOT NULL,
    name TEXT NOT NULL,
    description TEXT,
    max_capacity INTEGER,
    current_usage INTEGER DEFAULT 0,
    is_active BOOLEAN DEFAULT TRUE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    UNIQUE (warehouse_id, code)
);

COMMENT ON TABLE public.locations IS 'Localizações internas dos armazéns';

-- =========================
-- ENUM: Tipo de Movimentação
-- =========================
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_type WHERE typname = 'movement_type'
  ) THEN
    CREATE TYPE public.movement_type AS ENUM (
      'entry',
      'exit',
      'adjustment',
      'transfer'
    );
  END IF;
END$$;

-- =========================
-- Tabela de Itens em Estoque
-- =========================
CREATE TABLE IF NOT EXISTS public.stock_items (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    product_id UUID REFERENCES public.products(id) ON DELETE CASCADE,
    location_id UUID REFERENCES public.locations(id),
    batch_number TEXT,
    serial_number TEXT UNIQUE,
    expiration_date DATE,
    quantity INTEGER NOT NULL CHECK (quantity >= 0),
    unit_cost DECIMAL(10,2),
    total_value DECIMAL(10,2) GENERATED ALWAYS AS (quantity * unit_cost) STORED,
    status TEXT DEFAULT 'available'
        CHECK (status IN ('available', 'reserved', 'expired', 'damaged')),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES public.profiles(id),
    UNIQUE (product_id, batch_number, serial_number)
);

COMMENT ON TABLE public.stock_items IS 'Itens específicos em estoque com lote/série';

-- =========================
-- Tabela de Movimentações
-- =========================
CREATE TABLE IF NOT EXISTS public.stock_movements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    stock_item_id UUID REFERENCES public.stock_items(id),
    movement_type public.movement_type NOT NULL,
    quantity INTEGER NOT NULL,
    from_location_id UUID REFERENCES public.locations(id),
    to_location_id UUID REFERENCES public.locations(id),
    reference_number TEXT,
    reason TEXT,
    notes TEXT,
    movement_date TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    created_by UUID REFERENCES public.profiles(id),
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE public.stock_movements IS 'Histórico completo de todas as movimentações';

-- =========================
-- Tabela de Alertas
-- =========================
CREATE TABLE IF NOT EXISTS public.alerts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    type TEXT CHECK (type IN ('low_stock', 'expiration', 'custom')),
    product_id UUID REFERENCES public.products(id),
    message TEXT NOT NULL,
    priority TEXT DEFAULT 'medium'
        CHECK (priority IN ('low', 'medium', 'high')),
    is_read BOOLEAN DEFAULT FALSE,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    resolved_at TIMESTAMP WITH TIME ZONE,
    resolved_by UUID REFERENCES public.profiles(id)
);

COMMENT ON TABLE public.alerts IS 'Sistema de alertas e notificações';

-- =========================
-- Tabela de Auditoria
-- =========================
CREATE TABLE IF NOT EXISTS public.audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES public.profiles(id),
    action TEXT NOT NULL,
    table_name TEXT,
    record_id UUID,
    old_data JSONB,
    new_data JSONB,
    ip_address TEXT,
    user_agent TEXT,
    created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

COMMENT ON TABLE public.audit_logs IS 'Log completo de ações dos usuários';

-- =========================
-- Índices
-- =========================
CREATE INDEX IF NOT EXISTS idx_profiles_email ON public.profiles(email);
CREATE INDEX IF NOT EXISTS idx_products_sku ON public.products(sku);
CREATE INDEX IF NOT EXISTS idx_products_category ON public.products(category);
CREATE INDEX IF NOT EXISTS idx_stock_items_product_id ON public.stock_items(product_id);
CREATE INDEX IF NOT EXISTS idx_stock_items_location_id ON public.stock_items(location_id);
CREATE INDEX IF NOT EXISTS idx_stock_items_expiration ON public.stock_items(expiration_date);
CREATE INDEX IF NOT EXISTS idx_stock_movements_created_at ON public.stock_movements(created_at);
CREATE INDEX IF NOT EXISTS idx_alerts_type ON public.alerts(type);
CREATE INDEX IF NOT EXISTS idx_alerts_is_read ON public.alerts(is_read);
