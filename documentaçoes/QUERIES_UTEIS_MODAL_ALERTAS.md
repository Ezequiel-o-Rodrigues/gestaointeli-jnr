# 🔍 QUERIES ÚTEIS - MODAL DE ALERTAS DE PERDAS

## Verificação Rápida Pós-Instalação

```sql
-- ✅ Verificar se todos os componentes foram criados

-- 1. Stored Procedure
SHOW PROCEDURE STATUS WHERE Name = 'relatorio_analise_estoque_periodo_com_filtro_perdas';

-- 2. Funções
SHOW FUNCTION STATUS WHERE Name LIKE '%perdas%';

-- 3. Views
SHOW FULL TABLES WHERE TABLE_TYPE LIKE '%VIEW%' AND TABLE_NAME LIKE '%perdas%';

-- 4. Tabela de Log
DESCRIBE log_auditoria_perdas;

-- 5. Índices na tabela perdas_estoque
SHOW INDEX FROM perdas_estoque;
```

---

## 📊 Queries de Monitoramento

### Contar alertas não visualizados
```sql
SELECT COUNT(*) as total_alertas_pendentes
FROM perdas_estoque
WHERE visualizada = 0;
```

### Valor total em alertas
```sql
SELECT 
    COUNT(*) as quantidade_alertas,
    SUM(quantidade_perdida) as total_unidades,
    SUM(valor_perda) as valor_total,
    AVG(valor_perda) as valor_medio
FROM perdas_estoque
WHERE visualizada = 0;
```

### Alertas por produto
```sql
SELECT 
    p.nome as produto,
    cat.nome as categoria,
    COUNT(pe.id) as quantidade_alertas,
    SUM(pe.quantidade_perdida) as total_unidades,
    SUM(pe.valor_perda) as valor_total
FROM perdas_estoque pe
JOIN produtos p ON pe.produto_id = p.id
JOIN categorias cat ON p.categoria_id = cat.id
WHERE pe.visualizada = 0
GROUP BY pe.produto_id
ORDER BY valor_total DESC;
```

### Alertas por categoria
```sql
SELECT 
    cat.nome as categoria,
    COUNT(pe.id) as total_alertas,
    SUM(pe.quantidade_perdida) as total_unidades,
    SUM(pe.valor_perda) as valor_total
FROM perdas_estoque pe
JOIN produtos p ON pe.produto_id = p.id
JOIN categorias cat ON p.categoria_id = cat.id
WHERE pe.visualizada = 0
GROUP BY cat.id
ORDER BY valor_total DESC;
```

---

## 🔍 Consultas por Período

### Alertas do mês atual
```sql
SELECT 
    p.nome as produto,
    cat.nome as categoria,
    pe.quantidade_perdida,
    pe.valor_perda,
    pe.motivo,
    pe.data_identificacao,
    pe.visualizada
FROM perdas_estoque pe
JOIN produtos p ON pe.produto_id = p.id
JOIN categorias cat ON p.categoria_id = cat.id
WHERE MONTH(pe.data_identificacao) = MONTH(NOW())
  AND YEAR(pe.data_identificacao) = YEAR(NOW())
ORDER BY pe.data_identificacao DESC;
```

### Alertas últimos 7 dias
```sql
SELECT 
    p.nome as produto,
    pe.quantidade_perdida,
    pe.valor_perda,
    pe.data_identificacao,
    CASE 
        WHEN pe.visualizada = 0 THEN '⏳ Pendente'
        ELSE '✅ Visualizada'
    END as status
FROM perdas_estoque pe
JOIN produtos p ON pe.produto_id = p.id
WHERE pe.data_identificacao >= DATE_SUB(NOW(), INTERVAL 7 DAY)
ORDER BY pe.data_identificacao DESC;
```

### Alertas últimos 30 dias
```sql
SELECT 
    DATE(pe.data_identificacao) as data,
    COUNT(*) as quantidade,
    SUM(pe.valor_perda) as valor_dia
FROM perdas_estoque pe
WHERE pe.data_identificacao >= DATE_SUB(NOW(), INTERVAL 30 DAY)
GROUP BY DATE(pe.data_identificacao)
ORDER BY data DESC;
```

---

## 📈 Análise de Tendências

### Produtos com mais perdas (todos os tempos)
```sql
SELECT 
    p.nome as produto,
    cat.nome as categoria,
    COUNT(pe.id) as total_ocorrencias,
    SUM(pe.quantidade_perdida) as total_unidades_perdidas,
    SUM(pe.valor_perda) as valor_total_perdido,
    ROUND(SUM(pe.valor_perda) / COUNT(pe.id), 2) as valor_medio_por_ocorrencia
FROM perdas_estoque pe
JOIN produtos p ON pe.produto_id = p.id
JOIN categorias cat ON p.categoria_id = cat.id
GROUP BY pe.produto_id
ORDER BY valor_total_perdido DESC
LIMIT 10;
```

### Taxa de visualização de alertas
```sql
SELECT 
    COUNT(*) as total_perdas,
    SUM(CASE WHEN visualizada = 0 THEN 1 ELSE 0 END) as nao_visualizadas,
    SUM(CASE WHEN visualizada = 1 THEN 1 ELSE 0 END) as visualizadas,
    ROUND(SUM(CASE WHEN visualizada = 1 THEN 1 ELSE 0 END) / COUNT(*) * 100, 2) as taxa_visualizacao_percent
FROM perdas_estoque;
```

---

## 🔐 Auditoria

### Ver histórico de visualizações
```sql
SELECT 
    lap.id,
    lap.perda_id,
    pe.produto_id,
    p.nome as produto,
    lap.acao,
    lap.data_acao,
    lap.usuario_id
FROM log_auditoria_perdas lap
LEFT JOIN perdas_estoque pe ON lap.perda_id = pe.id
LEFT JOIN produtos p ON pe.produto_id = p.id
ORDER BY lap.data_acao DESC
LIMIT 50;
```

### Visualizações por dia
```sql
SELECT 
    DATE(data_acao) as data,
    COUNT(*) as total_visualizacoes
FROM log_auditoria_perdas
WHERE acao = 'visualizada'
GROUP BY DATE(data_acao)
ORDER BY data DESC;
```

---

## 🧪 Testes Manuais

### Criar perda de teste
```sql
INSERT INTO perdas_estoque 
(produto_id, quantidade_perdida, valor_perda, motivo, data_identificacao, visualizada)
VALUES 
(1, 10, 100.00, 'Teste Manual', NOW(), 0);

-- Copiar o ID retornado para o próximo comando
```

### Marcar perda como visualizada (simulando API)
```sql
UPDATE perdas_estoque 
SET visualizada = 1, data_visualizacao = NOW() 
WHERE id = 1;  -- Substitua 1 pelo ID da perda

-- Verificar se foi atualizada
SELECT * FROM perdas_estoque WHERE id = 1;

-- Ver no log de auditoria
SELECT * FROM log_auditoria_perdas WHERE perda_id = 1;
```

---

## 🔧 Manutenção

### Limpar alertas não visualizados há mais de 30 dias
```sql
-- ATENÇÃO: Isso irá DELETAR dados! Use com cuidado
DELETE FROM perdas_estoque
WHERE visualizada = 0 
  AND data_identificacao < DATE_SUB(NOW(), INTERVAL 30 DAY);
```

### Recalcular totalizadores
```sql
SELECT 
    COUNT(*) as total_perdas,
    SUM(quantidade_perdida) as total_unidades,
    SUM(valor_perda) as valor_total
FROM perdas_estoque;
```

### Limpeza de logs antigos (opcional)
```sql
-- Manter apenas últimos 90 dias de logs
DELETE FROM log_auditoria_perdas
WHERE data_acao < DATE_SUB(NOW(), INTERVAL 90 DAY);
```

---

## 🔗 Usar com APIs

### Testar API de perdas não visualizadas
```bash
curl -s "http://localhost/caixa-seguro-7xy3q9kkle/api/perdas_nao_visualizadas.php" | jq .

# Com filtro de período
curl -s "http://localhost/caixa-seguro-7xy3q9kkle/api/perdas_nao_visualizadas.php?data_inicio=2025-12-01&data_fim=2025-12-12" | jq .
```

### Testar API de análise por período
```bash
curl -s "http://localhost/caixa-seguro-7xy3q9kkle/api/relatorio_analise_estoque_periodo_perdas.php?data_inicio=2025-12-01&data_fim=2025-12-12" | jq .

# Com filtros
curl -s "http://localhost/caixa-seguro-7xy3q9kkle/api/relatorio_analise_estoque_periodo_perdas.php?data_inicio=2025-12-01&data_fim=2025-12-12&tipo_filtro=com_perda&valor_minimo=100" | jq .
```

---

## 📊 Relatórios Úteis

### Relatório Diário de Perdas
```sql
SELECT 
    DATE(pe.data_identificacao) as data,
    COUNT(*) as total_alertas,
    SUM(pe.quantidade_perdida) as total_unidades,
    SUM(pe.valor_perda) as valor_total,
    SUM(CASE WHEN pe.visualizada = 0 THEN 1 ELSE 0 END) as pendentes,
    SUM(CASE WHEN pe.visualizada = 1 THEN 1 ELSE 0 END) as visualizadas
FROM perdas_estoque pe
WHERE pe.data_identificacao >= DATE_SUB(NOW(), INTERVAL 7 DAY)
GROUP BY DATE(pe.data_identificacao)
ORDER BY data DESC;
```

### Relatório por Motivo
```sql
SELECT 
    pe.motivo,
    COUNT(*) as total,
    SUM(pe.quantidade_perdida) as unidades,
    SUM(pe.valor_perda) as valor,
    ROUND(SUM(pe.valor_perda) / (SELECT SUM(valor_perda) FROM perdas_estoque) * 100, 2) as percentual
FROM perdas_estoque pe
WHERE pe.data_identificacao >= DATE_SUB(NOW(), INTERVAL 30 DAY)
GROUP BY pe.motivo
ORDER BY valor DESC;
```

---

## 💾 Backup e Restauração

### Fazer backup da tabela perdas_estoque
```bash
mysqldump -h localhost -u root -p gestaointeli_db perdas_estoque > backup_perdas_estoque.sql
```

### Restaurar a partir de backup
```bash
mysql -h localhost -u root -p gestaointeli_db < backup_perdas_estoque.sql
```

---

## 🚨 Troubleshooting

### Verificar função criada corretamente
```sql
SHOW CREATE FUNCTION fn_contar_perdas_nao_visualizadas;

-- Testar função
SELECT fn_contar_perdas_nao_visualizadas();
```

### Verificar stored procedure
```sql
SHOW CREATE PROCEDURE relatorio_analise_estoque_periodo_com_filtro_perdas;

-- Testar procedure
CALL relatorio_analise_estoque_periodo_com_filtro_perdas('2025-12-01', '2025-12-12');
```

### Verificar view
```sql
SHOW CREATE VIEW vw_alertas_perdas_nao_visualizadas;

-- Contar alertas via view
SELECT COUNT(*) FROM vw_alertas_perdas_nao_visualizadas;
```

### Contar perdas por status
```sql
SELECT 
    visualizada,
    CASE WHEN visualizada = 0 THEN '⏳ Não Visualizadas' ELSE '✅ Visualizadas' END as status,
    COUNT(*) as quantidade
FROM perdas_estoque
GROUP BY visualizada;
```

---

## 📝 Exportar Dados

### Exportar para CSV
```bash
# Todas as perdas
mysql -h localhost -u root -p gestaointeli_db -e "
SELECT * FROM perdas_estoque;" -N > perdas_all.csv

# Apenas não visualizadas
mysql -h localhost -u root -p gestaointeli_db -e "
SELECT * FROM perdas_estoque WHERE visualizada = 0;" -N > perdas_nao_visualizadas.csv
```

---

**Última Atualização:** 12 de dezembro de 2025
