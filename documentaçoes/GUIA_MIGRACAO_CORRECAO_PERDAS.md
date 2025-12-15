# 📋 GUIA DE MIGRAÇÃO - Correção da Lógica de Perdas de Estoque

**Data**: 11 de dezembro de 2025  
**Versão**: 2.0 (Corrigida)  
**Prioridade**: ALTA  
**Tempo estimado**: 30-45 minutos

---

## ⚠️ PRÉ-REQUISITOS

### Checklist de Preparação

- [ ] Fazer backup completo do banco de dados
  ```bash
  mysqldump -u root -p gestaointeli_db > backup_$(date +%Y%m%d_%H%M%S).sql
  ```

- [ ] Verificar espaço em disco disponível (mínimo 500MB)
  
- [ ] Clonar/criar branch de desenvolvimento
  ```bash
  git checkout -b fix/correcao-perdas-estoque
  ```

- [ ] Informar equipe sobre janela de manutenção (15 minutos)

- [ ] Ter acesso MySQL com privilégios de criação de estrutura

---

## 📊 FASES DE MIGRAÇÃO

### FASE 1: VALIDAÇÃO PRÉ-MIGRAÇÃO (5 minutos)

#### 1.1 Conectar ao MySQL
```bash
mysql -u root -p gestaointeli_db
```

#### 1.2 Executar queries de validação
```sql
-- Contar registros principais
SELECT 'movimentacoes_estoque' as tabela, COUNT(*) as total FROM movimentacoes_estoque
UNION ALL
SELECT 'produtos', COUNT(*) FROM produtos
UNION ALL
SELECT 'itens_comanda', COUNT(*) FROM itens_comanda
UNION ALL
SELECT 'perdas_estoque', COUNT(*) FROM perdas_estoque;

-- Verificar produtos com estoque negativo (erro crítico!)
SELECT id, nome, estoque_atual 
FROM produtos 
WHERE estoque_atual < 0;

-- Verificar integridade de chaves estrangeiras
SHOW ENGINE INNODB STATUS;
```

**Resultado esperado:**
- Nenhum produto com estoque negativo
- Sem erros em chaves estrangeiras

---

### FASE 2: EXECUTAR SCRIPT DE MIGRAÇÃO (20 minutos)

#### 2.1 Copiar arquivo SQL para servidor
```bash
cp migracao_correcao_perdas.sql /xampp/mysql/data/
```

#### 2.2 Executar script de migração
```bash
mysql -u root -p gestaointeli_db < migracao_correcao_perdas.sql
```

**O que este script faz:**

```
✅ Cria tabela tipos_ajuste_estoque
✅ Insere 9 tipos padrão de movimentação
✅ Adiciona coluna 'motivo' em movimentacoes_estoque
✅ Adiciona coluna 'tipo_ajuste_id' com FK
✅ Migra dados existentes com motivos automáticos
✅ Cria stored procedure corrigida
✅ Cria funções auxiliares (fn_estoque_acumulado, fn_calcular_perda)
✅ Cria view de auditoria
✅ Executa validações finais
✅ Registra log de migração
```

#### 2.3 Monitorar execução
```sql
-- Em outro terminal, monitorar progresso
SHOW PROCESSLIST;
SELECT * FROM logs_migracao_estoque ORDER BY data_execucao DESC LIMIT 5;
```

**Tempo esperado**: 15-20 minutos (depende do volume de dados)

---

### FASE 3: VALIDAÇÃO PÓS-MIGRAÇÃO (10 minutos)

#### 3.1 Verificar estrutura criada
```sql
-- Verificar coluna motivo
DESCRIBE movimentacoes_estoque;

-- Verificar tipos de ajuste
SELECT * FROM tipos_ajuste_estoque;

-- Verificar stored procedure
SHOW CREATE PROCEDURE relatorio_analise_estoque_periodo_corrigido;

-- Verificar funções
SHOW CREATE FUNCTION fn_estoque_acumulado;
SHOW CREATE FUNCTION fn_calcular_perda;
```

#### 3.2 Testar stored procedure com dados reais
```sql
-- Testar período recente
CALL relatorio_analise_estoque_periodo_corrigido('2025-11-01', '2025-12-11');

-- Verificar resultados
-- Deve listar todos produtos com estoque_inicial, entradas, vendas, etc.
```

#### 3.3 Comparar resultados: Antiga vs. Nova
```sql
-- Antiga (para comparação)
SELECT COUNT(*) as total_produtos_com_perda
FROM produtos p
WHERE (
    SELECT COALESCE(SUM(me.quantidade), 0) FROM movimentacoes_estoque 
    WHERE produto_id = p.id AND tipo = 'entrada'
) - (
    SELECT COALESCE(SUM(ic.quantidade), 0) FROM itens_comanda ic
    JOIN comandas c ON ic.comanda_id = c.id
    WHERE ic.produto_id = p.id AND c.status = 'fechada'
) - p.estoque_atual > 0;

-- Nova (corrigida)
SELECT COUNT(*) as total_produtos_com_perda
FROM vw_analise_perdas_corrigida
WHERE perda_atual > 0;
```

**Diferença esperada**: Muito menor (menos falsos positivos)

---

### FASE 4: ATUALIZAR CÓDIGO PHP (5 minutos)

#### 4.1 Verificar se API antiga ainda funciona
```php
// Arquivo: api/relatorio_alertas_perda.php (MANTER)
// Continua funcionando para compatibilidade
```

#### 4.2 Ativar nova API corrigida
```php
// Arquivo: api/relatorio_alertas_perda_corrigido.php (NOVO)
// Implementa lógica corrigida
// JavaScript deve chamar esta versão

// Em modules/relatorios/relatorios.js:
// Mudar de:
//   fetch('../../api/relatorio_alertas_perda.php')
// Para:
//   fetch('../../api/relatorio_alertas_perda_corrigido.php')
```

#### 4.3 Criar alias para compatibilidade (opcional)
```php
// Criar relatorio_alertas_perda.php como alias:
<?php
// Redirecionar para nova versão
require_once 'relatorio_alertas_perda_corrigido.php';
?>
```

---

### FASE 5: TESTES FUNCIONAIS (10 minutos)

#### 5.1 Teste 1: Verificar Dashboard
1. Abrir navegador
2. Acessar `modules/relatorios/`
3. Verificar cards de alertas
4. Comparar com valor esperado (menor que antes)

#### 5.2 Teste 2: Gerar Relatório
1. Selecionar "Análise de Estoque e Perdas"
2. Data início: 2025-11-01
3. Data fim: 2025-12-11
4. Clicar "Gerar Relatório"
5. Verificar se totalizadores são menores
6. Verificar se tabela mostra dados corretos

#### 5.3 Teste 3: Alertas Automáticos
```bash
# Chamar API diretamente
curl http://localhost/gestaointeli-jnr/public_html/caixa-seguro-7xy3q9kkle/api/relatorio_alertas_perda_corrigido.php

# Verificar resposta JSON
# Deve retornar:
# {
#   "success": true,
#   "data": [...],
#   "total_alertas": X,  // Número menor que antes
#   "resumo": {...}
# }
```

#### 5.4 Teste 4: Dados Históricos
```sql
-- Verificar alertas criados
SELECT COUNT(*) FROM perdas_estoque WHERE DATE(data_identificacao) >= '2025-12-11';

-- Verificar consistência
SELECT p.id, p.nome, p.estoque_atual, 
       fn_estoque_acumulado(p.id, CURDATE()) as teorico,
       fn_calcular_perda(p.id, CURDATE()) as perda
FROM produtos p
WHERE fn_calcular_perda(p.id, CURDATE()) > 0
ORDER BY perda DESC LIMIT 10;
```

---

## 🔄 ROLLBACK (Se necessário)

### Caso 1: Erro durante migração

```sql
-- Restaurar do backup
-- 1. Parar aplicação
-- 2. Excluir banco corrompido
DROP DATABASE gestaointeli_db;

-- 3. Restaurar de backup
mysql gestaointeli_db < backup_YYYYMMDD_HHMMSS.sql

-- 4. Reiniciar aplicação
```

### Caso 2: Resultados inesperados após migração

```sql
-- Remover estruturas novas (voltar ao estado anterior)
DROP TABLE tipos_ajuste_estoque;
DROP PROCEDURE relatorio_analise_estoque_periodo_corrigido;
DROP FUNCTION fn_estoque_acumulado;
DROP FUNCTION fn_calcular_perda;
DROP VIEW vw_analise_perdas_corrigida;
DROP TABLE logs_migracao_estoque;

-- Remover colunas adicionadas (cuidado!)
-- ALTER TABLE movimentacoes_estoque DROP COLUMN motivo;
-- ALTER TABLE movimentacoes_estoque DROP COLUMN tipo_ajuste_id;
```

---

## 📈 MONITORAMENTO PÓS-MIGRAÇÃO (7 dias)

### Dia 1-3: Monitoramento Intensivo
```sql
-- A cada 4 horas, verificar:
-- Novos alertas gerados
SELECT DATE(data_identificacao), COUNT(*) 
FROM perdas_estoque 
WHERE DATE(data_identificacao) >= DATE_SUB(NOW(), INTERVAL 3 DAY)
GROUP BY DATE(data_identificacao);

-- Consistência entre movimentações
SELECT p.id, p.nome,
       fn_estoque_acumulado(p.id, CURDATE()) as teorico,
       p.estoque_atual as real,
       fn_calcular_perda(p.id, CURDATE()) as perda
FROM produtos p
WHERE ABS(fn_estoque_acumulado(p.id, CURDATE()) - p.estoque_atual) > 20
ORDER BY perda DESC;
```

### Dia 4-7: Monitoramento Normal
```sql
-- Uma vez por dia
-- Verificar se estoque ainda está consistente
-- Verificar se novos alertas fazem sentido
SELECT COUNT(*), SUM(valor_perda)
FROM perdas_estoque
WHERE DATE(data_identificacao) = CURDATE()
AND visualizada = 0;
```

---

## 📝 DOCUMENTAÇÃO PARA EQUIPE

### O que muda para o usuário?

✅ **Alertas mais precisos** - Menos notificações falsas
✅ **Relatórios mais corretos** - Dados confiáveis para decisão
✅ **Interface igual** - Sem mudanças na tela
⚠️ **Números podem diminuir** - Perdas fictícias serão eliminadas

### O que muda para o desenvolvedor?

📍 **Nova stored procedure**: `relatorio_analise_estoque_periodo_corrigido()`
📍 **Nova API**: `api/relatorio_alertas_perda_corrigido.php`
📍 **Novas funções**: `fn_estoque_acumulado()`, `fn_calcular_perda()`
📍 **Coluna nova**: `motivo` em `movimentacoes_estoque`
📍 **View nova**: `vw_analise_perdas_corrigida`

---

## ✅ CHECKLIST DE CONCLUSÃO

- [ ] Backup realizado e testado
- [ ] Script SQL executado sem erros
- [ ] Validações pós-migração OK
- [ ] Testes funcionais passaram
- [ ] API nova testada
- [ ] Equipe informada
- [ ] Documentação atualizada
- [ ] Monitoramento configurado
- [ ] Rollback testado (simulado)
- [ ] Deploy em produção realizado
- [ ] Monitoramento por 7 dias iniciado

---

## 🆘 SUPORTE DURANTE MIGRAÇÃO

**Dúvidas ou problemas?**

1. **Verificar logs**:
   ```bash
   tail -f /var/log/mysql/error.log
   ```

2. **Consultar status**:
   ```sql
   SELECT * FROM logs_migracao_estoque ORDER BY data_execucao DESC;
   ```

3. **Contatar desenvolvedor** com:
   - Mensagem de erro
   - Timestamp do erro
   - Arquivo de log

---

**Versão do guia**: 1.0  
**Data**: 11 de dezembro de 2025  
**Status**: Pronto para produção
