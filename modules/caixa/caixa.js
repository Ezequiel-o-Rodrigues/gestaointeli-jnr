// Debug inicial
console.log('✅ caixa.js carregado com sucesso');

// Variáveis globais
let comandaAtualId = null;
let categoriaAtual = null;
let itensComanda = [];

// URL base para APIs - CORRIGIDA
const API_BASE = '../../api/'; // Caminho RELATIVO correto

console.log('🔄 URL Base da API:', API_BASE);

// Função auxiliar para fazer requisições API
async function apiCall(endpoint, options = {}) {
    const url = API_BASE + endpoint;
    console.log('📡 Chamando API:', url, options);
    
    try {
        const response = await fetch(url, {
            headers: {
                'Content-Type': 'application/json',
                ...options.headers
            },
            ...options
        });
        
        console.log('📦 Resposta HTTP:', response.status, response.statusText);
        
        if (!response.ok) {
            throw new Error(`Erro HTTP: ${response.status} - ${response.statusText}`);
        }
        
        const data = await response.json();
        console.log('✅ Resposta API:', data);
        return data;
        
    } catch (error) {
        console.error('❌ Erro na API:', error);
        mostrarNotificacao('Erro de conexão: ' + error.message, 'error');
        throw error;
    }
}

// Funções principais
async function novaComanda() {
    console.log('🔄 Criando nova comanda...');
    
    try {
        const result = await apiCall('nova_comanda.php', {
            method: 'POST',
            body: JSON.stringify({}) // Enviar objeto vazio
        });
        
        if (result.success) {
            comandaAtualId = result.comanda_id;
            document.getElementById('numero-comanda').textContent = 'Comanda: #' + comandaAtualId;
            document.getElementById('itens-comanda').innerHTML = '<p class="empty-message">Nenhum item adicionado</p>';
            document.getElementById('subtotal').textContent = 'R$ 0,00';
            document.getElementById('total').textContent = 'R$ 0,00';
            document.getElementById('btn-finalizar').disabled = true;
            
            mostrarNotificacao('Nova comanda #' + comandaAtualId + ' criada!', 'success');
            
            // Verificar no banco
            console.log('🔍 Verifique no banco: SELECT * FROM comandas ORDER BY id DESC LIMIT 1;');
        } else {
            mostrarNotificacao('Erro ao criar comanda: ' + result.message, 'error');
        }
    } catch (error) {
        console.error('❌ Erro detalhado:', error);
        mostrarNotificacao('Erro ao criar comanda. Verifique o console.', 'error');
    }
}

async function carregarProdutos(categoriaId, categoriaNome) {
    console.log('🔄 Carregando produtos da categoria:', categoriaId, categoriaNome);
    categoriaAtual = categoriaId;
    
    try {
        const produtos = await apiCall(`produtos_categoria.php?categoria_id=${categoriaId}`);
        
        // Mostrar seção de produtos
        document.getElementById('categorias-section').style.display = 'none';
        document.getElementById('produtos-section').style.display = 'block';
        document.getElementById('titulo-produtos').textContent = 'Produtos: ' + categoriaNome;
        
        const grid = document.getElementById('produtos-grid');
        
        if (!produtos || produtos.length === 0) {
            grid.innerHTML = '<p>Nenhum produto encontrado nesta categoria</p>';
            return;
        }
        
        grid.innerHTML = produtos.map(produto => `
            <div class="produto-card" onclick="adicionarProduto(${produto.id}, '${escapeHtml(produto.nome)}', ${produto.preco})">
                <h4>${escapeHtml(produto.nome)}</h4>
                <div class="preco">R$ ${parseFloat(produto.preco).toFixed(2)}</div>
                <small>Estoque: ${produto.estoque_atual}</small>
            </div>
        `).join('');
        
    } catch (error) {
        console.error('❌ Erro ao carregar produtos:', error);
    }
}

function voltarCategorias() {
    document.getElementById('produtos-section').style.display = 'none';
    document.getElementById('categorias-section').style.display = 'block';
}

async function adicionarProduto(produtoId, produtoNome, produtoPreco) {
    console.log('➕ Adicionando produto:', produtoId, produtoNome, produtoPreco);
    
    if (!comandaAtualId) {
        mostrarNotificacao('Crie uma comanda primeiro!', 'warning');
        return;
    }

    try {
        const result = await apiCall('adicionar_item.php', {
            method: 'POST',
            body: JSON.stringify({
                comanda_id: comandaAtualId,
                produto_id: produtoId,
                quantidade: 1
            })
        });
        
        if (result.success) {
            // Recarregar itens da comanda
            await carregarItensComanda();
            mostrarNotificacao(produtoNome + ' adicionado à comanda!', 'success');
            
            // Verificar no banco
            console.log('🔍 Verifique no banco: SELECT * FROM itens_comanda ORDER BY id DESC LIMIT 1;');
        } else {
            mostrarNotificacao('Erro ao adicionar produto: ' + result.message, 'error');
        }
    } catch (error) {
        console.error('❌ Erro ao adicionar produto:', error);
    }
}

async function carregarItensComanda() {
    if (!comandaAtualId) return;

    try {
        const data = await apiCall(`itens_comanda.php?comanda_id=${comandaAtualId}`);
        itensComanda = data.itens || [];
        
        atualizarInterfaceComanda();
    } catch (error) {
        console.error('Erro ao carregar itens:', error);
    }
}

function atualizarInterfaceComanda() {
    const comandaElement = document.getElementById('numero-comanda');
    const itensElement = document.getElementById('itens-comanda');
    const btnFinalizar = document.getElementById('btn-finalizar');

    if (comandaAtualId) {
        comandaElement.textContent = `Comanda: #${comandaAtualId}`;
        
        if (itensComanda.length > 0) {
            itensElement.innerHTML = itensComanda.map(item => `
                <div class="item-comanda">
                    <span>${escapeHtml(item.nome)} x${item.quantidade}</span>
                    <span>R$ ${parseFloat(item.subtotal).toFixed(2)}</span>
                </div>
            `).join('');
            
            btnFinalizar.disabled = false;
            
            // Calcular totais
            const subtotal = itensComanda.reduce((sum, item) => sum + parseFloat(item.subtotal), 0);
            document.getElementById('subtotal').textContent = 'R$ ' + subtotal.toFixed(2);
            document.getElementById('total').textContent = 'R$ ' + subtotal.toFixed(2);
        } else {
            itensElement.innerHTML = '<p class="empty-message">Nenhum item adicionado</p>';
            document.getElementById('subtotal').textContent = 'R$ 0,00';
            document.getElementById('total').textContent = 'R$ 0,00';
            btnFinalizar.disabled = true;
        }
    } else {
        comandaElement.textContent = 'Comanda: --';
        itensElement.innerHTML = '<p class="empty-message">Nenhuma comanda aberta</p>';
        document.getElementById('subtotal').textContent = 'R$ 0,00';
        document.getElementById('total').textContent = 'R$ 0,00';
        btnFinalizar.disabled = true;
    }
}

async function finalizarComanda() {
    if (!comandaAtualId) {
        mostrarNotificacao('Nenhuma comanda aberta!', 'error');
        return;
    }

    if (itensComanda.length === 0) {
        mostrarNotificacao('Adicione itens à comanda primeiro!', 'warning');
        return;
    }

    if (confirm('Deseja finalizar a comanda #' + comandaAtualId + '?')) {
        try {
            const result = await apiCall('finalizar_comanda.php', {
                method: 'POST',
                body: JSON.stringify({
                    comanda_id: comandaAtualId
                })
            });
            
            if (result.success) {
                mostrarNotificacao('Comanda #' + comandaAtualId + ' finalizada com sucesso!', 'success');
                
                // Resetar comanda
                comandaAtualId = null;
                itensComanda = [];
                atualizarInterfaceComanda();
                
                console.log('🔍 Verifique no banco: SELECT * FROM comandas WHERE id = ' + comandaAtualId + ';');
            } else {
                mostrarNotificacao('Erro ao finalizar comanda: ' + result.message, 'error');
            }
        } catch (error) {
            mostrarNotificacao('Erro ao finalizar comanda', 'error');
        }
    }
}

// Funções auxiliares
function escapeHtml(text) {
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

function mostrarNotificacao(mensagem, tipo = 'info') {
    const cores = {
        success: '#27ae60',
        error: '#e74c3c',
        warning: '#f39c12',
        info: '#3498db'
    };
    
    const notificacao = document.createElement('div');
    notificacao.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        padding: 15px 20px;
        background: ${cores[tipo] || '#3498db'};
        color: white;
        border-radius: 5px;
        z-index: 1000;
        font-weight: bold;
        box-shadow: 0 2px 10px rgba(0,0,0,0.2);
    `;
    notificacao.textContent = mensagem;
    
    document.body.appendChild(notificacao);
    
    setTimeout(() => {
        if (document.body.contains(notificacao)) {
            document.body.removeChild(notificacao);
        }
    }, 3000);
}

// Inicialização quando a página carregar
document.addEventListener('DOMContentLoaded', function() {
    console.log('✅ DOM Carregado - Sistema de caixa pronto!');
    
    // Carregar comanda aberta se existir
    carregarComandaAberta();
});

async function carregarComandaAberta() {
    console.log('🔄 Buscando comanda aberta...');
    try {
        const result = await apiCall('comanda_aberta.php');
        
        if (result.success && result.comanda) {
            comandaAtualId = result.comanda.id;
            console.log('ℹ️ Comanda aberta encontrada:', comandaAtualId);
            await carregarItensComanda();
        } else {
            console.log('ℹ️ Nenhuma comanda aberta encontrada');
        }
    } catch (error) {
        console.error('❌ Erro ao carregar comanda:', error);
    }
}

// Tornar funções globais
window.novaComanda = novaComanda;
window.carregarProdutos = carregarProdutos;
window.voltarCategorias = voltarCategorias;
window.adicionarProduto = adicionarProduto;
window.finalizarComanda = finalizarComanda;

console.log('✅ Funções globais definidas');