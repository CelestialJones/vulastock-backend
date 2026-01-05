-- ============================================
-- MIGRATION 003: Triggers de Negócio
-- ============================================

-- Função para atualizar estoque após movimentação
CREATE OR REPLACE FUNCTION public.handle_stock_movement()
RETURNS TRIGGER AS $$
DECLARE
    v_product_id UUID;
    v_from_location_id UUID;
    v_to_location_id UUID;
    v_current_quantity INTEGER;
BEGIN
    -- Obter informações do item de estoque
    SELECT product_id, location_id, quantity 
    INTO v_product_id, v_from_location_id, v_current_quantity
    FROM public.stock_items 
    WHERE id = NEW.stock_item_id;

    -- ATENÇÃO: Esta é uma versão simplificada!
    -- Em produção, você precisaria de lógica mais complexa
    
    IF NEW.movement_type = 'entry' THEN
        -- Entrada: aumenta quantidade
        UPDATE public.stock_items 
        SET quantity = quantity + NEW.quantity
        WHERE id = NEW.stock_item_id;
        
    ELSIF NEW.movement_type = 'exit' THEN
        -- Saída: verifica se tem estoque suficiente
        IF v_current_quantity < NEW.quantity THEN
            RAISE EXCEPTION 'Estoque insuficiente. Disponível: %, Solicitado: %', 
                v_current_quantity, NEW.quantity;
        END IF;
        
        -- Diminui quantidade
        UPDATE public.stock_items 
        SET quantity = quantity - NEW.quantity
        WHERE id = NEW.stock_item_id;
        
    ELSIF NEW.movement_type = 'transfer' THEN
        -- Transferência: move entre localizações
        -- 1. Diminui na origem
        UPDATE public.stock_items 
        SET quantity = quantity - NEW.quantity
        WHERE id = NEW.stock_item_id;
        
        -- 2. Cria ou atualiza no destino
        INSERT INTO public.stock_items (
            product_id, location_id, batch_number,
            serial_number, expiration_date, quantity,
            unit_cost, created_by
        )
        SELECT 
            product_id, NEW.to_location_id, batch_number,
            serial_number, expiration_date, NEW.quantity,
            unit_cost, NEW.created_by
        FROM public.stock_items 
        WHERE id = NEW.stock_item_id
        ON CONFLICT (product_id, batch_number, serial_number) 
        DO UPDATE SET 
            quantity = public.stock_items.quantity + EXCLUDED.quantity;
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para movimentações de estoque
CREATE TRIGGER on_stock_movement
    AFTER INSERT ON public.stock_movements
    FOR EACH ROW
    EXECUTE FUNCTION public.handle_stock_movement();

-- Função para verificar estoque baixo
CREATE OR REPLACE FUNCTION public.check_low_stock()
RETURNS TRIGGER AS $$
DECLARE
    v_product_name TEXT;
    v_min_stock INTEGER;
    v_total_quantity INTEGER;
BEGIN
    -- Obter informações do produto
    SELECT name, min_stock INTO v_product_name, v_min_stock
    FROM public.products 
    WHERE id = NEW.product_id;
    
    -- Calcular quantidade total em estoque
    SELECT COALESCE(SUM(quantity), 0) INTO v_total_quantity
    FROM public.stock_items 
    WHERE product_id = NEW.product_id 
    AND status = 'available';
    
    -- Verificar se está abaixo do mínimo
    IF v_total_quantity <= v_min_stock THEN
        INSERT INTO public.alerts (
            type, product_id, message, priority
        ) VALUES (
            'low_stock',
            NEW.product_id,
            format('Estoque baixo: %s. Quantidade: %s (Mínimo: %s)', 
                   v_product_name, v_total_quantity, v_min_stock),
            'high'
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para verificar estoque baixo
CREATE TRIGGER check_stock_after_change
    AFTER INSERT OR UPDATE ON public.stock_items
    FOR EACH ROW
    EXECUTE FUNCTION public.check_low_stock();

-- Função para verificar validade
CREATE OR REPLACE FUNCTION public.check_expiration()
RETURNS TRIGGER AS $$
BEGIN
    -- Verificar se o produto está perto de expirar (30 dias)
    IF NEW.expiration_date IS NOT NULL 
       AND NEW.expiration_date <= (CURRENT_DATE + INTERVAL '30 days') 
       AND NEW.expiration_date > CURRENT_DATE THEN
        
        INSERT INTO public.alerts (
            type, product_id, message, priority
        ) VALUES (
            'expiration',
            NEW.product_id,
            format('Produto vencendo em %s dias: %s', 
                   NEW.expiration_date - CURRENT_DATE,
                   (SELECT name FROM public.products WHERE id = NEW.product_id)),
            'medium'
        );
        
    -- Verificar se expirou
    ELSIF NEW.expiration_date IS NOT NULL 
          AND NEW.expiration_date <= CURRENT_DATE THEN
        
        UPDATE public.stock_items 
        SET status = 'expired'
        WHERE id = NEW.id;
        
        INSERT INTO public.alerts (
            type, product_id, message, priority
        ) VALUES (
            'expiration',
            NEW.product_id,
            format('PRODUTO VENCIDO: %s (Data: %s)', 
                   (SELECT name FROM public.products WHERE id = NEW.product_id),
                   NEW.expiration_date),
            'high'
        );
    END IF;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Trigger para verificar validade
CREATE TRIGGER check_expiration_date
    AFTER INSERT OR UPDATE OF expiration_date ON public.stock_items
    FOR EACH ROW
    EXECUTE FUNCTION public.check_expiration();