# 📋 INSTRUÇÕES DE EXECUÇÃO DOS SCRIPTS DE MIGRAÇÃO

## Status Atual do Banco de Dados ✅

A estrutura já foi parcialmente criada:
- ✅ Tabela `tipos_ajuste_estoque` existe (9 tipos criados)
- ✅ Colunas `motivo`, `tipo_ajuste_id`, `comanda_id` existem em `movimentacoes_estoque`
- ⏳ Dados ainda não foram migrados
- ⏳ Stored procedures ainda não foram criadas
- ⏳ Funções auxiliares ainda não foram criadas

## Próximos Scripts a Executar

### ✅ Script 3: Migrar dados - VENDAS
**Arquivo:** `03_migrar_dados_vendas.sql`
**Tempo:** 10-30 segundos
**O que faz:** Classifica saídas que correspondem a vendas em itens_comanda

```sql
SOURCE database/03_migrar_dados_vendas.sql;
```

**Validar depois:** Execute estas queries:
```sql
-- Contar vendas reclassificadas
SELECT COUNT(*) as total_vendas FROM movimentacoes_estoque WHERE motivo = 'venda';

-- Ver exemplos
SELECT id, produto_id, quantidade, motivo, comanda_id FROM movimentacoes_estoque 
WHERE motivo = 'venda' LIMIT 10;

-- Contar saídas sem motivo
SELECT COUNT(*) FROM movimentacoes_estoque WHERE tipo = 'saida' AND motivo IS NULL;
```

---

### ⏳ Script 4: Migrar dados - ENTRADAS
**Arquivo:** `04_migrar_dados_entradas.sql`
**Tempo:** 5-10 segundos
**O que faz:** Classifica todas as entradas como 'compra'

**Validar depois:**
```sql
SELECT COUNT(*) FROM movimentacoes_estoque WHERE motivo = 'compra';
SELECT COUNT(*) FROM movimentacoes_estoque WHERE tipo = 'entrada' AND motivo IS NULL;
```

---

### ⏳ Script 5: Migrar dados - OUTRAS SAÍDAS
**Arquivo:** `05_migrar_dados_outras_saidas.sql`
**Tempo:** 5-10 segundos
**O que faz:** Classifica saídas restantes (ajustes, perdas, etc) analisando observações

**Validar depois:**
```sql
-- Distribuição de motivos
SELECT motivo, COUNT(*) as quantidade FROM movimentacoes_estoque 
WHERE tipo = 'saida' GROUP BY motivo;
```

---

### ⏳ Script 6: Criar Stored Procedure Corrigida
**Arquivo:** `06_criar_stored_procedure_corrigida.sql`
**Tempo:** 2-5 segundos
**O que faz:** Cria procedure com lógica corrigida de cálculo de perdas

**Validar depois:**
```sql
-- Testar a procedure
CALL relatorio_analise_estoque_periodo_corrigido('2025-11-01', '2025-12-11');

-- Ver se foi criada
SHOW CREATE PROCEDURE relatorio_analise_estoque_periodo_corrigido;
```

---

### ⏳ Script 7: Criar Funções Auxiliares
**Arquivo:** `07_criar_funcoes_auxiliares.sql`
**Tempo:** 2-5 segundos
**O que faz:** Cria 2 funções para calcular estoque e perdas

**Validar depois:**
```sql
-- Testar função de estoque acumulado
SELECT p.id, p.nome, fn_estoque_acumulado(p.id, CURDATE()) as acumulado 
FROM produtos p LIMIT 5;

-- Testar função de perda
SELECT p.id, p.nome, fn_calcular_perda(p.id, CURDATE()) as perda 
FROM produtos p WHERE fn_calcular_perda(p.id, CURDATE()) > 0 LIMIT 5;
```

---

### ⏳ Script 8: Criar View de Auditoria
**Arquivo:** `08_criar_view_auditoria.sql`
**Tempo:** 2-5 segundos
**O que faz:** Cria view consolidada para análise de perdas

**Validar depois:**
```sql
-- Ver top 10 produtos com maiores perdas
SELECT * FROM vw_analise_perdas_corrigida LIMIT 10;

-- Contar produtos com perda
SELECT COUNT(*) FROM vw_analise_perdas_corrigida WHERE perda_atual > 0;
```

---

### ⏳ Script 9: Criar Tabela de Log
**Arquivo:** `09_criar_log_migracao.sql`
**Tempo:** 1-2 segundos
**O que faz:** Cria tabela para registrar histórico de migrações

**Validar depois:**
```sql
SELECT * FROM logs_migracao_estoque;
```

---

## Ordem de Execução ⚙️

```
Script 3 ► Script 4 ► Script 5 ► Script 6 ► Script 7 ► Script 8 ► Script 9
  ↓         ↓         ↓         ↓         ↓         ↓         ↓
Vendas   Entradas  Outros     SP     Funções    View      Log
```

## Cada Script Deve Ser Executado SEPARADAMENTE

1. Execute Script 3 **completamente** → valide → prossiga
2. Execute Script 4 **completamente** → valide → prossiga
3. Execute Script 5 **completamente** → valide → prossiga
4. E assim sucessivamente...

## Dicas de Sucesso ✨

- ✅ Faça um BACKUP antes de começar
- ✅ Execute **um script por vez**
- ✅ Valide os resultados após cada script
- ✅ Se houver erro, mostre a mensagem completa
- ✅ NÃO prossiga para o próximo se houver erros
- ✅ Os scripts são idempotentes (seguro rodá-los novamente)

## Se Houver Erro

Se um script falhar:
1. Copie a **mensagem de erro completa**
2. Verifique a sintaxe SQL
3. Execute apenas a parte que está falhando
4. Após corrigir, **re-execute o script inteiro**

## Resumo Final

Após executar todos os 9 scripts:
- ✅ Nova lógica de cálculo de perdas ativa
- ✅ Dados migrados e classificados
- ✅ Stored procedures funcionando
- ✅ Views e funções disponíveis
- ✅ Log de auditoria registrado

**Próximo passo:** Ativar a API corrigida em JavaScript:
```javascript
// Em modules/relatorios/relatorios.js
// Trocar:
fetch('../../api/relatorio_alertas_perda.php')

// Por:
fetch('../../api/relatorio_alertas_perda_corrigido.php')
```

---

**Data:** 11 de dezembro de 2025
**Status:** Aguardando execução dos scripts 3-9
