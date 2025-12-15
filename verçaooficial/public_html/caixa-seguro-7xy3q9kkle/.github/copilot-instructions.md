# GestãoInteli JNR - Instruções para Agentes de IA

## 📋 Visão Geral do Projeto

Sistema de gerenciamento de restaurante (POS - Point of Sale) em PHP/MySQL com arquitetura modular. Componentes principais:
- **Caixa** (`modules/caixa/`): Gestão de comandas e vendas
- **Estoque** (`modules/estoque/`): Controle de produtos e movimentações
- **Relatórios** (`modules/relatorios/`): Análise de vendas e perdas
- **Admin** (`modules/admin/`): Cadastro de produtos/categorias/garçons

## 🏗️ Arquitetura e Estrutura de Caminhos

### Convenção de Imports (CRÍTICO)
**Problema histórico**: Múltiplos estilos de import coexistem. **Padrão correto**:

```php
// ✅ CORRETO - usar PathConfig para imports sistemáticos
require_once __DIR__ . '/../config/paths.php';
require_once PathConfig::config('database.php');

// ❌ EVITAR - caminhos hardcoded quebram com relocação
require_once '../config/database.php';
```

**Arquivo de referência**: `config/paths.php` define `PathConfig::config()`, `PathConfig::api()`, `PathConfig::modules()`

### Estrutura de Diretórios
```
/config          → database.php (PDO wrapper), paths.php (PathConfig class)
/api             → Endpoints JSON (29 arquivos) - sem lógica de UI
/modules/*/      → Interfaces HTML/CSS/JS isoladas por feature
/includes/       → Utilitários reutilizáveis (formatação, queries genéricas)
/js              → path-config.js (cliente-side path resolution)
```

## 🔌 Padrões de Comunicação PHP-JS

### Backend → Frontend (JSON APIs)
Todos os endpoints `/api/*.php` retornam JSON estruturado:

```php
// ✅ Padrão: sucesso com dados
echo json_encode(['success' => true, 'comanda_id' => 123, 'message' => '...']);

// ✅ Padrão: erro com contexto
http_response_code(500);
echo json_encode(['success' => false, 'message' => 'Descrição do erro']);
```

**Endpoints críticos**:
- `nova_comanda.php` - POST: cria comanda vazia
- `adicionar_item.php` - POST: insere produto em comanda (valida estoque antes)
- `finalizar_comanda.php` - POST: transação: calcula total + baixa estoque + registra movimentação
- `itens_comanda.php` - GET: lista itens com JOIN produtos
- `verificar_estoque.php` - POST: valida stock antes de finalizar

### Frontend → Backend (Fetch + Transações)
Classe JavaScript `CaixaSystem` (`modules/caixa/caixa.js`) gerencia fluxo de comanda:

```javascript
// Padrão: await + .json() + check success
const response = await fetch(url, { method: 'POST', body: JSON.stringify(data) });
const result = await response.json();
if (result.success) { /* atualizar UI */ } else { throw Error(result.message); }
```

**Proteção contra dupla inicialização**: `window.CaixaSystemAlreadyLoaded` flag + verificação em DOMContentLoaded

## 🗄️ Modelo de Dados (tabelas principais)

```sql
comandas          → id, status (aberta|fechada), valor_total, taxa_gorjeta, data_venda, numero_mesa
itens_comanda     → id, comanda_id, produto_id, quantidade, subtotal
produtos          → id, nome, preco, estoque_atual, estoque_minimo, categoria_id, ativo
categorias        → id, nome
garcons           → id, nome, codigo, ativo
movimentacoes_estoque → tipo (entrada|saida), produto_id, quantidade, fornecedor_id, data
```

**Fluxo crítico**: Comanda criada → itens adicionados (verifica estoque) → finalização (transação: atualiza `productos.estoque_atual`, insere `movimentacoes_estoque`)

## 🚨 Padrões de Tratamento de Erros

### PHP (Backend)
```php
try {
    $database = new Database();
    $db = $database->getConnection(); // retorna null se falhar
    // logica...
} catch (Exception $e) {
    http_response_code(500);
    echo json_encode(['success' => false, 'message' => $e->getMessage()]);
}
```

### JavaScript (Frontend)
```javascript
try {
    await this.carregarProdutos();
    this.configurarEventos(); // só inicia UI se dados carregados
} catch (error) {
    console.error('Erro:', error);
    this.mostrarToast('Erro ao carregar', 'error'); // notificação ao usuário
} finally {
    this.mostrarLoadingProdutos(false); // cleanup
}
```

## 🔑 Convenções Críticas

### Cache Busting de Assets
Para forçar recarregamento após atualizações JS:
```php
// modules/caixa/index.php (linha 6-7)
$caixa_js_version = filemtime(__DIR__ . '/caixa.js');
// <script src="...caixa.js?v=<?php echo $caixa_js_version; ?>"></script>
```

### Proteção contra Dupla Inicialização em JavaScript
```javascript
// NO INÍCIO de caixa.js
if (window.CaixaSystemAlreadyLoaded) {
    console.warn('Já carregado. Ignorando...');
} else {
    window.CaixaSystemAlreadyLoaded = true;
    class CaixaSystem { ... }
    // listener DOMContentLoaded sempre checa: if (!window.caixaSystem)
}
```

### Validações em Dois Níveis
1. **Cliente** (JavaScript): feedback visual imediato, UX
2. **Servidor** (PHP): validações obrigatórias (estoque, permissões, integridade)

## 🧪 Debugging Rápido

**Verificar conexão BD**: `/api/teste_conexao.php` (listagem de tabelas/campos)
**Listar arquivos**: `/api/find_database.php` (navega diretório)
**Debug API**: `/api/debug.php` (valida caminhos e requires)

## 📝 Convenções Nomeação

- **Variáveis PHP**: snake_case (`$comanda_id`, `$estoque_atual`)
- **Classes JavaScript**: PascalCase (`CaixaSystem`, `Relatorios`)
- **Métodos**: camelCase (`configurarEventos`, `adicionarItem`)
- **URLs base**: `/gestaointeli-jnr/` (hardcoded em PathConfig, revisitar se deployment muda)

## ✅ Checklist para Novas Features

1. **Novo endpoint API?** → Criar em `/api/*.php` com `PathConfig::config('database.php')` + JSON response
2. **Novo módulo UI?** → Criar em `/modules/novo_modulo/{index.php, novo_modulo.js, criando_modulo.js}`
3. **Novo table?** → Atualizar schema SQL (`sistema_restaurante.sql`) + migrations (se houver)
4. **Integração com estoque?** → `finalizar_comanda.php` já valida; revisar `movimentacoes_estoque` INSERT
5. **Cache issues?** → Validar version query param em scripts/links (linhas 6-7 modules/*/index.php)

## 🔗 Referências Rápidas

- **Path resolution JS**: `js/path-config.js` → `PathConfig.api('endpoint.php')`
- **Path resolution PHP**: `config/paths.php` → `PathConfig::config('file.php')`
- **Exemplo comanda completo**: `modules/caixa/caixa.js` (linhas 150-200)
- **Transação de finalização**: `api/finalizar_comanda.php` (linhas 30-80)
