-- ============================================================================
-- ARMAZEM DO NECA - SCHEMA COMPLETO (V2.1)
-- Sistema de gestão para pequeno comércio com bar, lanchonete e mercearia
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pg_trgm";
CREATE EXTENSION IF NOT EXISTS "citext";

-- ============================================================================
-- ENUMS - Tipos enumerados para padronização de dados
-- ============================================================================

DO $$ BEGIN
    -- Métodos de pagamento aceitos no estabelecimento
    CREATE TYPE payment_method_enum AS ENUM (
        'DINHEIRO',
        'CREDITO',
        'DEBITO',
        'PIX',
        'FIADO-EM-ABERTO',
        'FIADO-PAGO-PARCIAL',
        'FIADO-QUITADO',
        'VALE_ALIMENTACAO'        
    );
    
    -- Tipos de movimentação de estoque
    CREATE TYPE stock_movement_enum AS ENUM (
        'VENDA', 
        'COMPRA', 
        'DEVOLUCAO_VENDA', 
        'DEVOLUCAO_FORNECEDOR', 
        'PERDA', 
        'AJUSTE', 
        'CONSUMO_INTERNO', 
        'CANCELAMENTO'
    );
    
    -- Papéis/funções dos usuários no sistema
    CREATE TYPE user_role_enum AS ENUM (
        'ADMIN',
        'CAIXA', 
        'GERENTE', 
        'CLIENTE',
        'ESTOQUISTA',
        'CONTADOR'
    );
    
    -- Status possíveis de uma venda
    CREATE TYPE sale_status_enum AS ENUM (
        'ABERTA', 
        'CONCLUIDA', 
        'CANCELADA', 
        'EM_ENTREGA'        
    );
    
    -- Unidades de medida para produtos
    CREATE TYPE measure_unit_enum AS ENUM (
        'UN', 
        'KG', 
        'L', 
        'CX'
    );
EXCEPTION
    WHEN duplicate_object THEN null;
END $$;

-- ============================================================================
-- FUNCTIONS - Funções auxiliares do banco de dados
-- ============================================================================

-- Atualiza automaticamente o campo updated_at quando um registro é modificado
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = CURRENT_TIMESTAMP;
    RETURN NEW;
END;
$$ language 'plpgsql';

-- ============================================================================
-- CATEGORIAS - Organização hierárquica de produtos
-- ============================================================================

CREATE TABLE IF NOT EXISTS categories (
    id SERIAL PRIMARY KEY,
    name CITEXT NOT NULL,
    parent_category_id INTEGER,    
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT categories_name_length_cstr CHECK ((length(name)) <= 64 AND length(name) >= 3),
    CONSTRAINT categories_name_unique_cstr UNIQUE (name),
    FOREIGN KEY (parent_category_id) REFERENCES categories(id) ON DELETE SET NULL ON UPDATE CASCADE
);

COMMENT ON TABLE categories IS 'Categorias e subcategorias de produtos (ex: Bebidas, Frios, Lanchonete)';
COMMENT ON COLUMN categories.name IS 'Nome da categoria (case-insensitive)';
COMMENT ON COLUMN categories.parent_category_id IS 'Categoria pai para criar hierarquia (NULL = categoria raiz)';

-- ============================================================================
-- FORNECEDORES - Cadastro de fornecedores de produtos
-- ============================================================================

CREATE TABLE IF NOT EXISTS suppliers (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name CITEXT NOT NULL,
    cnpj TEXT,
    phone TEXT,
    contact_name TEXT,
    address TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT suppliers_cnpj_length_check CHECK ((length(cnpj) <= 20)),
    CONSTRAINT suppliers_phone_length_check CHECK ((length(phone) = 11)),
    CONSTRAINT suppliers_cnpj_unique UNIQUE (cnpj),
    CONSTRAINT suppliers_name_unique UNIQUE (name)
);

COMMENT ON TABLE suppliers IS 'Cadastro de fornecedores de mercadorias';
COMMENT ON COLUMN suppliers.cnpj IS 'CNPJ do fornecedor (apenas números)';
COMMENT ON COLUMN suppliers.phone IS 'Telefone de contato (11 dígitos com DDD)';
COMMENT ON COLUMN suppliers.contact_name IS 'Nome da pessoa de contato no fornecedor';

-- ============================================================================
-- TRIBUTAÇÃO - Grupos fiscais e impostos
-- ============================================================================

CREATE TABLE IF NOT EXISTS tax_groups (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    description VARCHAR(100) NOT NULL,
    icms_cst VARCHAR(3) NOT NULL,
    pis_cofins_cst VARCHAR(2) NOT NULL,
    icms_rate NUMERIC(5,2) DEFAULT 0,
    pis_rate NUMERIC(5,2) DEFAULT 0,
    cofins_rate NUMERIC(5,2) DEFAULT 0
);

COMMENT ON TABLE tax_groups IS 'Grupos de tributação para facilitar a gestão fiscal de produtos similares';
COMMENT ON COLUMN tax_groups.description IS 'Descrição do grupo (ex: "Bebidas Frias - Monofásico")';
COMMENT ON COLUMN tax_groups.icms_cst IS 'Código de Situação Tributária do ICMS (ex: 060 = cobrado anteriormente)';
COMMENT ON COLUMN tax_groups.pis_cofins_cst IS 'CST para PIS/COFINS (ex: 04 = Monofásico com alíquota zero)';

-- ============================================================================
-- PRODUTOS - Cadastro principal de mercadorias
-- ============================================================================

CREATE TABLE IF NOT EXISTS products (
    -- Identificação
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name CITEXT NOT NULL,
    sku CITEXT UNIQUE NOT NULL,
    description TEXT,
    category_id INTEGER NOT NULL,
    image_url TEXT,
    
    -- Fiscal
    gtin VARCHAR(14),
    ncm VARCHAR(8) NOT NULL DEFAULT '00000000',
    cest VARCHAR(7),
    cfop_default VARCHAR(4) NOT NULL DEFAULT '5102',
    origin CHAR(1) NOT NULL DEFAULT '0',
    tax_group_id UUID,

    -- Estoque
    stock_quantity NUMERIC(10, 3) NOT NULL DEFAULT 0,
    min_stock_quantity NUMERIC(10, 3) NOT NULL DEFAULT 0,
    max_stock_quantity NUMERIC(10, 3) NOT NULL DEFAULT 0,
    average_weight NUMERIC(10, 4) NOT NULL DEFAULT 0.0,
    
    -- Preços e Margem
    purchase_price NUMERIC(10, 2) NOT NULL DEFAULT 0,
    sale_price NUMERIC(10, 2) NOT NULL DEFAULT 0,
    profit_margin NUMERIC(10, 2) GENERATED ALWAYS AS (
        CASE WHEN purchase_price > 0 
        THEN ((sale_price - purchase_price) / purchase_price * 100) 
        ELSE 0 END
    ) STORED,
    measure_unit measure_unit_enum NOT NULL DEFAULT 'UN',
    
    -- Status
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    needs_preparation BOOLEAN NOT NULL DEFAULT FALSE,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (category_id) REFERENCES categories(id) ON UPDATE CASCADE,
    FOREIGN KEY (tax_group_id) REFERENCES tax_groups(id) ON DELETE SET NULL ON UPDATE CASCADE,

    CONSTRAINT products_name_unique_cstr UNIQUE (name),
    CONSTRAINT products_gtin_unique_cstr UNIQUE (gtin),
    CONSTRAINT products_sale_price_valid_cstr CHECK (sale_price >= purchase_price),
    CONSTRAINT products_sku_chk CHECK ((length(sku) >= 2 AND length(sku) <= 128))
);

COMMENT ON TABLE products IS 'Cadastro principal de produtos do estabelecimento';
COMMENT ON COLUMN products.name IS 'Nome comercial do produto (único no sistema)';
COMMENT ON COLUMN products.sku IS 'Código interno de identificação (Stock Keeping Unit)';
COMMENT ON COLUMN products.gtin IS 'Código de barras EAN-13 ou similar';
COMMENT ON COLUMN products.ncm IS 'Nomenclatura Comum do Mercosul (obrigatório para emissão de NF-e)';
COMMENT ON COLUMN products.cest IS 'Código Especificador da Substituição Tributária (obrigatório para alguns produtos)';
COMMENT ON COLUMN products.cfop_default IS 'CFOP padrão (5102 = Venda de mercadoria adquirida para revenda)';
COMMENT ON COLUMN products.origin IS 'Origem da mercadoria (0=Nacional, 1=Estrangeira-Importação direta, etc)';
COMMENT ON COLUMN products.stock_quantity IS 'Quantidade atual em estoque';
COMMENT ON COLUMN products.min_stock_quantity IS 'Estoque mínimo para alerta de reposição';
COMMENT ON COLUMN products.max_stock_quantity IS 'Estoque máximo recomendado';
COMMENT ON COLUMN products.average_weight IS 'Peso médio para produtos vendidos por unidade mas pesados';
COMMENT ON COLUMN products.profit_margin IS 'Margem de lucro calculada automaticamente em percentual';
COMMENT ON COLUMN products.is_active IS 'Se FALSE, produto não está mais disponível para venda';
COMMENT ON COLUMN products.needs_preparation IS 'TRUE para produtos preparados (receitas), como caipirinhas ou lanches';

-- ============================================================================
-- RECEITAS - Composição de produtos preparados
-- ============================================================================

CREATE TABLE IF NOT EXISTS recipes (
    product_id UUID NOT NULL,
    ingredient_id UUID NOT NULL,
    measure_unit measure_unit_enum NOT NULL DEFAULT 'UN',
    quantity NUMERIC(10, 4) NOT NULL,
    PRIMARY KEY (product_id, ingredient_id),
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    FOREIGN KEY (ingredient_id) REFERENCES products(id) ON DELETE CASCADE,
    CONSTRAINT recipes_quantity_valid CHECK (quantity >= 0.0000)
);

COMMENT ON TABLE recipes IS 'Receitas de produtos preparados (ex: caipirinha = limão + cachaça + açúcar)';
COMMENT ON COLUMN recipes.product_id IS 'Produto final que será preparado';
COMMENT ON COLUMN recipes.ingredient_id IS 'Ingrediente necessário (também deve ser um produto cadastrado)';
COMMENT ON COLUMN recipes.quantity IS 'Quantidade do ingrediente necessária por unidade do produto final';

-- ============================================================================
-- LOTES - Controle de validade e rastreabilidade
-- ============================================================================

CREATE TABLE IF NOT EXISTS batches (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID NOT NULL,
    batch_code TEXT,
    expiration_date DATE NOT NULL,
    quantity NUMERIC(10, 3) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(id) ON DELETE CASCADE,
    CONSTRAINT batches_batch_code_length_cstr CHECK (length(batch_code) <= 64),
    CONSTRAINT batches_quantity_valid CHECK (quantity >= 0.000)
);

COMMENT ON TABLE batches IS 'Controle de lotes de produtos com validade (FIFO/FEFO)';
COMMENT ON COLUMN batches.batch_code IS 'Código do lote do fornecedor';
COMMENT ON COLUMN batches.expiration_date IS 'Data de validade do lote';
COMMENT ON COLUMN batches.quantity IS 'Quantidade de unidades neste lote';

-- ============================================================================
-- USUÁRIOS - Cadastro de funcionários e clientes
-- ============================================================================

CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    name TEXT NOT NULL,
    nickname TEXT,
    email TEXT,
    phone TEXT,
    cpf VARCHAR(14),
    notes TEXT,
    password_hash TEXT,
    role user_role_enum DEFAULT 'CLIENTE',

    -- Controle de crédito para vendas fiadas
    credit_limit NUMERIC(10, 2) NOT NULL DEFAULT 0,
    invoice_amount NUMERIC(10, 2) NOT NULL DEFAULT 0,

    state_tax_indicator SMALLINT DEFAULT 9,

    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT users_email_unique_cstr UNIQUE (email),
    CONSTRAINT users_cpf_unique_cstr UNIQUE (cpf),
    CONSTRAINT users_valid_cpf_cstr CHECK (cpf ~ '^\d{3}\.\d{3}\.\d{3}-\d{2}$' OR cpf ~ '^\d{11}$'),
    CONSTRAINT users_valid_phone_cstr CHECK (phone ~ '^\d{10,11}$' OR phone ~ '^\(\d{2}\)\s?\d{4,5}-?\d{4}$'),
    CONSTRAINT users_name_length_cstr CHECK ((length(name) <= 256 AND length(name) >= 2)),
    CONSTRAINT users_nickname_length_check CHECK ((length(nickname) <= 256 AND length(nickname) >= 2)),
    CONSTRAINT users_notes_length_check CHECK ((length(notes) <= 512 AND length(notes) >= 2))
);

COMMENT ON TABLE users IS 'Cadastro de usuários do sistema (funcionários e clientes)';
COMMENT ON COLUMN users.role IS 'Papel do usuário (ADMIN, CAIXA, GERENTE, CLIENTE, ESTOQUISTA, CONTADOR)';
COMMENT ON COLUMN users.password_hash IS 'Hash da senha (apenas para funcionários que acessam o sistema)';
COMMENT ON COLUMN users.credit_limit IS 'Limite de crédito para compras fiadas';
COMMENT ON COLUMN users.invoice_amount IS 'Valor total em aberto (dívidas não pagas)';
COMMENT ON COLUMN users.state_tax_indicator IS 'Indicador fiscal: 1=Contribuinte ICMS, 2=Isento, 9=Não Contribuinte';
COMMENT ON COLUMN users.notes IS 'Observações sobre o usuário (ex: "Sempre paga em dia", "Preferência por cerveja X")';

-- ============================================================================
-- ENDEREÇOS - Endereços de usuários/clientes
-- ============================================================================

CREATE TABLE IF NOT EXISTS user_addresses (
    user_id UUID NOT NULL,
    ibge_city_code VARCHAR(7),
    street TEXT,
    number TEXT,
    neighborhood TEXT,
    zip_code TEXT,
    state CHAR(2),
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE
);

COMMENT ON TABLE user_addresses IS 'Endereços dos usuários (para entregas e emissão de NF-e)';
COMMENT ON COLUMN user_addresses.ibge_city_code IS 'Código IBGE da cidade (ex: 4205407 para Florianópolis/SC)';

-- ============================================================================
-- TOKENS DE SESSÃO - Controle de autenticação
-- ============================================================================

CREATE TABLE IF NOT EXISTS refresh_tokens (
    id UUID PRIMARY KEY,
    user_id UUID NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    revoked BOOLEAN NOT NULL DEFAULT FALSE,
    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE ON UPDATE CASCADE
);

COMMENT ON TABLE refresh_tokens IS 'Tokens de refresh para manter sessões de login ativas';
COMMENT ON COLUMN refresh_tokens.revoked IS 'TRUE quando o token é invalidado (logout)';

-- ============================================================================
-- AUDITORIA DE PREÇOS - Histórico de alterações de preços
-- ============================================================================

CREATE TABLE IF NOT EXISTS price_audits (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID NOT NULL,
    old_purchase_price NUMERIC(10, 2),
    new_purchase_price NUMERIC(10, 2),
    old_sale_price NUMERIC(10, 2),
    new_sale_price NUMERIC(10, 2),
    changed_by UUID,
    changed_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(id),
    FOREIGN KEY (changed_by) REFERENCES users(id)
);

COMMENT ON TABLE price_audits IS 'Histórico de alterações de preços de produtos';
COMMENT ON COLUMN price_audits.changed_by IS 'Usuário que realizou a alteração de preço';

-- ============================================================================
-- MOVIMENTAÇÃO DE ESTOQUE - Todas as entradas e saídas
-- ============================================================================

CREATE TABLE IF NOT EXISTS stock_movements (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    product_id UUID NOT NULL,
    type stock_movement_enum NOT NULL,
    quantity NUMERIC(10, 3) NOT NULL,
    reference_id UUID,
    reason TEXT,
    created_by UUID,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (product_id) REFERENCES products(id) ON UPDATE CASCADE,
    FOREIGN KEY (created_by) REFERENCES users(id) ON UPDATE CASCADE ON DELETE SET NULL
);

COMMENT ON TABLE stock_movements IS 'Registro de todas as movimentações de estoque (entradas e saídas)';
COMMENT ON COLUMN stock_movements.type IS 'Tipo: VENDA, COMPRA, DEVOLUCAO, PERDA, AJUSTE, etc';
COMMENT ON COLUMN stock_movements.quantity IS 'Quantidade movimentada (positivo=entrada, negativo=saída)';
COMMENT ON COLUMN stock_movements.reference_id IS 'ID da venda/compra relacionada (se aplicável)';
COMMENT ON COLUMN stock_movements.reason IS 'Motivo da movimentação (ex: "Venda #123", "Produto vencido")';

-- ============================================================================
-- VENDAS - Cabeçalho das vendas
-- ============================================================================

CREATE TABLE IF NOT EXISTS sales (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    subtotal NUMERIC(10, 2) NOT NULL DEFAULT 0,
    total_discount NUMERIC(10, 2) DEFAULT 0,
    total_amount NUMERIC(10, 2) NOT NULL DEFAULT 0,
    status sale_status_enum DEFAULT 'ABERTA',

    salesperson_id UUID,
    customer_id UUID,
    
    cancelled_by UUID,
    cancelled_at TIMESTAMP,
    cancellation_reason TEXT,

    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    finished_at TIMESTAMP,
    FOREIGN KEY (salesperson_id) REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE,
    FOREIGN KEY (customer_id) REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE,
    FOREIGN KEY (cancelled_by) REFERENCES users(id) ON DELETE SET NULL ON UPDATE CASCADE
);

COMMENT ON TABLE sales IS 'Cabeçalho das vendas realizadas';
COMMENT ON COLUMN sales.subtotal IS 'Soma dos itens antes de descontos';
COMMENT ON COLUMN sales.total_discount IS 'Desconto total aplicado na venda';
COMMENT ON COLUMN sales.total_amount IS 'Valor final da venda (subtotal - desconto)';
COMMENT ON COLUMN sales.status IS 'Status: ABERTA, CONCLUIDA, CANCELADA, EM_ENTREGA';
COMMENT ON COLUMN sales.salesperson_id IS 'Funcionário que realizou a venda';
COMMENT ON COLUMN sales.customer_id IS 'Cliente que realizou a compra (opcional)';
COMMENT ON COLUMN sales.finished_at IS 'Data/hora da conclusão da venda';

-- ============================================================================
-- ITENS DE VENDA - Produtos vendidos em cada venda
-- ============================================================================

CREATE TABLE IF NOT EXISTS sale_items (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sale_id UUID NOT NULL,
    product_id UUID NOT NULL,
    quantity NUMERIC(10, 3) NOT NULL,
    unit_sale_price NUMERIC(10, 2) NOT NULL,
    unit_cost_price NUMERIC(10, 2),
    subtotal NUMERIC(10, 2) GENERATED ALWAYS AS (quantity * unit_sale_price) STORED,
    CONSTRAINT sale_items_greater_than_zero_cstr CHECK (quantity > 0),
    FOREIGN KEY (product_id) REFERENCES products(id) ON UPDATE CASCADE ON DELETE SET NULL,
    FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE CASCADE ON UPDATE CASCADE
);

COMMENT ON TABLE sale_items IS 'Itens individuais de cada venda';
COMMENT ON COLUMN sale_items.unit_sale_price IS 'Preço de venda unitário no momento da venda (congelado)';
COMMENT ON COLUMN sale_items.unit_cost_price IS 'Custo unitário no momento da venda (para cálculo de lucro real)';
COMMENT ON COLUMN sale_items.subtotal IS 'Valor total do item (quantidade × preço unitário)';

-- ============================================================================
-- PAGAMENTOS DE VENDAS - Formas de pagamento utilizadas
-- ============================================================================

CREATE TABLE IF NOT EXISTS sale_payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sale_id UUID NOT NULL,
    method payment_method_enum NOT NULL,
    total NUMERIC(10, 2) NOT NULL,
    created_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (sale_id) REFERENCES sales(id) ON DELETE CASCADE ON UPDATE CASCADE
);

COMMENT ON TABLE sale_payments IS 'Formas de pagamento utilizadas em cada venda (pode haver múltiplas)';
COMMENT ON COLUMN sale_payments.method IS 'Método: DINHEIRO, CREDITO, DEBITO, PIX, FIADO, etc';
COMMENT ON COLUMN sale_payments.total IS 'Valor pago através deste método';

-- ============================================================================
-- PAGAMENTOS DE FIADO - Quitação de dívidas
-- ============================================================================

CREATE TABLE IF NOT EXISTS tab_payments (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    sale_id UUID NOT NULL,
    amount_paid NUMERIC(10, 2) NOT NULL,
    payment_method payment_method_enum NOT NULL,
    received_by UUID,
    observation TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (sale_id) REFERENCES sales(id),
    FOREIGN KEY (received_by) REFERENCES users(id),
    CONSTRAINT positive_amount CHECK (amount_paid > 0)
);

COMMENT ON TABLE tab_payments IS 'Pagamentos realizados para quitar vendas fiadas (a prazo)';
COMMENT ON COLUMN tab_payments.amount_paid IS 'Valor pago neste pagamento parcial';
COMMENT ON COLUMN tab_payments.payment_method IS 'Forma de pagamento utilizada na quitação';
COMMENT ON COLUMN tab_payments.received_by IS 'Funcionário que recebeu o pagamento';

-- ============================================================================
-- LOGS - Registro de eventos do sistema
-- ============================================================================

CREATE TABLE IF NOT EXISTS logs (
    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    level VARCHAR(50) NOT NULL,
    message TEXT NOT NULL,
    path TEXT,
    method VARCHAR(10),
    status_code INT,
    stacktrace TEXT,
    metadata JSONB,
    created_at TIMESTAMPTZ DEFAULT CURRENT_TIMESTAMP NOT NULL,
    CONSTRAINT chk_log_level CHECK (level IN ('DEBUG', 'INFO', 'WARN', 'ERROR', 'FATAL'))
);

COMMENT ON TABLE logs IS 'Registro de logs do sistema para auditoria e debugging';
COMMENT ON COLUMN logs.level IS 'Nível de severidade do log';
COMMENT ON COLUMN logs.metadata IS 'Dados adicionais em formato JSON';

-- ============================================================================
-- TRIGGERS
-- ============================================================================

CREATE OR REPLACE TRIGGER trg_products_updated_at
BEFORE UPDATE ON products
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

CREATE OR REPLACE TRIGGER trg_users_updated_at
BEFORE UPDATE ON users
FOR EACH ROW EXECUTE FUNCTION update_updated_at_column();

