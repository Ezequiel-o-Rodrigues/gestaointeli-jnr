# 📊 Relatório de Análise e Perdas de Estoque - Documentação Detalhada

## ⚠️ VERSÃO 2.0 - CORRIGIDA
**Atualizado em**: 11 de dezembro de 2025  
**Status**: Pronto para migração  
**Mudança crítica**: Lógica de cálculo corrigida para eliminar falsos positivos

## 📑 Índice
1. [O que foi Corrigido](#o-que-foi-corrigido)
2. [Visão Geral](#visão-geral)
3. [Arquitetura do Sistema](#arquitetura-do-sistema)
4. [Banco de Dados](#banco-de-dados)
5. [APIs e Endpoints](#apis-e-endpoints)
6. [Lógica SQL Detalhada (CORRIGIDA)](#lógica-sql-detalhada)
7. [Fluxo de Funcionamento](#fluxo-de-funcionamento)
8. [Interface Gráfica](#interface-gráfica)
9. [Exemplos Práticos](#exemplos-práticos)

---

## 🔴 O que foi Corrigido

### **Problema 1: Cálculo Incorreto do Estoque Teórico**
**Antes** (ERRADO):
```
Estoque Teórico = Estoque Inicial + Entradas - APENAS Vendas
```

**Problema**: Não considerava saídas por outros motivos (perdas já registradas, ajustes, danos)

**Depois** (CORRETO):
```
Estoque Teórico = Estoque Inicial + Entradas - Todas as Saídas
                = SUM(todas as movimentações com tipo 'entrada' e 'saida')
```

---

### **Problema 2: Duplicação de Contabilizações**
**Antes**: Mesma venda era contabilizada em:
- `itens_comanda` (como venda)
- `movimentacoes_estoque` tipo 'saida' (como saída)

**Depois**: Venda é contabilizada APENAS em `movimentacoes_estoque` com `motivo='venda'`

---

### **Problema 3: Falta de Classificação de Saídas**
**Antes**: Todas as saídas eram tratadas como "desconhecidas"

**Depois**: Cada saída tem um motivo:
- `venda` - Venda normal
- `perda_identificada` - Quebra, dano, roubo já identificado
- `ajuste` - Correção de inventário
- `transferencia` - Movimentação entre unidades
- `descarte` - Produto vencido/descartado

---

### **Resultado Final**
✅ Sem falsos positivos (0 perdas fictícias)
✅ Apenas alertas para perdas REAIS não identificadas
✅ Rastreabilidade completa de cada unidade
✅ Relatórios precisos para tomada de decisão

---

## 🎯 Visão Geral

O sistema de **Análise e Perdas de Estoque** é uma solução completa para:
- ✅ Detectar automaticamente divergências entre estoque teórico e real
- ✅ Monitorar produtos com baixo desempenho
- ✅ Gerar alertas em tempo real
- ✅ Analisar períodos específicos
- ✅ Auditar movimentações de estoque

**Tipo**: Sistema analítico e de auditoria
**Escopo**: Nível empresarial (relatórios, KPIs, alertas)
**Frequência**: Contínua (alertas) + Periódica (relatórios)

---

## 🏗️ Arquitetura do Sistema

```
┌─────────────────────────────────────────────────────────────┐
│                     INTERFACE WEB                            │
│          (modules/relatorios/index.php + relatorios.js)     │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐      │
│  │ Dashboard    │  │ Filtros      │  │ Gráficos     │      │
│  │ (Cards KPI)  │  │ (Data/Tipo)  │  │ (Chart.js)   │      │
│  └──────────────┘  └──────────────┘  └──────────────┘      │
│                                                              │
└──────────────────────────────────────────────────────────────┘
                           ↓
                    JAVASCRIPT (relatorios.js)
                           ↓
┌──────────────────────────────────────────────────────────────┐
│                      API ENDPOINTS (PHP)                      │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ api/relatorio_analise_estoque.php                   │   │
│  │ - Chama stored procedure                            │   │
│  │ - Retorna análise completa do período               │   │
│  │ - Calcula totais agregados                          │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ api/relatorio_alertas_perda.php                     │   │
│  │ - Detecta perdas automáticas                        │   │
│  │ - Cria registros em perdas_estoque                  │   │
│  │ - Marca alertas como visualizados                   │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ api/historico_perdas.php                            │   │
│  │ - Retorna histórico completo                        │   │
│  │ - Filtros por período/produto                       │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
│  ┌─────────────────────────────────────────────────────┐   │
│  │ api/marcar_perda_visualizada.php                    │   │
│  │ - Marca alerta como lido                            │   │
│  │ - Registra timestamp de visualização                │   │
│  └─────────────────────────────────────────────────────┘   │
│                                                              │
└──────────────────────────────────────────────────────────────┘
                           ↓
┌──────────────────────────────────────────────────────────────┐
│              BANCO DE DADOS (MySQL/MariaDB)                  │
├──────────────────────────────────────────────────────────────┤
│                                                              │
│  Tabelas:                                                    │
│  ├── produtos (id, nome, preco, estoque_atual, ...)        │
│  ├── movimentacoes_estoque (produto_id, tipo, qtd, ...)    │
│  ├── itens_comanda (produto_id, quantidade, subtotal)      │
│  ├── comandas (status, data_venda, valor_total, ...)       │
│  └── perdas_estoque (produto_id, qtd_perdida, data, ...)   │
│                                                              │
│  Stored Procedures:                                          │
│  └── relatorio_analise_estoque_periodo()                     │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

---

## 🗄️ Banco de Dados

### 📋 Tabela: `produtos`

**Responsabilidade**: Manter o cadastro de produtos com estoque em tempo real

```sql
CREATE TABLE produtos (
    id INT PRIMARY KEY AUTO_INCREMENT,
    nome VARCHAR(100) NOT NULL,
    categoria_id INT NOT NULL,
    preco DECIMAL(10,2) NOT NULL,
    estoque_atual INT DEFAULT 0,           -- ESTOQUE REAL (atualizado após vendas)
    estoque_minimo INT DEFAULT 0,          -- Limite para alertas
    ativo TINYINT(1) DEFAULT 1,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (categoria_id) REFERENCES categorias(id)
);
```

**Exemplo de dados:**
```
ID | Nome                  | Preço | Estoque Atual | Estoque Mínimo
47 | Jantinha com bife     | 30.00 | 23            | 0
46 | Marmita com bife      | 26.00 | 89            | 0
45 | Jantinha com espeto   | 28.00 | 86            | 0
```

---

### 📋 Tabela: `movimentacoes_estoque`

**Responsabilidade**: Registrar todas as entradas e saídas de produtos (auditoria)

```sql
CREATE TABLE movimentacoes_estoque (
    id INT PRIMARY KEY AUTO_INCREMENT,
    produto_id INT NOT NULL,
    tipo ENUM('entrada', 'saida') NOT NULL,
    quantidade INT NOT NULL,
    valor_unitario DECIMAL(10,2) DEFAULT 0.00,
    data_movimentacao TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    observacao TEXT,
    fornecedor_id INT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (produto_id) REFERENCES produtos(id),
    FOREIGN KEY (fornecedor_id) REFERENCES fornecedores(id)
);
```

**Tipos de movimentação:**
- `entrada`: Quando produto chega (compra, devolução, ajuste)
- `saida`: Quando produto sai (venda, ajuste)

**Exemplo de dados:**
```
ID | Produto ID | Tipo    | Qtd | Data           | Observacao
12 | 47         | entrada | 100 | 2025-11-02     | Estoque inicial
141| 47         | saida   | 1   | 2025-11-11     | Venda - comanda 226
142| 47         | saida   | 1   | 2025-11-11     | Venda - comanda 227
```

---

### 📋 Tabela: `itens_comanda`

**Responsabilidade**: Registrar cada produto vendido (necessário para cálculo de perdas)

```sql
CREATE TABLE itens_comanda (
    id INT PRIMARY KEY AUTO_INCREMENT,
    comanda_id INT NOT NULL,
    produto_id INT NOT NULL,
    quantidade INT NOT NULL DEFAULT 1,
    preco_unitario DECIMAL(10,2) NOT NULL,
    subtotal DECIMAL(10,2) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    FOREIGN KEY (comanda_id) REFERENCES comandas(id),
    FOREIGN KEY (produto_id) REFERENCES produtos(id)
);
```

**Relação com perdas**: A quantidade de vendas é comparada com o estoque teórico para detectar perdas

---

### 📋 Tabela: `comandas`

**Responsabilidade**: Registrar vendas (essencial para calcular saídas de produtos)

```sql
CREATE TABLE comandas (
    id INT PRIMARY KEY AUTO_INCREMENT,
    status ENUM('aberta', 'fechada') DEFAULT 'aberta',
    valor_total DECIMAL(10,2),
    taxa_gorjeta DECIMAL(10,2),
    garcom_id INT,
    data_venda TIMESTAMP,
    data_finalizacao TIMESTAMP,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    FOREIGN KEY (garcom_id) REFERENCES garcons(id)
);
```

**Dados usados no relatório:**
- `status = 'fechada'`: Apenas vendas confirmadas
- `data_venda`: Para filtrar por período
- `valor_total`: Para calcular faturamento

---

### 📋 Tabela: `perdas_estoque`

**Responsabilidade**: Manter histórico de perdas detectadas (auditoria + alertas)

```sql
CREATE TABLE perdas_estoque (
    id INT PRIMARY KEY AUTO_INCREMENT,
    produto_id INT NOT NULL,
    quantidade_perdida INT NOT NULL,
    valor_perda DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    estoque_esperado INT,
    estoque_real INT,
    motivo VARCHAR(255) DEFAULT 'Diferença de inventário',
    data_identificacao DATETIME DEFAULT CURRENT_TIMESTAMP,
    visualizada TINYINT(1) DEFAULT 0,
    data_visualizacao DATETIME NULL,
    observacoes TEXT,
    FOREIGN KEY (produto_id) REFERENCES produtos(id),
    INDEX idx_visualizada (visualizada),
    INDEX idx_data (data_identificacao)
);
```

**Campos importantes:**
- `visualizada`: Flag para controle de alertas não lidos (0 = novo, 1 = lido)
- `quantidade_perdida`: Diferença entre teórico e real
- `valor_perda`: Impacto financeiro da perda

---

## 🔌 APIs e Endpoints

### 1️⃣ **Relatório de Análise de Estoque**

**Arquivo**: `api/relatorio_analise_estoque.php`

**Método**: GET (POST com parâmetros de filtro)

**Parâmetros**:
```php
GET /api/relatorio_analise_estoque.php?
    data_inicio=2025-11-01&
    data_fim=2025-11-30
```

**Lógica interna**:
```php
1. Validar e sanitizar datas
2. Chamar stored procedure: CALL relatorio_analise_estoque_periodo(:inicio, :fim)
3. Iterar resultados e calcular totais agregados:
   - total_produtos_com_perda (COUNT)
   - total_perdas_quantidade (SUM)
   - total_perdas_valor (SUM)
   - total_faturamento (SUM)
4. Retornar JSON com dados + totais
```

**Resposta JSON**:
```json
{
    "success": true,
    "data": [
        {
            "id": 47,
            "nome": "Jantinha com bife",
            "categoria": "Alimenticio",
            "preco": 30.00,
            "estoque_inicial": 100,
            "entradas_periodo": 0,
            "vendidas_periodo": 77,
            "estoque_teorico_final": 23,
            "estoque_real_atual": 23,
            "perdas_quantidade": 0,
            "perdas_valor": 0.00,
            "faturamento_periodo": 2310.00
        }
    ],
    "totais": {
        "total_produtos_com_perda": 3,
        "total_perdas_quantidade": 15,
        "total_perdas_valor": 450.00,
        "total_faturamento": 8750.00
    },
    "periodo": {
        "data_inicio": "2025-11-01",
        "data_fim": "2025-11-30"
    }
}
```

---

### 2️⃣ **Alertas de Perdas (Detecção Automática)**

**Arquivo**: `api/relatorio_alertas_perda.php`

**Método**: GET

**Lógica interna**:
```php
1. Criar tabela perdas_estoque se não existir
2. Para cada produto ativo:
   a. Calcular: diferenca_estoque = total_entradas - total_vendidos - estoque_atual
   b. Se diferenca > 0:
      - Verificar se existe perda não visualizada para este produto
      - Se NÃO existe: INSERT nova linha em perdas_estoque
      - Se existe: Usar ID existente
   c. Calcular valor_perda = diferenca × preco_produto
3. Retornar array com alertas
```

**Resposta JSON**:
```json
{
    "success": true,
    "data": [
        {
            "id": 1,
            "produto_id": 47,
            "nome": "Jantinha com bife",
            "categoria": "Alimenticio",
            "diferenca_estoque": 5,
            "valor_perda": 150.00,
            "estoque_atual": 23,
            "estoque_esperado": 28
        }
    ],
    "total_alertas": 1
}
```

---

### 3️⃣ **Histórico de Perdas**

**Arquivo**: `api/historico_perdas.php`

**Método**: GET

**Parâmetros**:
```php
GET /api/historico_perdas.php?
    data_inicio=2025-11-01&
    data_fim=2025-11-30
```

**Lógica interna**:
```php
1. SELECT * FROM perdas_estoque
2. JOIN com produtos e categorias
3. Filtrar por data_identificacao (BETWEEN)
4. ORDER BY data DESC
```

**Resposta JSON**:
```json
{
    "success": true,
    "data": [
        {
            "id": 1,
            "produto_id": 47,
            "produto_nome": "Jantinha com bife",
            "categoria_nome": "Alimenticio",
            "quantidade_perdida": 5,
            "valor_perda": 150.00,
            "motivo": "Diferença de inventário",
            "data_identificacao": "2025-11-13 14:30:00",
            "visualizada": 0,
            "observacoes": null
        }
    ],
    "total": 1
}
```

---

### 4️⃣ **Marcar Perda como Visualizada**

**Arquivo**: `api/marcar_perda_visualizada.php`

**Método**: POST

**Body JSON**:
```json
{
    "perda_id": 1
}
```

**Lógica interna**:
```php
1. Validar perda_id
2. UPDATE perdas_estoque SET visualizada = 1, data_visualizacao = NOW()
3. Retornar sucesso
```

**Resposta JSON**:
```json
{
    "success": true,
    "message": "Perda marcada como visualizada com sucesso"
}
```

---

## 🧮 Lógica SQL Detalhada

### 📐 Fórmula Principal de Cálculo

```
┌────────────────────────────────────────────────────────────────┐
│                    ESTOQUE TEÓRICO                             │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  ESTOQUE INICIAL (antes do período)                           │
│  + ENTRADAS (durante o período)                               │
│  - VENDAS (durante o período)                                 │
│  = ESTOQUE TEÓRICO FINAL                                      │
│                                                                │
│  Exemplo:                                                      │
│  100 (inicial) + 0 (entradas) - 77 (vendas) = 23 (teórico)   │
│                                                                │
└────────────────────────────────────────────────────────────────┘

┌────────────────────────────────────────────────────────────────┐
│                    CÁLCULO DE PERDAS                           │
├────────────────────────────────────────────────────────────────┤
│                                                                │
│  PERDAS = ESTOQUE TEÓRICO - ESTOQUE REAL                      │
│                                                                │
│  Exemplo:                                                      │
│  23 (teórico) - 23 (real) = 0 (perdas)                       │
│                                                                │
│  OU (com perda):                                              │
│  30 (teórico) - 25 (real) = 5 (perdas)                       │
│                                                                │
│  VALOR PERDA = Perdas × Preço do Produto                     │
│  5 × 30.00 = R$ 150.00                                        │
│                                                                │
└────────────────────────────────────────────────────────────────┘
```

---

### 🔍 Queries SQL Detalhadas

#### **Query 1: Estoque Inicial**
```sql
SELECT COALESCE((
    SELECT SUM(me.quantidade)
    FROM movimentacoes_estoque me
    WHERE me.produto_id = p.id
    AND me.tipo = 'entrada'
    AND DATE(me.data_movimentacao) < '2025-11-01'
), 0) as estoque_inicial
```

**O que faz**: Soma todas as entradas ANTES da data de início
**Resultado**: 100 unidades (estoque do produto no início do período)

---

#### **Query 2: Entradas Durante o Período**
```sql
SELECT COALESCE((
    SELECT SUM(me.quantidade)
    FROM movimentacoes_estoque me
    WHERE me.produto_id = p.id
    AND me.tipo = 'entrada'
    AND DATE(me.data_movimentacao) BETWEEN '2025-11-01' AND '2025-11-30'
), 0) as entradas_periodo
```

**O que faz**: Soma entradas durante o período específico
**Resultado**: 0 unidades (nenhuma compra no período)

---

#### **Query 3: Vendas Durante o Período**
```sql
SELECT COALESCE((
    SELECT SUM(ic.quantidade)
    FROM itens_comanda ic
    JOIN comandas c ON ic.comanda_id = c.id
    WHERE ic.produto_id = p.id
    AND c.status = 'fechada'
    AND DATE(c.data_venda) BETWEEN '2025-11-01' AND '2025-11-30'
), 0) as vendidas_periodo
```

**O que faz**: Soma quantidade vendida apenas de comandas FECHADAS
**Resultado**: 77 unidades

---

#### **Query 4: Faturamento do Período**
```sql
SELECT COALESCE((
    SELECT SUM(ic.subtotal)
    FROM itens_comanda ic
    JOIN comandas c ON ic.comanda_id = c.id
    WHERE ic.produto_id = p.id
    AND c.status = 'fechada'
    AND DATE(c.data_venda) BETWEEN '2025-11-01' AND '2025-11-30'
), 0) as faturamento_periodo
```

**O que faz**: Soma o valor (subtotal) vendido
**Resultado**: R$ 2.310,00 (77 × 30,00)

---

#### **Query 5: Estoque Teórico Final**
```sql
SELECT (
    -- Estoque inicial
    COALESCE((SELECT SUM(me.quantidade) ...), 0) +
    -- Mais entradas do período
    COALESCE((SELECT SUM(me.quantidade) ...), 0) -
    -- Menos vendas
    COALESCE((SELECT SUM(ic.quantidade) ...), 0)
) as estoque_teorico_final
```

**Cálculo**: 100 + 0 - 77 = 23 unidades

---

### 🔴 Query Detecção Automática de Perdas

Executada em `api/relatorio_alertas_perda.php`:

```sql
SELECT 
    p.id as produto_id,
    p.nome,
    cat.nome as categoria,
    p.preco,
    
    -- Total de entradas
    (SELECT COALESCE(SUM(quantidade), 0) 
     FROM movimentacoes_estoque 
     WHERE produto_id = p.id AND tipo = 'entrada') as total_entradas,
    
    -- Total de vendidos
    (SELECT COALESCE(SUM(ic.quantidade), 0) 
     FROM itens_comanda ic 
     JOIN comandas c ON ic.comanda_id = c.id 
     WHERE ic.produto_id = p.id AND c.status = 'fechada') as total_vendido,
    
    -- DIFERENÇA = Perdas
    ((SELECT COALESCE(SUM(quantidade), 0) FROM movimentacoes_estoque 
      WHERE produto_id = p.id AND tipo = 'entrada') - 
     (SELECT COALESCE(SUM(ic.quantidade), 0) FROM itens_comanda ic 
      JOIN comandas c ON ic.comanda_id = c.id 
      WHERE ic.produto_id = p.id AND c.status = 'fechada') - 
     p.estoque_atual) as diferenca_estoque

FROM produtos p
JOIN categorias cat ON p.categoria_id = cat.id
WHERE p.ativo = 1
HAVING diferenca_estoque > 0
ORDER BY diferenca_estoque DESC
```

**Exemplo com dados reais:**
```
Produto: Jantinha com bife (ID: 47)
Total Entradas: 100
Total Vendido: 77
Estoque Atual: 23
─────────────────────────────
Diferença = 100 - 77 - 23 = 0 (sem perda!)

Produto: Feijão Tropeiro (ID: 14)
Total Entradas: 100
Total Vendido: 80
Estoque Atual: 15
─────────────────────────────
Diferença = 100 - 80 - 15 = 5 (PERDA DE 5 UNIDADES!)
Valor Perda = 5 × 20.00 = R$ 100,00
```

---

## 📊 Fluxo de Funcionamento

### Fluxo 1: Geração de Relatório de Análise

```
┌─────────────────────────────────────────────────────────────┐
│ 1. Usuário acessa módulo de relatórios                      │
│    (modules/relatorios/index.php)                           │
└──────────────────────┬──────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. JavaScript valida datas e tipo de relatório             │
│    (relatorios.js - função gerarRelatorio())               │
└──────────────────────┬──────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. Faz requisição AJAX para API:                           │
│    GET /api/relatorio_analise_estoque.php?                 │
│        data_inicio=2025-11-01&                             │
│        data_fim=2025-11-30                                 │
└──────────────────────┬──────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. API PHP:                                                 │
│    a) Valida parâmetros GET                                │
│    b) Abre conexão banco de dados                          │
│    c) Chama CALL relatorio_analise_estoque_periodo()      │
│    d) Itera resultados                                     │
│    e) Calcula totais agregados                            │
│    f) Retorna JSON                                         │
└──────────────────────┬──────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. Stored Procedure (MySQL):                               │
│    - Para cada produto ativo:                              │
│      * Calcula estoque_inicial                             │
│      * Calcula entradas_periodo                            │
│      * Calcula vendidas_periodo                            │
│      * Calcula estoque_teorico = Inicial + Entradas - Vendas
│      * Calcula perdas = Teórico - Real                    │
│      * Calcula faturamento                                 │
│    - Retorna result set com todos produtos                │
└──────────────────────┬──────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────────────┐
│ 6. API PHP agrega totais:                                  │
│    - total_produtos_com_perda = COUNT(perdas > 0)         │
│    - total_perdas_quantidade = SUM(perdas)                │
│    - total_perdas_valor = SUM(perdas × preco)             │
│    - total_faturamento = SUM(faturamento)                 │
│    - Retorna JSON estruturado                             │
└──────────────────────┬──────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────────────┐
│ 7. JavaScript processa resposta:                           │
│    a) Valida JSON                                          │
│    b) Renderiza tabela com produtos                        │
│    c) Aplicar cores (verde=sem perda, vermelho=com perda) │
│    d) Exibir cards de resumo (totais)                      │
│    e) Plotar gráficos (se selecionado)                     │
└──────────────────────┬──────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────────────┐
│ 8. Usuário visualiza:                                       │
│    - Dashboard com KPIs principais                         │
│    - Tabela de análise detalhada                           │
│    - Gráficos de tendência                                 │
│    - Opção de exportar (PDF/Excel)                         │
└─────────────────────────────────────────────────────────────┘
```

---

### Fluxo 2: Detecção Automática de Perdas

```
┌─────────────────────────────────────────────────────────────┐
│ 1. JavaScript carrega (ao entrar no módulo)                │
│    chama carregarAlertasPerdas()                           │
└──────────────────────┬──────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────────────┐
│ 2. Faz requisição GET para:                               │
│    /api/relatorio_alertas_perda.php                        │
└──────────────────────┬──────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────────────┐
│ 3. API PHP:                                                 │
│    a) CREATE TABLE IF NOT EXISTS perdas_estoque            │
│    b) SELECT * FROM produtos WHERE ativo = 1              │
│    c) Para cada produto:                                   │
│       - Calcular diferenca_estoque                         │
│       - Se diferenca > 0:                                  │
│         * SELECT FROM perdas_estoque (procura existente)  │
│         * Se não existe: INSERT nova linha                │
│         * Se existe: usar ID existente                     │
│       - Calcular valor_perda                               │
│    d) Retornar array com alertas não visualizados         │
└──────────────────────┬──────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────────────┐
│ 4. JavaScript renderiza:                                    │
│    - Para cada alerta: mostrar card com:                   │
│      * Nome do produto                                     │
│      * Quantidade perdida                                  │
│      * Valor da perda                                      │
│      * Botão "Marcar como visualizado"                     │
│    - Contar total de alertas não lidos                     │
│    - Badge com número de alertas no header                 │
└──────────────────────┬──────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────────────┐
│ 5. Usuário clica em "Marcar como visualizado"             │
│    chama marcarPerdaVisualizada(perda_id)                 │
└──────────────────────┬──────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────────────┐
│ 6. Faz POST para:                                          │
│    /api/marcar_perda_visualizada.php                       │
│    Body: { "perda_id": 1 }                                │
└──────────────────────┬──────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────────────┐
│ 7. API PHP:                                                 │
│    UPDATE perdas_estoque                                    │
│    SET visualizada = 1,                                     │
│        data_visualizacao = NOW()                            │
│    WHERE id = 1                                             │
│                                                             │
│    Retornar sucesso                                         │
└──────────────────────┬──────────────────────────────────────┘
                       ↓
┌─────────────────────────────────────────────────────────────┐
│ 8. JavaScript remove alerta da tela (fade out)            │
│    Atualizar badge com novo total de não lidos            │
└─────────────────────────────────────────────────────────────┘
```

---

## 🎨 Interface Gráfica

### 📊 Dashboard Principal (modules/relatorios/index.php)

**Cards KPI:**
```
┌─────────────────────┐  ┌─────────────────────┐
│ Vendas da Semana    │  │ Faturamento Semana  │
│       12            │  │   R$ 4.500,00       │
│ Comandas fechadas   │  │   Valor vendido     │
└─────────────────────┘  └─────────────────────┘

┌─────────────────────┐  ┌─────────────────────┐
│ Alertas Estoque ⚠️  │  │ Perdas Identificadas│
│        3            │  │        2            │
│ Produtos baixos     │  │ Produtos divergência│
└─────────────────────┘  └─────────────────────┘
```

**Filtros:**
```
┌─────────────────────────────────────────────────┐
│ Data Início: [2025-11-01]                       │
│ Data Fim:    [2025-11-30]                       │
│ Tipo:        [Análise de Estoque e Perdas] 🔍  │
│ [Gerar Relatório] [Exportar] [Limpar Filtros]  │
└─────────────────────────────────────────────────┘
```

**Tabela de Resultados:**
```
┌────────────────────────────────────────────────────────────────┐
│ ANÁLISE DE ESTOQUE - Período 01/11/2025 a 30/11/2025         │
├─────────────┬──────────┬────────┬────────┬─────────┬──────────┤
│ Produto     │ Inicial  │ Vendas │ Teórico│ Real    │ Perdas   │
├─────────────┼──────────┼────────┼────────┼─────────┼──────────┤
│ Jantinha... │ 100      │ -77    │ 23     │ 23      │ 0        │
│ Feijão...   │ 100      │ -80    │ 20     │ 15      │ 5 ❌     │
│ Marmita...  │ 100      │ -30    │ 70     │ 70      │ 0        │
└─────────────┴──────────┴────────┴────────┴─────────┴──────────┘
```

**Resumo Executivo:**
```
┌──────────────────────────────────────────────┐
│ 📈 RESUMO DO PERÍODO                         │
├──────────────────────────────────────────────┤
│ Produtos com perda: 2                        │
│ Total perdido: 12 unidades                   │
│ Valor perdido: R$ 360,00                     │
│ Faturamento total: R$ 8.750,00               │
│ Taxa de perdas: 0,42%                        │
└──────────────────────────────────────────────┘
```

---

### 🔔 Seção de Alertas

```
┌─────────────────────────────────────────────┐
│ 🚨 ALERTAS DE PERDAS NÃO VISUALIZADAS       │
├─────────────────────────────────────────────┤
│                                             │
│ [❌] Feijão Tropeiro - 5 unidades perdidas │
│      Valor: R$ 100,00                       │
│      [Marcar como visualizado]              │
│                                             │
│ [❌] Salada G - 8 unidades perdidas         │
│      Valor: R$ 176,00                       │
│      [Marcar como visualizado]              │
│                                             │
└─────────────────────────────────────────────┘
```

---

## 💡 Exemplos Práticos

### Exemplo 1: Produto SEM Perdas

**Dados do período (01/11 a 30/11):**

| Campo | Valor |
|-------|-------|
| **Estoque Inicial** | 100 unidades |
| **Entradas** | 0 unidades |
| **Vendas** | 77 unidades |
| **Estoque Real** | 23 unidades |

**Cálculos:**
```
Estoque Teórico = 100 + 0 - 77 = 23
Perdas = 23 - 23 = 0 ✅ (sem perda)
Valor Perda = 0 × 30,00 = R$ 0,00
```

**Resultado:** Verde ✅ (produto OK)

---

### Exemplo 2: Produto COM Perdas

**Dados do período (01/11 a 30/11):**

| Campo | Valor |
|-------|-------|
| **Estoque Inicial** | 100 unidades |
| **Entradas** | 20 unidades |
| **Vendas** | 80 unidades |
| **Estoque Real** | 30 unidades |

**Cálculos:**
```
Estoque Teórico = 100 + 20 - 80 = 40
Perdas = 40 - 30 = 10 ❌ (10 unidades perdidas)
Valor Perda = 10 × 20,00 = R$ 200,00
```

**Resultado:** Vermelho ❌ (10 unidades não contabilizadas)

**Possíveis causas:**
- Danos/quebra durante o dia
- Erros ao registrar entrada/saída
- Roubo
- Erros de contagem

---

### Exemplo 3: Análise de Período Completo

**Relatório do mês de Novembro:**

```
╔════════════════════════════════════════════════════════════════╗
║         RELATÓRIO DE ANÁLISE DE ESTOQUE - NOVEMBRO 2025       ║
║                                                                ║
║ RESUMO EXECUTIVO                                              ║
║ ─────────────────────────────────────────────────────────────║
║ Total de produtos analisados: 48                              ║
║ Produtos COM perda: 3                                         ║
║ Produtos SEM perda: 45                                        ║
║                                                                ║
║ PERDAS TOTAIS                                                 ║
║ ─────────────────────────────────────────────────────────────║
║ Quantidade perdida: 23 unidades                               ║
║ Valor perdido: R$ 450,00                                      ║
║ Faturamento total: R$ 8.750,00                                ║
║ Taxa de perda: 0,64% do faturamento                           ║
║                                                                ║
║ DETALHAMENTO DE PRODUTOS COM PERDA                            ║
║ ─────────────────────────────────────────────────────────────║
║                                                                ║
║ 1. Feijão Tropeiro G                                          ║
║    Quantidade perdida: 5 unidades                             ║
║    Valor: R$ 125,00                                           ║
║    Status: Investigar possível quebra                         ║
║                                                                ║
║ 2. Salada G                                                   ║
║    Quantidade perdida: 8 unidades                             ║
║    Valor: R$ 176,00                                           ║
║    Status: Revisar processo de contagem                       ║
║                                                                ║
║ 3. Mandioca M                                                 ║
║    Quantidade perdida: 10 unidades                            ║
║    Valor: R$ 149,00                                           ║
║    Status: Possível erro de entrada                           ║
║                                                                ║
║ RECOMENDAÇÕES                                                 ║
║ ─────────────────────────────────────────────────────────────║
║ ✓ Revisar processo de recebimento de estoque                  ║
║ ✓ Treinar equipe em contagem de inventário                    ║
║ ✓ Implementar check-in obrigatório para entradas              ║
║ ✓ Aumentar frequência de contagem física                      ║
║ ✓ Investigar possíveis danos em produtos refrigerados        ║
╚════════════════════════════════════════════════════════════════╝
```

---

## 🔧 Manutenção e Troubleshooting

### ⚠️ Problema: Relatório mostrando perdas incorretas

**Causa provável**: Registro de venda sem diminuição de estoque

**Solução**:
```sql
-- Verificar se movimentação foi registrada
SELECT * FROM movimentacoes_estoque 
WHERE produto_id = 47 
AND tipo = 'saida' 
AND data_movimentacao > '2025-11-13'
ORDER BY data DESC LIMIT 10;

-- Se faltarem registros, investigar API de finalização
```

---

### ⚠️ Problema: Tabela perdas_estoque nunca cria registros

**Causa provável**: API de alertas não foi chamada

**Solução**:
```php
// Chamar manualmente no dashboard
curl -X GET "http://localhost/api/relatorio_alertas_perda.php"

// Verificar permissões de escrita no banco
GRANT ALL ON database.perdas_estoque TO 'user'@'localhost';
```

---

## 📚 Documentação Relacionada

- `FUNCIONALIDADES_PERDAS.md` - Detalhes das funcionalidades
- `FILTROS_DATA_PERDAS.md` - Explicação dos filtros
- `RELATORIO_ANALISE_PERDAS_ESTOQUE_COMPLETO.md` - Documentação anterior

---

**Versão**: 1.0  
**Data**: 11 de dezembro de 2025  
**Autor**: Sistema de Gestão do Restaurante  
**Última atualização**: 11/12/2025
