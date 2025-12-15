# 📋 Integração do Módulo de Relatórios com Snapshots

## Resumo das Alterações

O módulo de relatórios foi atualizado para usar a **nova stored procedure corrigida** que implementa snapshots diários para cálculos precisos de perdas.

---

## 🔄 Fluxo de Dados (Depois da Correção)

```
JavaScript (relatorios.js)
    ↓
URL: ../../api/relatorio_analise_estoque.php?data_inicio=2025-12-01&data_fim=2025-12-14
    ↓
PHP (relatorio_analise_estoque.php - CORRIGIDO)
    ↓
CALL relatorio_perdas_periodo_correto('2025-12-01', '2025-12-14')
    ↓
MySQL Stored Procedure (14_correcao_conceitual_perdas.sql)
    ├─ fn_estoque_teorico_ate_data() - Calcula teórico até data
    ├─ Snapshots da data anterior e data final
    └─ Calcula perdas REAIS do período
    ↓
Dados Mapeados (PHP converte para formato JS)
    ↓
Tabela HTML (JavaScript renderiza)
```

---

## 📝 Mudanças no PHP

### Arquivo: `api/relatorio_analise_estoque.php`

**ANTES:**
```php
$stmt = $db->prepare("CALL relatorio_analise_estoque_periodo(:data_inicio, :data_fim)");
// ❌ Chamava procedure antiga com lógica de divergência acumulada
```

**DEPOIS:**
```php
$stmt = $db->prepare("CALL relatorio_perdas_periodo_correto(:data_inicio, :data_fim)");
// ✅ Chama procedure nova com snapshots e período isolado
```

### Mapeamento de Colunas

A resposta da procedure é mapeada para compatibilidade com o JavaScript:

```php
$dados_mapeados = array_map(function($item) {
    return [
        'estoque_inicial'        => $item['estoque_inicial'],
        'entradas_periodo'       => $item['entradas_periodo'],
        'vendidas_periodo'       => $item['saidas_periodo'],    // ← NOTA: Saídas = Vendidas
        'estoque_teorico_final'  => $item['estoque_teorico_final'],
        'estoque_real_atual'     => $item['estoque_real_final'], // ← NOTA: Snapshot final
        'perdas_quantidade'      => $item['perdas_quantidade'],   // ✅ AGORA CORRETO
        'perdas_valor'           => $item['perdas_valor'],        // ✅ AGORA CORRETO
        'faturamento_periodo'    => saidas_periodo * preco        // Calculado aqui
    ];
}, $dados);
```

---

## 🎯 O que Mudou no Comportamento

### ANTES (ERRADO ❌)

Para **relatorio de 14 de dezembro**:
```
Estoque Inicial = SUM(TODAS entradas desde início do mês) = 1000
Entradas Período (14 dez) = 100
Vendidas (14 dez) = 50
Estoque Teórico Final = 1000 + 100 - 50 = 1050
Estoque Real (14 dez) = 900
PERDAS = 150 unidades  ❌ ERRADO! Inclui divergência de 13 de dezembro
```

### DEPOIS (CORRETO ✅)

Mesmo cenário com snapshots:
```
Estoque Inicial (snapshot 13 dez) = 900
Entradas Período (14 dez) = 100
Vendidas (14 dez) = 50
Estoque Teórico Final = 900 + 100 - 50 = 950
Estoque Real (14 dez snapshot) = 940
PERDAS = 10 unidades  ✅ CORRETO! Apenas do período
```

---

## 🚀 Recursos Novos Disponíveis

### 1. Snapshots Diários
```sql
-- Snapshot é criado automaticamente todos os dias
CALL gerar_snapshot_diario_corrigido(CURDATE());

-- Visualizar snapshots
SELECT * FROM estoque_snapshots 
WHERE produto_id = 1
ORDER BY data_snapshot DESC;
```

### 2. Histórico de Ajustes
```sql
-- Ver todos os ajustes de divergência realizados
SELECT * FROM historico_ajustes_estoque
ORDER BY data_ajuste DESC;
```

### 3. Função para Qualquer Período
```sql
-- Calcular perdas para período específico
SELECT fn_perdas_periodo(produto_id, '2025-12-01', '2025-12-14');
```

---

## ⚙️ Configuração Recomendada

### Automação de Snapshots Diários

**OPÇÃO 1: MySQL CRON (Recomendado)**
```sql
-- Agendar execução diária às 23:59
-- Executar uma vez no MySQL:
CREATE EVENT IF NOT EXISTS snapshot_diario
ON SCHEDULE EVERY 1 DAY
STARTS DATE_ADD(CURDATE(), INTERVAL 1 DAY)
STARTS CONCAT(CURDATE(), ' 23:59:00')
DO
    CALL gerar_snapshot_diario_corrigido(CURDATE());
```

**OPÇÃO 2: PHP (Se MySQL CRON não disponível)**
```php
// Colocar em um arquivo que roda diariamente
// Ex: cronjobs/gerar_snapshot.php

require_once '../config/database.php';
$db = (new Database())->getConnection();
$stmt = $db->prepare("CALL gerar_snapshot_diario_corrigido(CURDATE())");
$stmt->execute();
echo "Snapshot gerado para " . date('Y-m-d');
```

**OPÇÃO 3: Windows Task Scheduler**
```batch
REM Criar arquivo: C:\xampp\php\php.exe C:\xampp\htdocs\gestaointeli-jnr\cronjobs\gerar_snapshot.php
REM Agendar para rodar diariamente às 23:59
```

---

## 🧪 Testes Recomendados

### Test 1: Verificar que relatório está usando nova procedure
```javascript
// No console do navegador ao abrir relatório
// Verificar URL da requisição:
console.log('URL:', url + params);
// Deve conter: relatorio_analise_estoque.php?data_inicio=...&data_fim=...
```

### Test 2: Verificar dados retornados
```javascript
// No console, após gerar relatório
console.log('Dados da API:', resultado);
// Verificar se tem campos:
// - estoque_inicial
// - entradas_periodo  
// - vendidas_periodo
// - estoque_teorico_final
// - estoque_real_atual
// - perdas_quantidade (DEVE SER PEQUENO AGORA)
// - perdas_valor
```

### Test 3: Comparar com anterior
- Gerar mesmo relatório em período com dados antigos
- Verificar se perdas diminuíram (agora sem acumulação)
- Valores de estoque_inicial devem vir de snapshots

---

## 📊 Exemplo Prático

### Antes (ERRADO)
```
Período: 2025-12-10 a 2025-12-14
┌─────────────┬──────────┬────────┬──────────────┬────────────┬─────────┐
│ Produto     │ Inicial  │Entradas│Teórico Final │Real Atual  │ Perdas  │
├─────────────┼──────────┼────────┼──────────────┼────────────┼─────────┤
│ Arroz       │ 5000*    │ 200    │ 5050         │ 4500       │ 550 ❌ │
└─────────────┴──────────┴────────┴──────────────┴────────────┴─────────┘
* Inicial = SUM de TODAS entradas desde início (acumula 09/dez, 08/dez, etc)
```

### Depois (CORRETO)
```
Período: 2025-12-10 a 2025-12-14
┌─────────────┬──────────┬────────┬──────────────┬────────────┬─────────┐
│ Produto     │ Inicial  │Entradas│Teórico Final │Real Atual  │ Perdas  │
├─────────────┼──────────┼────────┼──────────────┼────────────┼─────────┤
│ Arroz       │ 4500 ✅  │ 200    │ 4700         │ 4500       │ 200 ✅ │
└─────────────┴──────────┴────────┴──────────────┴────────────┴─────────┘
* Inicial = Snapshot de 09/dez 23:59 (estado no fim do dia anterior)
```

---

## 🔧 Troubleshooting

### Problema: "Procedure 'relatorio_perdas_periodo_correto' não existe"

**Solução:**
1. Executar script SQL: `database/14_correcao_conceitual_perdas.sql`
2. Verificar que as 2 tabelas foram criadas:
   ```sql
   SHOW TABLES LIKE 'estoque_snapshots%';
   ```
3. Verificar que as 2 procedures foram criadas:
   ```sql
   SHOW PROCEDURE STATUS WHERE Name LIKE 'relatorio_perdas%';
   ```

### Problema: Perdas ainda aparecem grandes

**Solução:**
1. Verificar se snapshots foram gerados:
   ```sql
   SELECT COUNT(*) FROM estoque_snapshots;
   ```
2. Se vazio, gerar manualmente:
   ```sql
   CALL gerar_snapshot_diario_corrigido(CURDATE());
   CALL gerar_snapshot_diario_corrigido(DATE_SUB(CURDATE(), INTERVAL 1 DAY));
   ```
3. Regenrar relatório

### Problema: JavaScript mostra erro 404 ou resposta vazia

**Solução:**
1. Verificar console do navegador (F12)
2. Verificar se arquivo `api/relatorio_analise_estoque.php` existe
3. Verificar conexão com banco (testar query simples)
4. Verificar logs: `php error_log`

---

## 📌 Checklist de Implementação

- [ ] Executar script SQL `14_correcao_conceitual_perdas.sql`
- [ ] Verificar que 2 tabelas foram criadas (estoque_snapshots, historico_ajustes_estoque)
- [ ] Verificar que 2 procedures foram criadas (gerar_snapshot_diario_corrigido, relatorio_perdas_periodo_correto)
- [ ] Atualizar arquivo `api/relatorio_analise_estoque.php` (JÁ FEITO)
- [ ] Gerar snapshots para datas históricas
- [ ] Agendar snapshot automático diário
- [ ] Testar relatório com data_inicio e data_fim
- [ ] Verificar que perdas estão corretas no período
- [ ] Comparar com período anterior para validação

---

## 📚 Documentação Relacionada

- **14_correcao_conceitual_perdas.sql** - Script completo do SQL
- **GUIA_EXECUCAO_CORRECAO_PERDAS.md** - Passo a passo de implementação
- **TESTES_COMPLETOS_PERDAS.md** - 18 testes para validação
- **RESUMO_CORRECAO_PERDAS.md** - Resumo executivo

---

**Data**: 14 de Dezembro de 2025  
**Status**: ✅ Integração Completa
