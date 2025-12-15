# 🔧 **GUIA DE EXECUÇÃO - CORREÇÃO CONCEITUAL DE PERDAS**

## 📋 **SEQUÊNCIA DE PASSOS**

### **PASSO 1: Executar Script de Estrutura (Sem Risco)**
```bash
mysql -h localhost -u root -p gestaointeli_db < database/14_correcao_conceitual_perdas.sql
```

**O que acontece:**
- ✅ Cria tabela `estoque_snapshots`
- ✅ Cria tabela `historico_ajustes_estoque`
- ✅ Cria funções: `fn_estoque_teorico_ate_data`, `fn_divergencia_atual`, `fn_perdas_periodo`
- ✅ Cria procedures: `gerar_snapshot_diario_corrigido`, `relatorio_perdas_periodo_correto`
- ❌ NÃO altera nenhum dado

---

### **PASSO 2: Diagnosticar Divergências**

**2.1 No MySQL (phpMyAdmin ou CLI):**
```sql
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
    END AS status
FROM produtos p
WHERE p.ativo = 1
ORDER BY ABS(fn_divergencia_atual(p.id)) DESC;
```

**Exemplo de resultado esperado:**
```
| id | nome    | estoque_real | estoque_teorico | divergencia | status           |
|----|---------|--------------|-----------------|-------------|------------------|
| 1  | Arroz   | 50           | 100             | -50         | SOBRAM PRODUTOS  |
| 2  | Feijão  | 70           | 70              | 0           | OK               |
| 3  | Pinga   | 20           | 35              | -15         | SOBRAM PRODUTOS  |
```

**Interpretação:**
- `divergencia > 0`: Faltam produtos (foram vendidos mas não registrados?)
- `divergencia < 0`: Sobram produtos (entrada não registrada?)
- `divergencia = 0`: Tudo OK!

---

### **PASSO 3: Analisar Quais Ajustes Serão Feitos**

**Execute esta query (SEM ALTERAR NADA):**
```sql
SELECT 
    p.id,
    p.nome,
    p.estoque_atual,
    fn_estoque_teorico_ate_data(p.id, CURDATE()) AS estoque_deve_ser,
    fn_divergencia_atual(p.id) AS ajuste_necessario
FROM produtos p
WHERE p.ativo = 1
AND fn_divergencia_atual(p.id) != 0
ORDER BY ABS(fn_divergencia_atual(p.id)) DESC;
```

**Revise os resultados:**
- Os ajustes fazem sentido?
- Tem algo que não deveria ser ajustado?
- Se SIM: Interrompa e corrija os dados manualmente primeiro

---

### **PASSO 4: FAZER O AJUSTE (Ponto de Não Retorno)**

**⚠️ ATENÇÃO: A partir daqui você altera o banco de dados!**

**Backup OBRIGATÓRIO:**
```bash
mysqldump -h localhost -u root -p gestaointeli_db > backup_antes_ajuste.sql
```

**Execute o script de ajuste:**
```sql
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

**O que acontece:**
1. ✅ Todos os ajustes são registrados em `historico_ajustes_estoque`
2. ✅ Cada ajuste gera uma movimentação em `movimentacoes_estoque` (auditável)
3. ✅ Estoques são atualizados para o valor correto

---

### **PASSO 5: Verificar que Tudo Está OK**

**Execute novamente para confirmar:**
```sql
SELECT 
    p.id,
    p.nome,
    p.estoque_atual AS estoque_real,
    fn_estoque_teorico_ate_data(p.id, CURDATE()) AS estoque_teorico,
    fn_divergencia_atual(p.id) AS divergencia
FROM produtos p
WHERE p.ativo = 1
AND fn_divergencia_atual(p.id) != 0;
```

**Resultado esperado:** Nenhuma linha retornada (ou todos com `divergencia = 0`)

Se sim: ✅ **SUCESSO! Sistema está "zerado"**

---

### **PASSO 6: Gerar Snapshot de Hoje**

```sql
CALL gerar_snapshot_diario_corrigido(CURDATE());
```

**Resultado esperado:**
```
Snapshot diário gerado com sucesso | 2025-12-14
```

---

### **PASSO 7: Teste o Relatório Novo**

```sql
CALL relatorio_perdas_periodo_correto('2025-12-14', '2025-12-14');
```

**Resultado esperado:**
- Estoque inicial = Estoque real de ontem
- Perdas = 0 (pois não houve movimento hoje)
- **SEM FALSAS PERDAS!**

---

### **PASSO 8: Teste com um Período Anterior**

```sql
CALL relatorio_perdas_periodo_correto('2025-12-01', '2025-12-14');
```

**Resultado esperado:**
- Números fazem sentido
- Perdas = perdas REAIS do período, não "divergência acumulada"

---

## 🔄 **AGORA: MANUTENÇÃO DIÁRIA**

### **Configure para rodar automaticamente todo dia às 23:59:**

**Opção 1: CRON (Linux/Mac)**
```bash
# Editar crontab
crontab -e

# Adicionar linha:
59 23 * * * mysql -h localhost -u root -pSUASENHA gestaointeli_db -e "CALL gerar_snapshot_diario_corrigido(CURDATE());"
```

**Opção 2: Windows Task Scheduler**
```bash
# Criar arquivo: C:\gerar_snapshot.bat
@echo off
mysql -h localhost -u root -pSUASENHA gestaointeli_db -e "CALL gerar_snapshot_diario_corrigido(CURDATE());"
pause

# Agendar no Task Scheduler para rodar todo dia às 23:59
```

**Opção 3: PHP (Se não tiver acesso a CRON)**

Arquivo: `api/gerar_snapshot_diario.php`
```php
<?php
// Executar este script todo dia
// Pode ser chamado via: http://localhost/.../gerar_snapshot_diario.php

require 'config/database.php';

$data = date('Y-m-d');
$resultado = $pdo->query("CALL gerar_snapshot_diario_corrigido('$data')");

if ($resultado) {
    echo "✅ Snapshot gerado para $data\n";
} else {
    echo "❌ Erro ao gerar snapshot\n";
}
```

---

## 🎯 **RESULTADO FINAL**

**Antes da correção:**
- ❌ Relatórios com "perdas fantasmas"
- ❌ Cálculos cumulativos misturados com período
- ❌ Estoque inicial incorreto

**Depois da correção:**
- ✅ Relatórios mostram PERDAS REAIS
- ✅ Cada período isolado corretamente
- ✅ Snapshots diários como backup
- ✅ Histórico de ajustes auditável
- ✅ Sistema funcionando corretamente

---

## 🆘 **Se Der Errado**

**Rollback completo:**
```bash
# 1. Restaurar backup
mysql -h localhost -u root -p gestaointeli_db < backup_antes_ajuste.sql

# 2. Executar script novamente
mysql -h localhost -u root -p gestaointeli_db < database/14_correcao_conceitual_perdas.sql
```

---

## 📊 **Exemplo Prático Completo**

### **Dados iniciais:**
```
Produto: Feijão
- 01/12: Entrada 100 unidades
- 05/12: Saída 30 unidades
- 10/12: Saída 20 unidades
- HOJE: Estoque real = 50
```

### **Passo 1: Diagnosticar**
```sql
SELECT fn_divergencia_atual(1); 
-- Retorna: 0 (está OK!)
```

### **Passo 2: Gerar snapshot**
```sql
CALL gerar_snapshot_diario_corrigido('2025-12-14');
```

### **Passo 3: Relatório de hoje**
```sql
CALL relatorio_perdas_periodo_correto('2025-12-14', '2025-12-14');
-- estoque_inicial: 50
-- entradas: 0
-- saidas: 0
-- perdas: 0 ✅ CORRETO!
```

### **Passo 4: Relatório do período**
```sql
CALL relatorio_perdas_periodo_correto('2025-12-01', '2025-12-14');
-- estoque_inicial: 0 (antes não existia)
-- entradas: 100
-- saidas: 50
-- perdas: 0 ✅ CORRETO!
```

---

**Pronto! Sistema corrigido e funcionando! 🎉**
