# 🧪 **TESTES DE VALIDAÇÃO - SISTEMA CORRIGIDO DE PERDAS**

## 📋 **SUMÁRIO EXECUTIVO**

Este documento apresenta testes específicos para validar se a correção do sistema eliminou os problemas de cálculo cumulativo e perdas fantasmas.

---

## 🔍 **TESTE 1: CENÁRIO DE VALIDAÇÃO CRÍTICA**

### **Objetivo:** Reproduzir o cenário do bug mencionado (venda no dia anterior não deve aparecer como perda no dia seguinte)

### **Setup:**

```
Produto: Cerveja Premium
Preço: R$ 20,00

DIA 1 (15/12/2025):
- Estoque inicial: 100 unidades
- Vendas: 3 unidades
- Estoque final: 97 unidades
```

### **Executar:**

```bash
# 1. Gerar fechamento do dia 1
mysql -u root -p gestaointeli_db -e "CALL gerar_fechamento_diario_automatico('2025-12-15');"

# 2. Verificar fechamento criado
mysql -u root -p gestaointeli_db -e "
  SELECT * FROM fechamento_diario_estoque 
  WHERE produto_id = 1 
  AND data_fechamento = '2025-12-15';"

# 3. Gerar relatório do dia 2 (SEM VENDAS)
curl -X GET "http://localhost/caixa-seguro-7xy3q9kkle/api/relatorio_analise_estoque_corrigido.php?data_inicio=2025-12-16&data_fim=2025-12-16"
```

### **Validação Esperada:**

```json
{
  "data": [
    {
      "id": 1,
      "nome": "Cerveja Premium",
      "estoque_inicial": 97,        // ✅ Deve ser 97 (do fechamento do dia 15)
      "entradas_periodo": 0,        // ✅ Deve ser 0 (sem entradas no dia 16)
      "vendidas_periodo": 0,        // ✅ Deve ser 0 (sem vendas no dia 16)
      "estoque_teorico_final": 97,  // ✅ Deve ser 97 + 0 - 0 = 97
      "estoque_real_atual": 97,     // ✅ Deve ser 97
      "perdas_quantidade": 0,       // ✅ CRÍTICO: Deve ser ZERO (não pode contar venda do dia anterior!)
      "perdas_valor": 0.00          // ✅ CRÍTICO: Deve ser ZERO
    }
  ]
}
```

### **Resultado do Teste:**

- [ ] Estoque inicial é 97? (não 100)
- [ ] Perdas quantidade é 0? (não 3)
- [ ] Perdas valor é R$ 0,00? (não R$ 60,00)

---

## 🔍 **TESTE 2: RELATÓRIO COM MÚLTIPLOS DIAS**

### **Objetivo:** Validar que um relatório semanal não acumula dados de semanas anteriores

### **Setup:**

```
SEMANA 1 (08/12 a 14/12):
- Dia 08: 100 inicial, vende 5 → 95 final
- Dia 09: 95 inicial, vende 3 → 92 final
- Dia 10-14: Sem movimentação → 92 final

SEMANA 2 (15/12 a 21/12):
- Dia 15: 92 inicial, vende 2 → 90 final
- Dia 16-21: Sem movimentação → 90 final
```

### **Executar:**

```bash
# Gerar fechamentos
for dia in {08..21}; do
  mysql -u root -p gestaointeli_db \
    -e "CALL gerar_fechamento_diario_automatico('2025-12-$dia');"
done

# Relatório APENAS da semana 2
curl -X GET "http://localhost/caixa-seguro-7xy3q9kkle/api/relatorio_analise_estoque_corrigido.php?data_inicio=2025-12-15&data_fim=2025-12-21"
```

### **Validação Esperada:**

```json
{
  "totais": {
    "total_entradas": 0,              // ✅ Semana 2 tem 0 entradas
    "total_vendidas": 2,              // ✅ Semana 2 tem 2 vendas (apenas dia 15)
    "total_perdas_quantidade": 0,     // ✅ Sem perdas na semana 2
    "total_perdas_valor": 0.00        // ✅ Sem valor em perdas
  }
}
```

### **Resultado do Teste:**

- [ ] Total vendidas é 2? (não 10 de semanas anteriores)
- [ ] Total perdas é 0? (não acumula com semana anterior)
- [ ] Período está isolado corretamente?

---

## 🔍 **TESTE 3: MODAL DE ALERTAS**

### **Objetivo:** Validar que o modal carrega corretamente perdas não visualizadas

### **Executar:**

```bash
curl -X GET "http://localhost/caixa-seguro-7xy3q9kkle/api/modal_historico_perdas.php?data_inicio=2025-12-01&data_fim=2025-12-31"
```

### **Validação Esperada:**

```json
{
  "success": true,
  "resumo": {
    "total_alertas": 5,              // ✅ X perdas não visualizadas
    "total_historico": 12,           // ✅ 12 perdas no total (5 + 7 já visualizadas)
    "valor_total_alertas": 125.50
  },
  "alertas": {
    "count": 5,
    "data": [
      {
        "id": 1,
        "visualizada": 0,            // ✅ Deve ser 0
        "data_visualizacao": null    // ✅ Deve ser null
      }
    ]
  }
}
```

### **Resultado do Teste:**

- [ ] Alertas mostram apenas visualizada=0?
- [ ] Histórico mostra todas as perdas?
- [ ] Contagem está correta?

---

## 🔍 **TESTE 4: MARCAR COMO VISUALIZADA**

### **Objetivo:** Validar que marcar como visualizada funciona e atualiza o contador

### **Executar:**

```bash
# Antes
curl -X GET "http://localhost/caixa-seguro-7xy3q9kkle/api/modal_historico_perdas.php?data_inicio=2025-12-01&data_fim=2025-12-31" | jq '.resumo.total_alertas'

# Marcar como visualizada
curl -X POST "http://localhost/caixa-seguro-7xy3q9kkle/api/marcar_perda_visualizada_v2.php" \
  -H "Content-Type: application/json" \
  -d '{"perda_id": 1, "usuario_id": 1}'

# Depois
curl -X GET "http://localhost/caixa-seguro-7xy3q9kkle/api/modal_historico_perdas.php?data_inicio=2025-12-01&data_fim=2025-12-31" | jq '.resumo.total_alertas'
```

### **Validação Esperada:**

```
Antes:  5 alertas
Depois: 4 alertas

Auditoria registrada:
- acao: visualizada
- usuario_id: 1
- data_acao: data/hora atual
```

### **Resultado do Teste:**

- [ ] Total de alertas diminuiu em 1?
- [ ] Histórico inclui a perda marcada?
- [ ] Auditoria foi registrada?

---

## 🔍 **TESTE 5: VALIDAÇÃO DE CÁLCULOS MATEMÁTICOS**

### **Objetivo:** Validar a fórmula está 100% correta

### **Cenário:**

```
Produto: Água Mineral
Preço: R$ 2,00

DIA 20/12/2025:
- Estoque inicial (do fechamento 19/12): 500
- Entradas: 100 (compra)
- Vendas: 50
- Outras saídas: 5 (danos)
- Estoque real atual: 540

ESPERADO:
- Estoque teórico = 500 + 100 - 50 - 5 = 545
- Perdas = 545 - 540 = 5 unidades
- Valor perdas = 5 × R$ 2,00 = R$ 10,00
```

### **Executar:**

```bash
curl -X GET "http://localhost/caixa-seguro-7xy3q9kkle/api/relatorio_analise_estoque_corrigido.php?data_inicio=2025-12-20&data_fim=2025-12-20" | jq '.data[0] | {estoque_inicial, entradas_periodo, vendidas_periodo, estoque_teorico_final, estoque_real_atual, perdas_quantidade, perdas_valor}'
```

### **Validação Esperada:**

```json
{
  "estoque_inicial": 500,
  "entradas_periodo": 100,
  "vendidas_periodo": 50,
  "estoque_teorico_final": 545,
  "estoque_real_atual": 540,
  "perdas_quantidade": 5,
  "perdas_valor": 10.00
}
```

### **Resultado do Teste:**

- [ ] Estoque teórico = 545?
- [ ] Perdas quantidade = 5?
- [ ] Perdas valor = 10,00?
- [ ] Nenhum arredondamento incorreto?

---

## 🔍 **TESTE 6: FECHAMENTO AUTOMÁTICO**

### **Objetivo:** Validar que a procedure gera fechamentos corretamente

### **Executar:**

```bash
# Gerar para data específica
mysql -u root -p gestaointeli_db \
  -e "CALL gerar_fechamento_diario_automatico('2025-12-14');"

# Verificar registros criados
mysql -u root -p gestaointeli_db -e "
  SELECT 
    produto_id, 
    data_fechamento, 
    estoque_real,
    estoque_teorico,
    diferenca,
    status
  FROM fechamento_diario_estoque 
  WHERE data_fechamento = '2025-12-14'
  ORDER BY produto_id;"
```

### **Validação Esperada:**

- [ ] Número de registros = número de produtos ativos?
- [ ] Todos com status = 'concluido'?
- [ ] Diferença = estoque_teorico - estoque_real?
- [ ] Valores fazem sentido?

---

## 🔍 **TESTE 7: ISOLAMENTO DE PERÍODOS**

### **Objetivo:** Validar que períodos diferentes não interferem

### **Setup:**

```
Período 1: 01/12 a 07/12
Período 2: 08/12 a 15/12
Período 3: 16/12 a 23/12
```

### **Executar:**

```bash
# Relatório Período 1
curl -s "http://localhost/.../api/relatorio_analise_estoque_corrigido.php?data_inicio=2025-12-01&data_fim=2025-12-07" | jq '.totais.total_vendidas' > periodo1.txt

# Relatório Período 2
curl -s "http://localhost/.../api/relatorio_analise_estoque_corrigido.php?data_inicio=2025-12-08&data_fim=2025-12-15" | jq '.totais.total_vendidas' > periodo2.txt

# Relatório Período 3
curl -s "http://localhost/.../api/relatorio_analise_estoque_corrigido.php?data_inicio=2025-12-16&data_fim=2025-12-23" | jq '.totais.total_vendidas' > periodo3.txt

# Verificar que cada período tem seus próprios dados
echo "Período 1:" && cat periodo1.txt
echo "Período 2:" && cat periodo2.txt
echo "Período 3:" && cat periodo3.txt
```

### **Validação Esperada:**

- [ ] Período 1 ≠ Período 2 ≠ Período 3?
- [ ] Soma de vendas por período ≠ acumulado?
- [ ] Cada período é independente?

---

## ✅ **CHECKLIST FINAL**

Marca todos os testes que passaram:

- [ ] Teste 1: Bug crítico foi corrigido (vendas anterior não aparecem como perda)
- [ ] Teste 2: Períodos estão isolados (semana 2 não acumula semana 1)
- [ ] Teste 3: Modal carrega alertas corretamente
- [ ] Teste 4: Marcação como visualizada funciona
- [ ] Teste 5: Cálculos matemáticos estão 100% corretos
- [ ] Teste 6: Fechamento automático cria registros
- [ ] Teste 7: Períodos são completamente isolados

---

## 📊 **RESULTADO ESPERADO**

Quando TODOS os 7 testes passarem:

✅ **Sistema está corrigido e pronto para produção**

- Não há mais perdas fantasmas
- Cálculos são precisos por período
- Modal funciona corretamente
- Dados não acumulam de períodos anteriores
- Auditoria registra todas as ações

---

## 🐛 **SE ALGUM TESTE FALHAR**

Revise os arquivos:

1. **Script SQL:** `database/13_migracao_correcao_logica_perdas.sql`
2. **API relatório:** `api/relatorio_analise_estoque_corrigido.php`
3. **API modal:** `api/modal_historico_perdas.php`
4. **API marcar:** `api/marcar_perda_visualizada_v2.php`

Verifique:
- Tabela `fechamento_diario_estoque` foi criada?
- Procedure `relatorio_analise_estoque_periodo_corrigido` existe?
- APIs estão no diretório correto?
- Conexão com BD funciona?

---

**Data:** 14 de Dezembro de 2025  
**Versão:** 2.0 (Corrigida)  
**Status:** Pronto para Testes
