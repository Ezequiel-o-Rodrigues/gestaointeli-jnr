# 📊 Relatório de Análise e Perdas de Estoque - Documentação Completa

## 🎯 Visão Geral

O Sistema de Relatório de Análise e Perdas de Estoque é uma funcionalidade avançada que permite identificar, monitorar e gerenciar divergências entre o estoque teórico (calculado) e o estoque real (físico) dos produtos. O sistema detecta automaticamente perdas, oferece análises detalhadas e permite o controle completo do histórico de perdas.

## 🏗️ Arquitetura do Sistema

### 📁 Estrutura de Arquivos

```
📦 Sistema de Análise de Perdas
├── 🗂️ API Endpoints
│   ├── relatorio_analise_estoque.php      # Relatório principal de análise
│   ├── historico_perdas.php               # Histórico completo de perdas
│   ├── relatorio_alertas_perda.php        # Alertas de perdas não visualizadas
│   ├── marcar_perda_visualizada.php       # Marcar perda como visualizada
│   └── criar_tabela_perdas.php            # Criação automática da tabela
├── 🗂️ Interface
│   ├── modules/relatorios/index.php       # Interface principal
│   └── modules/relatorios/relatorios.js   # Lógica JavaScript
├── 🗂️ Banco de Dados
│   ├── perdas_estoque (tabela)            # Registro de perdas
│   ├── produtos (tabela)                  # Produtos do sistema
│   ├── movimentacoes_estoque (tabela)     # Movimentações de entrada/saída
│   └── relatorio_analise_estoque_periodo (stored procedure)
└── 🗂️ Documentação
    ├── FUNCIONALIDADES_PERDAS.md
    ├── FILTROS_DATA_PERDAS.md
    └── RELATORIO_ANALISE_PERDAS_ESTOQUE_COMPLETO.md (este arquivo)
```

## 🗄️ Estrutura do Banco de Dados

### 📋 Tabela: `perdas_estoque`

```sql
CREATE TABLE perdas_estoque (
    id INT AUTO_INCREMENT PRIMARY KEY,
    produto_id INT NOT NULL,
    quantidade_perdida INT NOT NULL,
    valor_perda DECIMAL(10,2) NOT NULL DEFAULT 0.00,
    estoque_esperado INT NOT NULL DEFAULT 0,
    estoque_real INT NOT NULL DEFAULT 0,
    motivo VARCHAR(255) DEFAULT 'Diferença de inventário',
    data_identificacao DATETIME DEFAULT CURRENT_TIMESTAMP,
    visualizada TINYINT(1) DEFAULT 0,
    data_visualizacao DATETIME NULL,
    observacoes TEXT NULL,
    FOREIGN KEY (produto_id) REFERENCES produtos(id) ON DELETE CASCADE
);
```

**Campos Principais:**
- `produto_id`: Referência ao produto com perda
- `quantidade_perdida`: Quantidade de unidades perdidas
- `valor_perda`: Valor monetário da perda (quantidade × preço)
- `estoque_esperado`: Estoque que deveria ter (teórico)
- `estoque_real`: Estoque físico encontrado
- `visualizada`: Flag para controle de visualização (0 = não visualizada, 1 = visualizada)
- `data_visualizacao`: Timestamp de quando foi marcada como visualizada

### 🔧 Stored Procedure: `relatorio_analise_estoque_periodo`

```sql
CALL relatorio_analise_estoque_periodo('2024-11-01', '2024-11-30');
```

**Parâmetros:**
- `p_data_inicio`: Data de início do período de análise
- `p_data_fim`: Data de fim do período de análise

**Retorna:**
- Análise completa de cada produto no período
- Cálculos de estoque inicial, entradas, saídas, estoque teórico
- Identificação de perdas e valores

## 🔌 APIs e Endpoints

### 1. **📊 Relatório de Análise de Estoque**

**Endpoint:** `api/relatorio_analise_estoque.php`

**Método:** GET

**Parâmetros:**
```php
?data_inicio=2024-11-01&data_fim=2024-11-30&categoria_id=1&valor_minimo=10.00&tipo_filtro=com_perda
```

**Resposta:**
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
        "total_produtos_com_perda": 0,
        "total_perdas_quantidade": 0,
        "total_perdas_valor": 0.00,
        "total_faturamento": 2310.00
    },
    "periodo": {
        "data_inicio": "2024-11-01",
        "data_fim": "2024-11-30"
    }
}
```

### 2. **📋 Histórico de Perdas**

**Endpoint:** `api/historico_perdas.php`

**Método:** GET

**Parâmetros:**
```php
?data_inicio=2024-11-01&data_fim=2024-11-30
# OU
?mes_ano=2024-11
```

**Resposta:**
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
            "data_identificacao": "2024-11-13 14:30:00",
            "visualizada": 0,
            "data_visualizacao": null,
            "observacoes": null
        }
    ],
    "total": 1,
    "filtros": {
        "data_inicio": "2024-11-01",
        "data_fim": "2024-11-30",
        "mes_ano": null
    }
}
```

### 3. **⚠️ Alertas de Perdas**

**Endpoint:** `api/relatorio_alertas_perda.php`

**Método:** GET

**Resposta:**
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
            "data_identificacao": "2024-11-13 14:30:00"
        }
    ],
    "total_alertas": 1
}
```

### 4. **✅ Marcar Perda como Visualizada**

**Endpoint:** `api/marcar_perda_visualizada.php`

**Método:** POST

**Body:**
```json
{
    "perda_id": 1
}
```

**Resposta:**
```json
{
    "success": true,
    "message": "Perda marcada como visualizada com sucesso"
}
```

## 🧮 Lógica de Cálculo das Perdas

### 📐 Fórmula Principal

```
Estoque Teórico = Estoque Inicial + Entradas do Período - Vendas do Período
Perdas = Estoque Teórico - Estoque Real Atual
Valor das Perdas = Perdas × Preço do Produto
```

### 🔍 Detalhamento dos Cálculos

1. **Estoque Inicial do Período:**
   ```sql
   SELECT SUM(me.quantidade) 
   FROM movimentacoes_estoque me 
   WHERE me.produto_id = p.id 
   AND me.tipo = 'entrada' 
   AND DATE(me.data_movimentacao) < p_data_inicio
   ```

2. **Entradas Durante o Período:**
   ```sql
   SELECT SUM(me.quantidade) 
   FROM movimentacoes_estoque me 
   WHERE me.produto_id = p.id 
   AND me.tipo = 'entrada' 
   AND DATE(me.data_movimentacao) BETWEEN p_data_inicio AND p_data_fim
   ```

3. **Vendas Durante o Período:**
   ```sql
   SELECT SUM(ic.quantidade) 
   FROM itens_comanda ic 
   JOIN comandas c ON ic.comanda_id = c.id 
   WHERE ic.produto_id = p.id 
   AND c.status = 'fechada'
   AND DATE(c.data_venda) BETWEEN p_data_inicio AND p_data_fim
   ```

4. **Faturamento do Período:**
   ```sql
   SELECT SUM(ic.subtotal) 
   FROM itens_comanda ic 
   JOIN comandas c ON ic.comanda_id = c.id 
   WHERE ic.produto_id = p.id 
   AND c.status = 'fechada'
   AND DATE(c.data_venda) BETWEEN p_data_inicio AND p_data_fim
   ```

## 🎨 Interface do Usuário

### 📊 Dashboard Principal

**Localização:** `modules/relatorios/index.php`

**Componentes:**
1. **Cards de Métricas:**
   - Vendas da semana
   - Faturamento da semana
   - Alertas de estoque
   - Perdas identificadas (com contador dinâmico)

2. **Filtros de Relatório:**
   - Data início/fim
   - Tipo de relatório (incluindo "Análise de Estoque e Perdas")
   - Botões de ação (Gerar, Exportar, Limpar Duplicadas)

3. **Área de Resultados:**
   - Tabela dinâmica com resultados
   - Gráficos (vendas, categorias, mensal)

### 🔍 Relatório de Análise de Estoque

**Características:**
- **Header com Período:** Mostra claramente o período analisado
- **Cards de Totais:** Resumo executivo das perdas
- **Tabela Detalhada:** Análise produto por produto
- **Código de Cores:** Verde (sem perdas) / Vermelho (com perdas)
- **Ícones Visuais:** Status de cada produto
- **Responsividade:** Adaptado para mobile

**Colunas da Tabela:**
1. Produto (com ícone de status)
2. Categoria (badge colorido)
3. Estoque Inicial
4. + Entradas (verde)
5. - Vendidos (vermelho)
6. = Estoque Teórico (azul)
7. Estoque Real
8. Perdas Qtd (destaque se > 0)
9. Perdas R$ (destaque se > 0)
10. Faturamento

### 📋 Modal de Histórico de Perdas

**Funcionalidades:**
- **Filtros de Data:** Mês/ano ou período específico
- **Tabela Completa:** Todas as perdas registradas
- **Status de Visualização:** Botão para marcar como visualizada
- **Exportação:** Download em Excel
- **Totais:** Resumo na parte inferior

## 🎛️ Funcionalidades Avançadas

### 🔄 Detecção Automática de Perdas

O sistema detecta perdas automaticamente através da view `view_alertas_perda_estoque`:

```sql
CREATE VIEW view_alertas_perda_estoque AS
SELECT 
    p.id,
    p.nome,
    cat.nome as categoria,
    p.estoque_atual,
    p.estoque_minimo,
    (SELECT COALESCE(SUM(me.quantidade), 0) 
     FROM movimentacoes_estoque me 
     WHERE me.produto_id = p.id AND me.tipo = 'entrada') as total_entradas,
    (SELECT COALESCE(SUM(ic.quantidade), 0) 
     FROM itens_comanda ic 
     JOIN comandas c ON ic.comanda_id = c.id 
     WHERE ic.produto_id = p.id AND c.status = 'fechada') as total_vendido,
    ((SELECT COALESCE(SUM(quantidade), 0) FROM movimentacoes_estoque WHERE produto_id = p.id AND tipo = 'entrada') - 
     (SELECT COALESCE(SUM(ic.quantidade), 0) FROM itens_comanda ic JOIN comandas c ON ic.comanda_id = c.id WHERE ic.produto_id = p.id AND c.status = 'fechada') - 
     p.estoque_atual) as diferenca_estoque
FROM produtos p
JOIN categorias cat ON p.categoria_id = cat.id
WHERE p.ativo = 1;
```

### 🎯 Filtros Avançados

**Filtros Disponíveis:**
1. **Por Categoria:** Filtrar produtos de categoria específica
2. **Por Valor Mínimo:** Mostrar apenas perdas acima de um valor
3. **Por Tipo:** Todos / Apenas com perdas / Apenas sem perdas
4. **Por Período:** Data início e fim personalizáveis

### 📱 Responsividade

**Breakpoints:**
- **Desktop (>1200px):** Layout completo com todas as colunas
- **Tablet (768px-1200px):** Fonte reduzida, colunas compactadas
- **Mobile (<768px):** Layout empilhado, botões reorganizados

## 🔧 Configuração e Instalação

### 1. **Criação da Tabela**

Execute o script SQL ou use o endpoint automático:
```php
GET api/criar_tabela_perdas.php
```

### 2. **Permissões de Usuário**

Certifique-se de que o usuário do banco tem permissões para:
- CREATE TABLE
- INSERT, UPDATE, DELETE
- EXECUTE (para stored procedures)

### 3. **Configuração do PHP**

Requisitos mínimos:
- PHP 7.4+
- PDO MySQL
- JSON extension

## 🚀 Fluxo de Uso Completo

### 📋 Cenário: Análise Mensal de Perdas

1. **Acesso ao Sistema:**
   - Login no sistema
   - Navegar para "Relatórios"

2. **Configuração do Relatório:**
   - Selecionar "Análise de Estoque e Perdas"
   - Definir período (ex: 01/11/2024 a 30/11/2024)
   - Aplicar filtros se necessário

3. **Geração do Relatório:**
   - Clique em "Gerar Relatório"
   - Sistema executa stored procedure
   - Exibe resultados em tabela formatada

4. **Análise dos Resultados:**
   - Verificar cards de totais
   - Identificar produtos com perdas (linhas vermelhas)
   - Analisar valores e quantidades

5. **Gestão de Alertas:**
   - Verificar alertas no dashboard
   - Marcar perdas como visualizadas
   - Acessar histórico completo

6. **Exportação:**
   - Exportar relatório para Excel
   - Imprimir se necessário

## 🔍 Casos de Uso Específicos

### 📊 Caso 1: Auditoria de Estoque

**Objetivo:** Verificar divergências no estoque do mês

**Passos:**
1. Gerar relatório do mês completo
2. Filtrar apenas produtos com perdas
3. Analisar produtos com maior valor de perda
4. Investigar causas (furto, deterioração, erro de contagem)
5. Marcar perdas como visualizadas após investigação

### 🎯 Caso 2: Controle Diário

**Objetivo:** Monitoramento contínuo de perdas

**Passos:**
1. Verificar alertas no dashboard diariamente
2. Investigar perdas identificadas
3. Marcar como visualizadas após verificação
4. Gerar relatório semanal para análise de tendências

### 📈 Caso 3: Análise de Tendências

**Objetivo:** Identificar padrões de perdas

**Passos:**
1. Gerar relatórios de múltiplos períodos
2. Comparar perdas por categoria
3. Identificar produtos com perdas recorrentes
4. Implementar ações corretivas

## ⚠️ Troubleshooting

### 🐛 Problemas Comuns

1. **Tabela não existe:**
   - Executar `api/criar_tabela_perdas.php`
   - Verificar permissões do usuário do banco

2. **Stored procedure não encontrada:**
   - Importar arquivo SQL completo
   - Verificar se o banco está atualizado

3. **Perdas não aparecem:**
   - Verificar se há movimentações de estoque registradas
   - Confirmar se há vendas no período
   - Verificar se produtos estão ativos

4. **Erro de permissão:**
   - Verificar login do usuário
   - Confirmar perfil de acesso (admin/estoque)

### 🔧 Logs e Debug

**Ativar debug no PHP:**
```php
error_reporting(E_ALL);
ini_set('display_errors', 1);
```

**Verificar logs do MySQL:**
```sql
SHOW VARIABLES LIKE 'log_error';
```

## 📊 Métricas e KPIs

### 📈 Indicadores Principais

1. **Taxa de Perdas:** (Valor Perdas / Faturamento) × 100
2. **Produtos Afetados:** Número de produtos com perdas
3. **Valor Médio por Perda:** Valor Total Perdas / Número de Perdas
4. **Frequência de Perdas:** Perdas por período de tempo

### 🎯 Metas Sugeridas

- **Taxa de Perdas:** < 2% do faturamento mensal
- **Tempo de Resolução:** Perdas visualizadas em até 24h
- **Produtos Críticos:** Zero perdas em produtos de alto valor

## 🔮 Roadmap e Melhorias Futuras

### 🚀 Próximas Funcionalidades

1. **Alertas por Email:** Notificações automáticas de perdas
2. **Dashboard Executivo:** Gráficos de tendências
3. **Integração com Câmeras:** Análise de imagens do estoque
4. **Machine Learning:** Predição de perdas
5. **App Mobile:** Controle via smartphone

### 🎨 Melhorias de UX

1. **Filtros Salvos:** Salvar configurações de filtros
2. **Relatórios Agendados:** Geração automática
3. **Comparação de Períodos:** Análise comparativa
4. **Exportação Avançada:** PDF com gráficos

## 📞 Suporte e Contato

Para dúvidas, problemas ou sugestões:

- **Documentação:** Consulte os arquivos .md na pasta `documentações/`
- **Logs:** Verifique logs do sistema em caso de erro
- **Backup:** Sempre faça backup antes de modificações

---

**📝 Última Atualização:** Novembro 2024  
**🔧 Versão do Sistema:** 2.0  
**👨‍💻 Desenvolvido por:** Equipe Gestão Inteli Jr.

---

*Este documento serve como guia completo para entendimento, uso e manutenção do Sistema de Relatório de Análise e Perdas de Estoque. Mantenha-o atualizado conforme novas funcionalidades são implementadas.*