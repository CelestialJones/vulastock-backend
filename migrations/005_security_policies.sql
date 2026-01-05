-- ============================================
-- MIGRATION 005: Políticas de Segurança (RLS)
-- ============================================

-- 1. POLÍTICAS PARA PROFILES
-- Usuário vê apenas seu próprio perfil
CREATE POLICY "Usuários veem apenas seu perfil" ON public.profiles
    FOR SELECT USING (auth.uid() = id);

-- Usuário pode atualizar apenas seu perfil
CREATE POLICY "Usuários atualizam apenas seu perfil" ON public.profiles
    FOR UPDATE USING (auth.uid() = id);

-- 2. POLÍTICAS PARA WAREHOUSES
-- Todos autenticados podem ver armazéns
CREATE POLICY "Todos autenticados veem armazéns" ON public.warehouses
    FOR SELECT USING (auth.role() = 'authenticated');

-- Apenas admins e supervisors podem modificar
CREATE POLICY "Apenas admins/supervisors gerenciam armazéns" ON public.warehouses
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'supervisor')
        )
    );

-- 3. POLÍTICAS PARA PRODUCTS
-- Todos autenticados podem ver produtos
CREATE POLICY "Todos autenticados veem produtos" ON public.products
    FOR SELECT USING (auth.role() = 'authenticated');

-- Apenas admins e supervisors podem criar/atualizar
CREATE POLICY "Apenas admins/supervisors criam produtos" ON public.products
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'supervisor')
        )
    );

CREATE POLICY "Apenas admins/supervisors atualizam produtos" ON public.products
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'supervisor')
        )
    );

-- 4. POLÍTICAS PARA STOCK_ITEMS
-- Todos autenticados podem ver estoque
CREATE POLICY "Todos autenticados veem estoque" ON public.stock_items
    FOR SELECT USING (auth.role() = 'authenticated');

-- Operadores podem fazer movimentações básicas
CREATE POLICY "Operadores gerenciam estoque" ON public.stock_items
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'supervisor', 'operator')
        )
    );

-- 5. POLÍTICAS PARA STOCK_MOVEMENTS
-- Todos autenticados veem movimentações
CREATE POLICY "Todos autenticados veem movimentações" ON public.stock_movements
    FOR SELECT USING (auth.role() = 'authenticated');

-- Apenas operadores+ podem criar movimentações
CREATE POLICY "Apenas operadores+ criam movimentações" ON public.stock_movements
    FOR INSERT WITH CHECK (
        EXISTS (
            SELECT 1 FROM public.profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'supervisor', 'operator')
        )
    );

-- 6. POLÍTICAS PARA ALERTS
-- Cada usuário vê apenas alerts relevantes
CREATE POLICY "Usuários veem alerts relevantes" ON public.alerts
    FOR SELECT USING (
        -- Admins veem tudo
        EXISTS (SELECT 1 FROM public.profiles WHERE id = auth.uid() AND role = 'admin')
        OR
        -- Outros veem apenas não resolvidos
        (is_read = FALSE)
    );

-- Apenas admins e supervisors podem marcar como resolvido
CREATE POLICY "Apenas admins/supervisors resolvem alerts" ON public.alerts
    FOR UPDATE USING (
        EXISTS (
            SELECT 1 FROM public.profiles 
            WHERE id = auth.uid() 
            AND role IN ('admin', 'supervisor')
        )
    );