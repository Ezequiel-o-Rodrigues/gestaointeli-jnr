# 🧪 **TESTES PRONTOS PARA COPIAR E COLAR**

## ✅ Teste 1: Verificar se tudo foi criado

```sql
-- Verificar tabelas
SHOW TABLES LIKE 'estoque%';

-- Deve retornar:
-- estoque_snapshots
-- historico_ajustes_estoque
```

---

## ✅ Teste 2: Verificar funções

```sql
-- Listar funções criadas
SHOW FUNCTION STATUS WHERE Name LIKE 'fn_%';

-- Deve retornar:
-- fn_estoque_teorico_ate_data
-- fn_divergencia_atual
-- fn_perdas_periodo
```

---

## ✅ Teste 3: Verificar procedures

```sql
-- Listar procedures criadas
SHOW PROCEDURE STATUS WHERE Name LIKE 'gerar_%' OR Name LIKE 'relatorio_%';

-- Deve retornar:
-- gerar_snapshot_diario_corrigido
-- relatorio_perdas_periodo_correto
```

---

## ✅ Teste 4: Teste Rápido das Funções

```sql
-- Testar com produto ID 1
SELECT 
    1 AS produto_id,
    'Teste de Função' AS tipo,
    fn_estoque_teorico_ate_data(1, CURDATE()) AS estoque_teorico,
    fn_divergencia_atual(1) AS divergencia,
    fn_perdas_periodo(1, CURDATE(), CURDATE()) AS perdas_hoje;
```

---

## ✅ Teste 5: Diagnóstico Completo de Divergências

```sql
-- IMPORTANTE: Execute isto para entender a situação atual
SELECT 
    p.id,
    p.nome,
    p.estoque_atual AS estoque_real,
    fn_estoque_teorico_ate_data(p.id, CURDATE()) AS estoque_teorico,
    fn_divergencia_atual(p.id) AS divergencia,
    CASE 
        WHEN fn_divergencia_atual(p.id) > 0 THEN 'FALTAM PRODUTOS'
        WHEN fn_divergencia_atual(p.id) < 0 THEN 'SOBRAM PRODUTOS'
        ELSE 'OK'
    END AS status,
    CASE 
        WHEN fn_divergencia_atual(p.id) > 0 THEN 'ENTRADA'
        WHEN fn_divergencia_atual(p.id) < 0 THEN 'SAIDA'
        ELSE 'NENHUM'
    END AS tipo_ajuste,
    ABS(fn_divergencia_atual(p.id)) AS qtd_ajuste
FROM produtos p
WHERE p.ativo = 1
ORDER BY ABS(fn_divergencia_atual(p.id)) DESC;
```

**Resultado esperado:**
```
Se não houver divergências: Nenhuma linha retornada
Se houver: Lista de produtos a serem ajustados
```

---

## ✅ Teste 6: Analisar Ajustes Necessários (sem fazer nada)

```sql
-- Visualize EXATAMENTE o que será ajustado
SELECT 
    p.id,
    p.nome,
    p.estoque_atual AS 'ESTOQUE ATUAL',
    fn_estoque_teorico_ate_data(p.id, CURDATE()) AS 'DEVERÁ SER',
    fn_divergencia_atual(p.id) AS 'AJUSTE QTD'
FROM produtos p
WHERE p.ativo = 1
AND fn_divergencia_atual(p.id) != 0
ORDER BY ABS(fn_divergencia_atual(p.id)) DESC;
```

**Revise com cuidado antes de prosseguir!**

---

## ✅ Teste 7: Gerar Snapshot de Hoje

```sql
-- Execute para criar snapshot diário
CALL gerar_snapshot_diario_corrigido(CURDATE());
```

**Resultado esperado:**
```
Mensagem: Snapshot diário gerado com sucesso
Data: 2025-12-14 (ou data de hoje)
```

---

## ✅ Teste 8: Verificar Snapshots Criados

```sql
-- Ver snapshots gerados
SELECT 
    es.data_snapshot,
    p.nome,
    es.estoque_real,
    es.estoque_teorico,
    es.divergencia,
    es.entradas_dia,
    es.saidas_dia
FROM estoque_snapshots es
JOIN produtos p ON es.produto_id = p.id
ORDER BY es.data_snapshot DESC
LIMIT 20;
```

**Resultado esperado:**
Snapshots de hoje com todos os produtos

---

## ✅ Teste 9: Relatório de UM DIA (deverá estar correto)

```sql
-- Relatório de HOJE
CALL relatorio_perdas_periodo_correto(CURDATE(), CURDATE());
```

**Resultado esperado:**
- `estoque_inicial`: Estoque real de ontem
- `perdas_quantidade`: Deve ser 0 ou pequeno
- **NEM 'perdas fantasmas'**

---

## ✅ Teste 10: Relatório de SEMANA

```sql
-- Relatório da semana passada
CALL relatorio_perdas_periodo_correto(
    DATE_SUB(CURDATE(), INTERVAL 7 DAY),
    CURDATE()
);
```

**Resultado esperado:**
- Números realistas
- Sem perdas falsas
- Período bem definido

---

## ✅ Teste 11: Verificar Histórico de Ajustes

```sql
-- Ver ajustes que foram aplicados
SELECT * FROM historico_ajustes_estoque
ORDER BY data_ajuste DESC
LIMIT 10;
```

**Resultado esperado:**
Se houver ajustes aplicados, estarão aqui registrados

---

## ✅ Teste 12: Verificar Movimentações de Ajuste

```sql
-- Ver movimentações de ajuste criadas
SELECT 
    p.nome,
    me.tipo_movimentacao,
    me.quantidade,
    me.motivo,
    DATE(me.data_movimentacao) as data
FROM movimentacoes_estoque me
JOIN produtos p ON me.produto_id = p.id
WHERE me.motivo LIKE '%Ajuste%'
ORDER BY me.data_movimentacao DESC
LIMIT 20;
```

---

## ⚠️ Teste 13: ANTES DE FAZER AJUSTE - Backup

```bash
# Execute no terminal (NOT MySQL):
mysqldump -h localhost -u root -p gestaointeli_db > backup_ANTES_AJUSTE_$(date +%Y%m%d_%H%M%S).sql
```

**Confirmação esperada:**
Arquivo criado com sucesso

---

## 💣 Teste 14: FAZER O AJUSTE (PONTO DE NÃO RETORNO)

```sql
-- ⚠️ CUIDADO! ESTE SCRIPT ALTERA DADOS!
-- ⚠️ Só execute se os ajustes estão corretos (Teste 6)

START TRANSACTION;

-- Registrar ajustes no histórico
INSERT INTO historico_ajustes_estoque 
(produto_id, divergencia_detectada, data_ajuste, ajuste_aplicado, motivo)
SELECT 
    p.id,
    fn_divergencia_atual(p.id),
    CURDATE(),
    fn_divergencia_atual(p.id),
    'Ajuste automático de divergência acumulada'
FROM produtos p
WHERE p.ativo = 1
AND fn_divergencia_atual(p.id) != 0;

-- Registrar movimentações de ajuste
INSERT INTO movimentacoes_estoque 
(produto_id, tipo_movimentacao, quantidade, motivo, data_movimentacao)
SELECT 
    p.id,
    CASE WHEN fn_divergencia_atual(p.id) > 0 THEN 'entrada' ELSE 'saida' END,
    ABS(fn_divergencia_atual(p.id)),
    'Ajuste de divergência acumulada',
    CURDATE()
FROM produtos p
WHERE p.ativo = 1
AND fn_divergencia_atual(p.id) != 0;

-- Atualizar estoque
UPDATE produtos p
SET estoque_atual = fn_estoque_teorico_ate_data(p.id, CURDATE())
WHERE p.ativo = 1
AND fn_divergencia_atual(p.id) != 0;

COMMIT;
```

**Resultado esperado:**
```
Query OK, X rows affected
```

---

## ✅ Teste 15: Verificar que Ajustes Foram Aplicados

```sql
-- Verificar que NÃO HÁ MAIS DIVERGÊNCIAS
SELECT 
    p.id,
    p.nome,
    fn_divergencia_atual(p.id) AS divergencia
FROM produtos p
WHERE p.ativo = 1
AND fn_divergencia_atual(p.id) != 0;
```

**Resultado esperado:**
**Nenhuma linha retornada** (ou todos com divergencia = 0)

✅ **Se sim: SUCESSO!**

---

## ✅ Teste 16: Testar Relatório Após Ajuste

```sql
-- Relatório de hoje após ajuste
CALL relatorio_perdas_periodo_correto(CURDATE(), CURDATE());
```

**Resultado esperado:**
- `estoque_inicial`: Correto
- `entradas`: 0 ou valores corretos
- `saidas`: 0 ou valores corretos
- `perdas`: 0 ou valores reais pequenos
- ✅ **SEM FALSAS PERDAS**

---

## ✅ Teste 17: Teste de Período Completo

```sql
-- Relatório de 30 dias
CALL relatorio_perdas_periodo_correto(
    DATE_SUB(CURDATE(), INTERVAL 30 DAY),
    CURDATE()
);
```

**Resultado esperado:**
- Números fazem sentido
- Período bem isolado
- Sem acúmulo com períodos anteriores

---

## 🔄 Teste 18: Simular Nova Venda e Snapshot

```sql
-- (OPCIONAL) Simular venda futura para testar novo snapshot
-- Suponha que você vendeu 5 unidades do produto ID 1 hoje:

INSERT INTO movimentacoes_estoque 
(produto_id, tipo_movimentacao, quantidade, motivo, data_movimentacao)
VALUES (1, 'saida', 5, 'Venda teste', CURDATE());

-- Atualizar estoque
UPDATE produtos SET estoque_atual = estoque_atual - 5 WHERE id = 1;

-- Gerar novo snapshot
CALL gerar_snapshot_diario_corrigido(CURDATE());

-- Verificar relatório novamente
CALL relatorio_perdas_periodo_correto(CURDATE(), CURDATE());
```

**Resultado esperado:**
- Snapshot mostra a nova saída
- Relatório está correto

---

## 📋 Checklist de Testes

```
[ ] Teste 1: Tabelas criadas
[ ] Teste 2: Funções criadas
[ ] Teste 3: Procedures criadas
[ ] Teste 4: Funções funcionando
[ ] Teste 5: Diagnóstico de divergências
[ ] Teste 6: Analisar ajustes (SEM fazer)
[ ] Teste 7: Gerar snapshot
[ ] Teste 8: Verificar snapshots
[ ] Teste 9: Relatório de um dia (correto?)
[ ] Teste 10: Relatório de semana (correto?)
[ ] Teste 11: Histórico vazio (ainda)
[ ] Teste 12: Movimentações vazias (ainda)
[ ] Teste 13: Backup feito ✅
[ ] Teste 14: FAZER AJUSTE
[ ] Teste 15: Sem divergências ✅
[ ] Teste 16: Relatório após ajuste ✅
[ ] Teste 17: Período completo ✅
[ ] Teste 18: Novo snapshot + venda (OPCIONAL)
```

---

**Status:** ✅ **TODOS OS TESTES PRONTOS PARA EXECUTAR**

Copie e cole cada teste um por um no seu MySQL client (phpMyAdmin, Workbench, CLI, etc.)
