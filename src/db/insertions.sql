

INSERT INTO categories (name, parent_category_id) VALUES 
    ('Lanchonete & Cozinha', NULL),
    ('Bar & Drinks', NULL),
    ('Bebidas (Varejo)', NULL),
    ('Mercearia', NULL),
    ('Frios e Laticínios', NULL),
    ('Hortifruti', NULL),
    ('Higiene e Limpeza', NULL),
    ('Conveniência', NULL)
ON CONFLICT (name) DO NOTHING;

-- Subcategorias de Lanchonete
INSERT INTO categories (name, parent_category_id) VALUES 
    ('Lanches Tradicionais', (SELECT id FROM categories WHERE name = 'Lanchonete & Cozinha')),
    ('Salgados e Assados',   (SELECT id FROM categories WHERE name = 'Lanchonete & Cozinha')),
    ('Cafeteria',            (SELECT id FROM categories WHERE name = 'Lanchonete & Cozinha'))
ON CONFLICT (name) DO NOTHING;

-- Subcategorias de Bar
INSERT INTO categories (name, parent_category_id) VALUES 
    ('Cervejas (Geladas/Consumo)', (SELECT id FROM categories WHERE name = 'Bar & Drinks')),
    ('Drinks e Coquetéis',         (SELECT id FROM categories WHERE name = 'Bar & Drinks')),
    ('Doses',                      (SELECT id FROM categories WHERE name = 'Bar & Drinks')),
    ('Porções e Petiscos',         (SELECT id FROM categories WHERE name = 'Bar & Drinks'))
ON CONFLICT (name) DO NOTHING;

-- Subcategorias de Bebidas (Varejo)
INSERT INTO categories (name, parent_category_id) VALUES 
    ('Cervejas (Packs/Fardos)', (SELECT id FROM categories WHERE name = 'Bebidas (Varejo)')),
    ('Refrigerantes e Sucos',   (SELECT id FROM categories WHERE name = 'Bebidas (Varejo)')),
    ('Destilados (Garrafas)',   (SELECT id FROM categories WHERE name = 'Bebidas (Varejo)')),
    ('Águas',                   (SELECT id FROM categories WHERE name = 'Bebidas (Varejo)')),
    ('Águas (Galões/Retornáveis)', (SELECT id FROM categories WHERE name = 'Bebidas (Varejo)'))
ON CONFLICT (name) DO NOTHING;

-- Subcategorias de Mercearia
INSERT INTO categories (name, parent_category_id) VALUES 
    ('Alimentos Básicos',     (SELECT id FROM categories WHERE name = 'Mercearia')),
    ('Matinais',              (SELECT id FROM categories WHERE name = 'Mercearia')),
    ('Biscoitos e Doces',     (SELECT id FROM categories WHERE name = 'Mercearia')),
    ('Condimentos e Molhos',  (SELECT id FROM categories WHERE name = 'Mercearia'))
ON CONFLICT (name) DO NOTHING;

-- Subcategorias de Frios
INSERT INTO categories (name, parent_category_id) VALUES 
    ('Fatiados',   (SELECT id FROM categories WHERE name = 'Frios e Laticínios')),
    ('Laticínios', (SELECT id FROM categories WHERE name = 'Frios e Laticínios')),
    ('Embutidos',  (SELECT id FROM categories WHERE name = 'Frios e Laticínios'))
ON CONFLICT (name) DO NOTHING;

-- Subcategorias de Hortifruti
INSERT INTO categories (name, parent_category_id) VALUES 
    ('Frutas',   (SELECT id FROM categories WHERE name = 'Hortifruti')),
    ('Legumes',  (SELECT id FROM categories WHERE name = 'Hortifruti')),
    ('Verduras', (SELECT id FROM categories WHERE name = 'Hortifruti'))
ON CONFLICT (name) DO NOTHING;

-- Subcategorias de Limpeza
INSERT INTO categories (name, parent_category_id) VALUES 
    ('Limpeza Casa',    (SELECT id FROM categories WHERE name = 'Higiene e Limpeza')),
    ('Higiene Pessoal', (SELECT id FROM categories WHERE name = 'Higiene e Limpeza'))
ON CONFLICT (name) DO NOTHING;