-- ============================================================================
-- RLS - ARMAZÉM DO NECA
-- ============================================================================

-- ============================================================================
-- 1. TAX_GROUPS
-- ============================================================================

CREATE POLICY tax_groups_select ON tax_groups FOR SELECT TO PUBLIC
USING (auth_role() IN ('ADMIN', 'GERENTE', 'CONTADOR', 'ESTOQUISTA'));

CREATE POLICY tax_groups_modify ON tax_groups FOR ALL TO PUBLIC
USING (auth_role() IN ('ADMIN', 'CONTADOR'))
WITH CHECK (auth_role() IN ('ADMIN', 'CONTADOR'));

-- ============================================================================
-- 2. SUPPLIERS
-- ============================================================================

CREATE POLICY suppliers_select ON suppliers FOR SELECT TO PUBLIC
USING (auth_role() IN ('ADMIN', 'GERENTE', 'ESTOQUISTA', 'CONTADOR'));

CREATE POLICY suppliers_modify ON suppliers FOR ALL TO PUBLIC
USING (auth_role() IN ('ADMIN', 'GERENTE'))
WITH CHECK (auth_role() IN ('ADMIN', 'GERENTE'));

-- ============================================================================
-- 3. RECIPES
-- ============================================================================

CREATE POLICY recipes_select ON recipes FOR SELECT TO PUBLIC
USING (auth_role() IN ('ADMIN', 'GERENTE', 'CAIXA', 'ESTOQUISTA'));

CREATE POLICY recipes_modify ON recipes FOR ALL TO PUBLIC
USING (auth_role() IN ('ADMIN', 'GERENTE'))
WITH CHECK (auth_role() IN ('ADMIN', 'GERENTE'));

-- ============================================================================
-- 4. USER_ADDRESSES
-- ============================================================================

CREATE POLICY addresses_select ON user_addresses FOR SELECT TO PUBLIC
USING (
    auth_role() IN ('ADMIN', 'GERENTE', 'CAIXA', 'CONTADOR')
    OR user_id = auth_uid()
);

CREATE POLICY addresses_modify ON user_addresses FOR ALL TO PUBLIC
USING (
    auth_role() IN ('ADMIN', 'GERENTE')
    OR user_id = auth_uid()
)
WITH CHECK (
    auth_role() IN ('ADMIN', 'GERENTE')
    OR user_id = auth_uid()
);

-- ============================================================================
-- 5. SALE_PAYMENTS
-- ============================================================================

CREATE POLICY sale_payments_select ON sale_payments FOR SELECT TO PUBLIC
USING (
    auth_role() IN ('ADMIN', 'GERENTE', 'CONTADOR')
    OR EXISTS (
        SELECT 1 FROM sales s 
        WHERE s.id = sale_payments.sale_id 
        AND (s.salesperson_id = auth_uid() OR s.customer_id = auth_uid())
    )
);

CREATE POLICY sale_payments_insert ON sale_payments FOR INSERT TO PUBLIC
WITH CHECK (auth_role() IN ('ADMIN', 'GERENTE', 'CAIXA'));

-- Pagamentos não devem ser editados ou deletados após criados (auditoria)
CREATE POLICY sale_payments_no_modify ON sale_payments FOR UPDATE TO PUBLIC
USING (auth_role() = 'ADMIN');

CREATE POLICY sale_payments_no_delete ON sale_payments FOR DELETE TO PUBLIC
USING (auth_role() = 'ADMIN');

-- ============================================================================
-- 6. TAB_PAYMENTS
-- ============================================================================

CREATE POLICY tab_payments_select ON tab_payments FOR SELECT TO PUBLIC
USING (
    auth_role() IN ('ADMIN', 'GERENTE', 'CONTADOR')
    OR EXISTS (
        SELECT 1 FROM sales s 
        WHERE s.id = tab_payments.sale_id 
        AND (s.customer_id = auth_uid() OR s.salesperson_id = auth_uid())
    )
);

CREATE POLICY tab_payments_insert ON tab_payments FOR INSERT TO PUBLIC
WITH CHECK (auth_role() IN ('ADMIN', 'GERENTE', 'CAIXA'));

-- Pagamentos de fiado não devem ser editados após registro
CREATE POLICY tab_payments_no_modify ON tab_payments FOR UPDATE TO PUBLIC
USING (auth_role() = 'ADMIN');

CREATE POLICY tab_payments_no_delete ON tab_payments FOR DELETE TO PUBLIC
USING (auth_role() = 'ADMIN');

-- ============================================================================
-- 7. BATCHES
-- ============================================================================

CREATE POLICY batches_select ON batches FOR SELECT TO PUBLIC
USING (auth_role() IN ('ADMIN', 'GERENTE', 'ESTOQUISTA', 'CONTADOR'));

CREATE POLICY batches_modify ON batches FOR ALL TO PUBLIC
USING (auth_role() IN ('ADMIN', 'GERENTE', 'ESTOQUISTA'))
WITH CHECK (auth_role() IN ('ADMIN', 'GERENTE', 'ESTOQUISTA'));

-- ============================================================================
-- 8. USERS
-- ============================================================================

-- READ - Mantém a mesma lógica
CREATE POLICY users_select ON users FOR SELECT TO PUBLIC
USING (
    auth_role() IN ('ADMIN', 'GERENTE', 'CAIXA', 'CONTADOR')
    OR id = auth_uid()
);

-- INSERT - Apenas staff pode criar usuários
CREATE POLICY users_insert ON users FOR INSERT TO PUBLIC
WITH CHECK (auth_role() IN ('ADMIN', 'GERENTE', 'CAIXA'));

-- UPDATE - Usuários podem editar apenas campos não-sensíveis
CREATE POLICY users_update ON users FOR UPDATE TO PUBLIC
USING (
    auth_role() IN ('ADMIN', 'GERENTE')
    OR id = auth_uid()
)
WITH CHECK (
    -- ADMIN e GERENTE podem alterar tudo
    auth_role() IN ('ADMIN', 'GERENTE')
    OR (
        -- Usuário só pode alterar seu próprio perfil E
        id = auth_uid() 
        AND role = OLD.role  -- NÃO pode mudar o próprio role
        AND credit_limit = OLD.credit_limit -- NÃO pode aumentar crédito
        AND invoice_amount = OLD.invoice_amount -- NÃO pode zerar dívida
    )
);

-- DELETE - Apenas ADMIN
CREATE POLICY users_delete ON users FOR DELETE TO PUBLIC
USING (auth_role() = 'ADMIN');

-- ============================================================================
-- 9. SALES
-- ============================================================================

CREATE POLICY sales_update ON sales FOR UPDATE TO PUBLIC
USING (
    auth_role() IN ('ADMIN', 'GERENTE') 
    OR (auth_role() = 'CAIXA' AND salesperson_id = auth_uid() AND status = 'ABERTA')
)
WITH CHECK (
    auth_role() IN ('ADMIN', 'GERENTE') 
    OR (auth_role() = 'CAIXA' AND salesperson_id = auth_uid() AND status = 'ABERTA')
);

-- Apenas ADMIN pode deletar vendas concluídas
CREATE POLICY sales_delete ON sales FOR DELETE TO PUBLIC
USING (
    auth_role() = 'ADMIN'
    OR (auth_role() IN ('GERENTE', 'CAIXA') AND status = 'ABERTA')
);

-- ============================================================================
-- 10. STOCK_MOVEMENTS
-- ============================================================================

CREATE POLICY stock_insert ON stock_movements FOR INSERT TO PUBLIC
WITH CHECK (auth_role() IN ('ADMIN', 'GERENTE', 'ESTOQUISTA'));

-- Movimentações não devem ser editadas (auditoria)
CREATE POLICY stock_no_update ON stock_movements FOR UPDATE TO PUBLIC
USING (auth_role() = 'ADMIN');

-- Movimentações não devem ser deletadas (auditoria)
CREATE POLICY stock_no_delete ON stock_movements FOR DELETE TO PUBLIC
USING (auth_role() = 'ADMIN');

-- ============================================================================
-- 11. PRICE_AUDITS
-- ============================================================================

CREATE POLICY audit_insert ON price_audits FOR INSERT TO PUBLIC
WITH CHECK (auth_role() IN ('ADMIN', 'GERENTE'));

CREATE POLICY audit_no_modify ON price_audits FOR UPDATE TO PUBLIC
USING (auth_role() = 'ADMIN');

CREATE POLICY audit_no_delete ON price_audits FOR DELETE TO PUBLIC
USING (auth_role() = 'ADMIN');

-- ============================================================================
-- 12. REFRESH_TOKENS2
-- ============================================================================

ALTER TABLE refresh_tokens ENABLE ROW LEVEL SECURITY;

-- Usuários só veem seus próprios tokens
CREATE POLICY tokens_select ON refresh_tokens FOR SELECT TO PUBLIC
USING (
    auth_role() = 'ADMIN'
    OR user_id = auth_uid()
);

-- Apenas o sistema pode criar tokens (via backend, não direto)
CREATE POLICY tokens_insert ON refresh_tokens FOR INSERT TO PUBLIC
WITH CHECK (auth_role() = 'ADMIN');

-- Usuários podem revogar seus próprios tokens (logout)
CREATE POLICY tokens_update ON refresh_tokens FOR UPDATE TO PUBLIC
USING (
    auth_role() = 'ADMIN'
    OR user_id = auth_uid()
)
WITH CHECK (
    auth_role() = 'ADMIN'
    OR (user_id = auth_uid() AND revoked = true) -- Só permite revogar
);

-- Apenas ADMIN pode deletar tokens
CREATE POLICY tokens_delete ON refresh_tokens FOR DELETE TO PUBLIC
USING (auth_role() = 'ADMIN');

-- ============================================================================
-- 13. LOGS
-- ============================================================================

ALTER TABLE logs ENABLE ROW LEVEL SECURITY;

-- Apenas staff técnico pode ler logs
CREATE POLICY logs_select ON logs FOR SELECT TO PUBLIC
USING (auth_role() IN ('ADMIN', 'GERENTE'));

-- Sistema pode inserir logs (geralmente via backend service account)
CREATE POLICY logs_insert ON logs FOR INSERT TO PUBLIC
WITH CHECK (true); -- Permite inserção, mas leitura é restrita

-- Logs não devem ser editados ou deletados
CREATE POLICY logs_no_modify ON logs FOR UPDATE TO PUBLIC
USING (auth_role() = 'ADMIN');

CREATE POLICY logs_no_delete ON logs FOR DELETE TO PUBLIC
USING (auth_role() = 'ADMIN');

-- ============================================================================
-- 14. PRODUCTS
-- ============================================================================

CREATE POLICY products_insert ON products FOR INSERT TO PUBLIC
WITH CHECK (auth_role() IN ('ADMIN', 'GERENTE', 'ESTOQUISTA'));

CREATE POLICY products_update ON products FOR UPDATE TO PUBLIC
USING (auth_role() IN ('ADMIN', 'GERENTE', 'ESTOQUISTA'))
WITH CHECK (auth_role() IN ('ADMIN', 'GERENTE', 'ESTOQUISTA'));

CREATE POLICY products_delete ON products FOR DELETE TO PUBLIC
USING (auth_role() IN ('ADMIN', 'GERENTE'));

-- ============================================================================
-- 15. CATEGORIES - Melhorar separação
-- ============================================================================

CREATE POLICY categories_insert ON categories FOR INSERT TO PUBLIC
WITH CHECK (auth_role() IN ('ADMIN', 'GERENTE', 'ESTOQUISTA'));

CREATE POLICY categories_update ON categories FOR UPDATE TO PUBLIC
USING (auth_role() IN ('ADMIN', 'GERENTE', 'ESTOQUISTA'))
WITH CHECK (auth_role() IN ('ADMIN', 'GERENTE', 'ESTOQUISTA'));

CREATE POLICY categories_delete ON categories FOR DELETE TO PUBLIC
USING (auth_role() IN ('ADMIN', 'GERENTE'));

-- ============================================================================
-- 16. SALE_ITEMS
-- ============================================================================

CREATE POLICY sale_items_insert ON sale_items FOR INSERT TO PUBLIC
WITH CHECK (auth_role() IN ('ADMIN', 'GERENTE', 'CAIXA'));

CREATE POLICY sale_items_update ON sale_items FOR UPDATE TO PUBLIC
USING (
    auth_role() IN ('ADMIN', 'GERENTE')
    OR EXISTS (
        SELECT 1 FROM sales s 
        WHERE s.id = sale_items.sale_id 
        AND s.status = 'ABERTA'
        AND auth_role() = 'CAIXA'
    )
)
WITH CHECK (
    auth_role() IN ('ADMIN', 'GERENTE')
    OR EXISTS (
        SELECT 1 FROM sales s 
        WHERE s.id = sale_items.sale_id 
        AND s.status = 'ABERTA'
        AND auth_role() = 'CAIXA'
    )
);

CREATE POLICY sale_items_delete ON sale_items FOR DELETE TO PUBLIC
USING (
    auth_role() IN ('ADMIN', 'GERENTE')
    OR EXISTS (
        SELECT 1 FROM sales s 
        WHERE s.id = sale_items.sale_id 
        AND s.status = 'ABERTA'
        AND auth_role() = 'CAIXA'
    )
);

-- ============================================================================
-- COMENTÁRIOS FINAIS
-- ============================================================================

COMMENT ON POLICY users_update ON users IS 
'Usuários podem editar apenas campos não-sensíveis do próprio perfil. 
CRÍTICO: Previne autoelevação de privilégios verificando OLD.role';

COMMENT ON POLICY tokens_update ON refresh_tokens IS 
'Usuários podem apenas revogar (logout) seus próprios tokens, não criar novos';

COMMENT ON POLICY logs_insert ON logs IS 
'Permite inserção de logs mas restringe leitura a staff autorizado';