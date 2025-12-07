

-- ============================================================================
-- VIEWS - Relatórios e consultas pré-configuradas
-- ============================================================================

-- === VIEW: Produtos com estoque baixo ===
CREATE OR REPLACE VIEW vw_low_stock_products AS
SELECT 
    p.id,
    p.sku,
    p.name,
    c.name as category,
    p.stock_quantity,
    p.min_stock_quantity,
    p.max_stock_quantity,
    (p.min_stock_quantity - p.stock_quantity) as quantity_to_order,
    p.purchase_price,
    ((p.min_stock_quantity - p.stock_quantity) * p.purchase_price) as estimated_cost
FROM 
    products p
    INNER JOIN categories c ON p.category_id = c.id
WHERE 
    p.is_active = TRUE 
    AND p.stock_quantity <= p.min_stock_quantity
ORDER BY 
    (p.min_stock_quantity - p.stock_quantity) DESC;

COMMENT ON VIEW vw_low_stock_products IS 
'Produtos que atingiram o estoque mínimo e precisam de reposição';

-- === VIEW: Produtos mais vendidos ===
CREATE OR REPLACE VIEW vw_top_selling_products AS
SELECT 
    p.id,
    p.name,
    p.sku,
    c.name as category,
    COUNT(si.id) as times_sold,
    SUM(si.quantity) as total_quantity_sold,
    SUM(si.subtotal) as total_revenue,
    SUM(si.quantity * si.unit_cost_price) as total_cost,
    SUM(si.subtotal - (si.quantity * COALESCE(si.unit_cost_price, 0))) as total_profit
FROM 
    products p
    INNER JOIN categories c ON p.category_id = c.id
    INNER JOIN sale_items si ON p.id = si.product_id
    INNER JOIN sales s ON si.sale_id = s.id
WHERE 
    s.status = 'CONCLUIDA'
GROUP BY 
    p.id, p.name, p.sku, c.name
ORDER BY 
    total_quantity_sold DESC;

COMMENT ON VIEW vw_top_selling_products IS 
'Ranking dos produtos mais vendidos com receita e lucro';

-- === VIEW: Vendas diárias resumidas ===
CREATE OR REPLACE VIEW vw_daily_sales_summary AS
SELECT 
    DATE(s.finished_at) as sale_date,
    COUNT(s.id) as total_sales,
    SUM(s.subtotal) as gross_revenue,
    SUM(s.total_discount) as total_discounts,
    SUM(s.total_amount) as net_revenue,
    SUM(si.quantity * COALESCE(si.unit_cost_price, 0)) as total_cost,
    SUM(s.total_amount) - SUM(si.quantity * COALESCE(si.unit_cost_price, 0)) as total_profit,
    ROUND(
        (SUM(s.total_amount) - SUM(si.quantity * COALESCE(si.unit_cost_price, 0))) / 
        NULLIF(SUM(s.total_amount), 0) * 100, 2
    ) as profit_margin_percent
FROM 
    sales s
    INNER JOIN sale_items si ON s.id = si.sale_id
WHERE 
    s.status = 'CONCLUIDA'
    AND s.finished_at IS NOT NULL
GROUP BY 
    DATE(s.finished_at)
ORDER BY 
    sale_date DESC;

COMMENT ON VIEW vw_daily_sales_summary IS 
'Resumo financeiro das vendas por dia (receita, custos, lucro)';

-- === VIEW: Vendas por método de pagamento ===
CREATE OR REPLACE VIEW vw_sales_by_payment_method AS
SELECT 
    DATE(sp.created_at) as payment_date,
    sp.method,
    COUNT(DISTINCT sp.sale_id) as total_sales,
    SUM(sp.total) as total_amount
FROM 
    sale_payments sp
    INNER JOIN sales s ON sp.sale_id = s.id
WHERE 
    s.status = 'CONCLUIDA'
GROUP BY 
    DATE(sp.created_at), sp.method
ORDER BY 
    payment_date DESC, total_amount DESC;

COMMENT ON VIEW vw_sales_by_payment_method IS 
'Distribuição das vendas por forma de pagamento';

-- === VIEW: Clientes com maior dívida ===
CREATE OR REPLACE VIEW vw_customers_by_debt AS
SELECT 
    u.id,
    u.name,
    u.cpf,
    u.phone,
    u.credit_limit,
    u.invoice_amount as current_debt,
    (u.credit_limit - u.invoice_amount) as available_credit,
    COUNT(s.id) as total_purchases,
    MAX(s.finished_at) as last_purchase_date
FROM 
    users u
    LEFT JOIN sales s ON u.id = s.customer_id AND s.status = 'CONCLUIDA'
WHERE 
    u.role = 'CLIENTE'
    AND u.invoice_amount > 0
GROUP BY 
    u.id, u.name, u.cpf, u.phone, u.credit_limit, u.invoice_amount
ORDER BY 
    u.invoice_amount DESC;

COMMENT ON VIEW vw_customers_by_debt IS 
'Clientes com dívidas pendentes ordenados por valor devido';

-- === VIEW: Histórico de movimentação de estoque ===
CREATE OR REPLACE VIEW vw_stock_movement_history AS
SELECT 
    sm.id,
    sm.created_at,
    p.name as product_name,
    p.sku,
    c.name as category,
    sm.type as movement_type,
    sm.quantity,
    sm.reason,
    u.name as created_by_user,
    p.stock_quantity as current_stock
FROM 
    stock_movements sm
    INNER JOIN products p ON sm.product_id = p.id
    INNER JOIN categories c ON p.category_id = c.id
    LEFT JOIN users u ON sm.created_by = u.id
ORDER BY 
    sm.created_at DESC;

COMMENT ON VIEW vw_stock_movement_history IS 
'Histórico completo de movimentações de estoque';

-- === VIEW: Produtos próximos ao vencimento ===
CREATE OR REPLACE VIEW vw_expiring_products AS
SELECT 
    p.id,
    p.name,
    p.sku,
    c.name as category,
    b.batch_code,
    b.expiration_date,
    b.quantity,
    (b.expiration_date - CURRENT_DATE) as days_until_expiration
FROM 
    products p
    INNER JOIN categories c ON p.category_id = c.id
    INNER JOIN batches b ON p.id = b.product_id
WHERE 
    b.expiration_date BETWEEN CURRENT_DATE AND (CURRENT_DATE + INTERVAL '30 days')
    AND b.quantity > 0
ORDER BY 
    b.expiration_date ASC;

COMMENT ON VIEW vw_expiring_products IS 
'Produtos que vencem nos próximos 30 dias';

-- === VIEW: Desempenho de vendedores ===
CREATE OR REPLACE VIEW vw_salesperson_performance AS
SELECT 
    u.id,
    u.name as salesperson_name,
    DATE_TRUNC('month', s.finished_at) as month,
    COUNT(s.id) as total_sales,
    SUM(s.total_amount) as total_revenue,
    AVG(s.total_amount) as average_ticket,
    SUM(si.subtotal - (si.quantity * COALESCE(si.unit_cost_price, 0))) as total_profit
FROM 
    users u
    INNER JOIN sales s ON u.id = s.salesperson_id
    INNER JOIN sale_items si ON s.id = si.sale_id
WHERE 
    u.role IN ('CAIXA', 'GERENTE', 'ADMIN')
    AND s.status = 'CONCLUIDA'
GROUP BY 
    u.id, u.name, DATE_TRUNC('month', s.finished_at)
ORDER BY 
    month DESC, total_revenue DESC;

COMMENT ON VIEW vw_salesperson_performance IS 
'Desempenho dos vendedores por mês (vendas, receita, ticket médio)';

-- === VIEW: Análise de margem de lucro por categoria ===
CREATE OR REPLACE VIEW vw_profit_by_category AS
SELECT 
    c.id,
    c.name as category_name,
    COUNT(DISTINCT p.id) as total_products,
    COUNT(si.id) as total_items_sold,
    SUM(si.quantity) as total_quantity_sold,
    SUM(si.subtotal) as total_revenue,
    SUM(si.quantity * COALESCE(si.unit_cost_price, 0)) as total_cost,
    SUM(si.subtotal - (si.quantity * COALESCE(si.unit_cost_price, 0))) as total_profit,
    ROUND(
        (SUM(si.subtotal - (si.quantity * COALESCE(si.unit_cost_price, 0))) / 
        NULLIF(SUM(si.subtotal), 0) * 100), 2
    ) as profit_margin_percent
FROM 
    categories c
    INNER JOIN products p ON c.id = p.category_id
    INNER JOIN sale_items si ON p.id = si.product_id
    INNER JOIN sales s ON si.sale_id = s.id
WHERE 
    s.status = 'CONCLUIDA'
GROUP BY 
    c.id, c.name
ORDER BY 
    total_profit DESC;

COMMENT ON VIEW vw_profit_by_category IS 
'Análise de lucratividade por categoria de produtos';

-- === VIEW: Vendas canceladas com motivos ===
CREATE OR REPLACE VIEW vw_cancelled_sales AS
SELECT 
    s.id,
    s.created_at,
    s.cancelled_at,
    s.total_amount,
    u_customer.name as customer_name,
    u_salesperson.name as salesperson_name,
    u_cancelled.name as cancelled_by_name,
    s.cancellation_reason
FROM 
    sales s
    LEFT JOIN users u_customer ON s.customer_id = u_customer.id
    LEFT JOIN users u_salesperson ON s.salesperson_id = u_salesperson.id
    LEFT JOIN users u_cancelled ON s.cancelled_by = u_cancelled.id
WHERE 
    s.status = 'CANCELADA'
ORDER BY 
    s.cancelled_at DESC;

COMMENT ON VIEW vw_cancelled_sales IS 
'Histórico de vendas canceladas com responsável e motivo';

-- === VIEW: Fluxo de caixa diário ===
CREATE OR REPLACE VIEW vw_daily_cashflow AS
SELECT 
    payment_date,
    SUM(CASE WHEN method = 'DINHEIRO' THEN total ELSE 0 END) as cash,
    SUM(CASE WHEN method = 'CREDITO' THEN total ELSE 0 END) as credit_card,
    SUM(CASE WHEN method = 'DEBITO' THEN total ELSE 0 END) as debit_card,
    SUM(CASE WHEN method = 'PIX' THEN total ELSE 0 END) as pix,
    SUM(CASE WHEN method LIKE 'FIADO%' THEN total ELSE 0 END) as tab,
    SUM(CASE WHEN method = 'VALE_ALIMENTACAO' THEN total ELSE 0 END) as meal_voucher,
    SUM(total) as total_received
FROM 
    vw_sales_by_payment_method
GROUP BY 
    payment_date
ORDER BY 
    payment_date DESC;

COMMENT ON VIEW vw_daily_cashflow IS 
'Fluxo de caixa diário separado por forma de pagamento';

-- === VIEW: Receitas de produtos com custo calculado ===
CREATE OR REPLACE VIEW vw_recipe_costs AS
SELECT 
    p_final.id as product_id,
    p_final.name as product_name,
    p_final.sale_price,
    SUM(r.quantity * p_ingredient.purchase_price) as total_ingredient_cost,
    p_final.sale_price - SUM(r.quantity * p_ingredient.purchase_price) as profit_per_unit,
    ROUND(
        ((p_final.sale_price - SUM(r.quantity * p_ingredient.purchase_price)) / 
        NULLIF(p_final.sale_price, 0) * 100), 2
    ) as profit_margin_percent
FROM 
    products p_final
    INNER JOIN recipes r ON p_final.id = r.product_id
    INNER JOIN products p_ingredient ON r.ingredient_id = p_ingredient.id
WHERE 
    p_final.needs_preparation = TRUE
GROUP BY 
    p_final.id, p_final.name, p_final.sale_price
ORDER BY 
    profit_margin_percent DESC;

COMMENT ON VIEW vw_recipe_costs IS 'Custo de produção e margem de lucro de produtos preparados (receitas)';

