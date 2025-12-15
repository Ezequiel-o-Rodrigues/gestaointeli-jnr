# 📋 Correção: Cálculo de Perdas Considerando Estoque Inicial

## Problema Encontrado

Quando você gerava um relatório **apenas para hoje**, e hoje **não havia entradas de estoque**, mas havia **vendas do estoque anterior**, o sistema retornava:

- ❌ **Nenhuma venda registrada**
- ❌ **Estoque zerado**

Isso ocorria porque a fórmula usava:

```
Perdas = Entradas_Período - Vendas_Período - Estoque_Real
```

Quando:
- Entradas_Período = 0 (sem entrada hoje)
- Vendas_Período = X (vendas aconteceram)
- Resultado = 0 - X - EstoqueReal = NEGATIVO = 0

## Solução Implementada

✅ **Alterada a fórmula para considerar estoque inicial:**

```
Perdas = (Estoque_Inicial + Entradas_Período) - Vendas_Período - Estoque_Real
```

Onde:
- **Estoque_Inicial** = Estoque teórico no dia ANTES do período
- **Entradas_Período** = Inventários registrados no período
- **Vendas_Período** = Vendas realizadas no período
- **Estoque_Real** = Estoque físico atual

## Correções Aplicadas

### 1️⃣ Função: `fn_perdas_periodo()`

**Antes:**
```sql
v_estoque_teorico = entradas - saidas
v_perda = GREATEST(0, v_estoque_teorico - estoque_real)
```

**Depois:**
```sql
v_estoque_inicial = fn_estoque_teorico_ate_data(produto, dia_antes)
v_estoque_disponivel = v_estoque_inicial + entradas
v_perda = GREATEST(0, v_estoque_disponivel - vendas - estoque_real)
```

### 2️⃣ Stored Procedure: `relatorio_perdas_periodo_correto()`

Adicionada coluna **`estoque_inicial`** e ajustada fórmula de cálculo:

```sql
estoque_inicial = fn_estoque_teorico_ate_data(produto, p_data_inicio - 1 dia)

perdas = GREATEST(0, 
    (estoque_inicial + entradas - vendas) - estoque_real
)
```

## Exemplos Práticos

### Cenário 1: Venda sem Entrada

**Dados:**
- 13/12: Inventário registrou 100 unidades
- 14/12: Sem entrada, vendeu 10 unidades, estoque físico = 90

**Cálculo ANTIGO:**
```
Perdas = 0 - 10 - 90 = -100 → 0 (sem perdas)  ❌ ERRADO
```

**Cálculo NOVO:**
```
Estoque Inicial (antes do 14) = 100
Perdas = (100 + 0 - 10) - 90 = 0 (sem perdas)  ✅ CORRETO
```

### Cenário 2: Venda com Divergência

**Dados:**
- 13/12: Inventário = 100 unidades
- 14/12: Sem entrada, vendeu 10 unidades, estoque físico = 85 (5 unidades desapareceram!)

**Cálculo ANTIGO:**
```
Perdas = 0 - 10 - 85 = -95 → 0 (sem perdas)  ❌ ERRADO
```

**Cálculo NOVO:**
```
Estoque Inicial = 100
Perdas = (100 + 0 - 10) - 85 = 5 unidades  ✅ CORRETO
```

## Testes Realizados

✅ API `/api/executar_correcao_perdas.php` 
   - ✅ Função `fn_perdas_periodo` recriada
   - ✅ Procedure `relatorio_perdas_periodo_correto` atualizada

✅ Relatório de hoje
   - Total de produtos: 35
   - Produtos com perda: 1

✅ Cálculos testados com sucesso

## Coluna de Saída Atualizada

O relatório agora inclui:

| Campo | Descrição |
|-------|-----------|
| `estoque_inicial` | Estoque teórico no dia anterior |
| `entradas_periodo` | Inventários do período |
| `saidas_periodo` | Vendas do período |
| `estoque_teorico_final` | Inicial + Entradas - Vendas |
| `estoque_real_final` | Estoque físico atual |
| `perdas_quantidade` | Diferença não explicada |
| `perdas_valor` | Perdas em R$ |

## Como Usar

1. Vá para **Relatórios** → **Análise de Estoque e Perdas**
2. Escolha um período (ex: somente hoje)
3. Clique em **Gerar Relatório**
4. **O sistema agora vai considerar o estoque anterior** ✅

---

**Status:** ✅ IMPLEMENTADO E TESTADO  
**Data:** 14 de dezembro de 2025  
**Versão:** 1.1 (com estoque inicial)
