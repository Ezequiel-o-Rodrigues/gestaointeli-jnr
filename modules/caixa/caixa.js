// Variáveis globais
let comandaAtualId = window.appConfig ? window.appConfig.comandaAtualId : null;
let itensComanda = [];
const API_BASE = '../../api/';

// Função auxiliar para API
async function apiCall(endpoint, options = {}) {
    const url = API_BASE + endpoint;
    console.log('📡 Chamando API:', url);
    
    try {
        const response = await fetch(url, {
            headers: {
                'Content-Type': 'application/json',
                ...(options.headers || {})
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

// Função para criar nova comanda
async function novaComanda() {
    console.log('🔄 Tentando criar nova comanda...');
    
    try {
        const result = await apiCall('nova_comanda.php', {
            method: 'POST',
            body: JSON.stringify({})
        });
        
        console.log('📋 Resultado da criação:', result);
        
        if (result.success) {
            comandaAtualId = result.comanda_id;
            itensComanda = [];
            atualizarInterfaceComanda();
            mostrarNotificacao('Nova comanda #' + comandaAtualId + ' criada!', 'success');
        } else {
            mostrarNotificacao('Erro ao criar comanda: ' + (result.message || 'Erro desconhecido'), 'error');
        }
    } catch (error) {
        console.error('❌ Erro detalhado na criação:', error);
        mostrarNotificacao('Erro ao criar comanda. Verifique o console.', 'error');
    }
}

async function adicionarProduto(produtoId, produtoNome, produtoPreco) {
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
            await carregarItensComanda();
            mostrarNotificacao(produtoNome + ' adicionado!', 'success');
        }
    } catch (error) {
        console.error('Erro ao adicionar produto:', error);
    }
}

// Função para remover item da comanda
async function removerItem(itemId, produtoNome) {
    if (!comandaAtualId || !itemId) return;

    try {
        const result = await apiCall('remover_item.php', {
            method: 'POST',
            body: JSON.stringify({
                comanda_id: comandaAtualId,
                item_id: itemId
            })
        });
        
        if (result.success) {
            await carregarItensComanda();
            mostrarNotificacao(produtoNome + ' removido!', 'success');
        }
    } catch (error) {
        console.error('Erro ao remover item:', error);
        mostrarNotificacao('Erro ao remover item', 'error');
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
    console.log('🔄 Atualizando interface da comanda...');
    console.log('Comanda ID:', comandaAtualId);
    console.log('Itens comanda:', itensComanda);

    // BUSCAR ELEMENTOS COM FALLBACKS
    const comandaElement = document.getElementById('numero-comanda');
    const itensElement = document.getElementById('itens-comanda');
    const btnFinalizar = document.getElementById('btn-finalizar');
    const totalElement = document.getElementById('total-comanda');

    console.log('Elementos encontrados:', {
        comandaElement: !!comandaElement,
        itensElement: !!itensElement,
        btnFinalizar: !!btnFinalizar,
        totalElement: !!totalElement
    });

    // VERIFICAR SE ELEMENTOS EXISTEM ANTES DE USAR
    if (!comandaElement || !itensElement || !btnFinalizar || !totalElement) {
        console.error('❌ Elementos da interface não encontrados. Tentando novamente em 100ms...');
        setTimeout(atualizarInterfaceComanda, 100);
        return;
    }

    if (comandaAtualId) {
        console.log('✅ Atualizando comanda existente:', comandaAtualId);
        comandaElement.textContent = `#${comandaAtualId}`;
        
        if (itensComanda.length > 0) {
            console.log('📦 Itens para exibir:', itensComanda.length);
            const subtotal = itensComanda.reduce((sum, item) => sum + parseFloat(item.subtotal || 0), 0);
            
            itensElement.innerHTML = itensComanda.map(item => `
                <div class="item-comanda-horizontal" data-item-id="${item.id}">
                    <span class="item-nome">${escapeHtml(item.nome)}</span>
                    <span class="item-quantidade">${item.quantidade}x</span>
                    <span class="item-preco">R$ ${parseFloat(item.subtotal || 0).toFixed(2)}</span>
                    <button class="btn-remover" onclick="removerItem(${item.id}, '${escapeHtml(item.nome).replace(/'/g, "\\'")}')" title="Remover item">
                        ✕
                    </button>
                </div>
            `).join('');
            
            totalElement.textContent = 'R$ ' + subtotal.toFixed(2);
            btnFinalizar.disabled = false;
            console.log('💰 Total calculado:', subtotal);
        } else {
            console.log('📭 Comanda vazia');
            itensElement.innerHTML = '<div class="empty-comanda">Nenhum item adicionado</div>';
            totalElement.textContent = 'R$ 0,00';
            btnFinalizar.disabled = true;
        }
    } else {
        console.log('🚫 Nenhuma comanda ativa');
        comandaElement.textContent = '--';
        itensElement.innerHTML = '<div class="empty-comanda">Nenhuma comanda</div>';
        totalElement.textContent = 'R$ 0,00';
        btnFinalizar.disabled = true;
    }
    
    console.log('✅ Interface atualizada com sucesso');
}

// Função para finalizar comanda
async function finalizarComanda() {
    if (!comandaAtualId || itensComanda.length === 0) {
        mostrarNotificacao('Comanda vazia ou não criada!', 'warning');
        return;
    }

    const total = document.getElementById('total-comanda').textContent;
    if (confirm(`Finalizar comanda #${comandaAtualId}?\nTotal: ${total}`)) {
        try {
            const result = await apiCall('finalizar_comanda.php', {
                method: 'POST',
                body: JSON.stringify({ comanda_id: comandaAtualId })
            });
            
            if (result.success) {
                mostrarNotificacao('Comanda #' + comandaAtualId + ' finalizada!', 'success');
                comandaAtualId = null;
                itensComanda = [];
                atualizarInterfaceComanda();
            }
        } catch (error) {
            mostrarNotificacao('Erro ao finalizar comanda', 'error');
        }
    }
}

function filtrarProdutos() {
    const searchTerm = document.getElementById('search-produto').value.toLowerCase();
    const categoriaFiltro = document.getElementById('filtro-categoria').value;
    const categorias = document.querySelectorAll('.categoria-produtos');
    let totalVisiveis = 0;
    
    categorias.forEach(categoria => {
        const categoriaId = categoria.getAttribute('data-categoria');
        const produtos = categoria.querySelectorAll('.produto-card');
        let produtosVisiveis = 0;
        
        const mostrarCategoria = !categoriaFiltro || categoriaId === categoriaFiltro;
        
        produtos.forEach(produto => {
            const produtoNome = produto.getAttribute('data-produto-nome').toLowerCase();
            const matchesSearch = !searchTerm || produtoNome.includes(searchTerm);
            const matchesCategoria = mostrarCategoria;
            const deveMostrar = matchesSearch && matchesCategoria;
            
            produto.style.display = deveMostrar ? 'flex' : 'none';
            if (deveMostrar) {
                produtosVisiveis++;
                totalVisiveis++;
            }
        });
        
        categoria.style.display = produtosVisiveis > 0 && mostrarCategoria ? 'block' : 'none';
        
        const contador = categoria.querySelector('.contador-categoria');
        if (contador) contador.textContent = `(${produtosVisiveis})`;
    });
    
    document.getElementById('contador-produtos').textContent = `${totalVisiveis} produtos`;
    
    const container = document.getElementById('produtos-container');
    let noResults = container.querySelector('.no-results');
    
    if (totalVisiveis === 0 && !noResults) {
        noResults = document.createElement('div');
        noResults.className = 'no-results';
        noResults.innerHTML = `
            <div style="text-align: center; padding: 40px; color: #7f8c8d;">
                <div style="font-size: 3rem; margin-bottom: 10px;">🔍</div>
                <h3>Nenhum produto encontrado</h3>
            </div>
        `;
        container.appendChild(noResults);
    } else if (totalVisiveis > 0 && noResults) {
        noResults.remove();
    }
}

function limparFiltros() {
    document.getElementById('search-produto').value = '';
    document.getElementById('filtro-categoria').value = '';
    filtrarProdutos();
}

function mostrarNotificacao(mensagem, tipo = 'info') {
    const cores = { success: '#27ae60', error: '#e74c3c', warning: '#f39c12', info: '#3498db' };
    
    const notificacao = document.createElement('div');
    notificacao.style.cssText = `
        position: fixed;
        top: 20px;
        right: 20px;
        padding: 12px 20px;
        background: ${cores[tipo] || '#3498db'};
        color: white;
        border-radius: 5px;
        z-index: 1000;
        font-weight: bold;
    `;
    notificacao.textContent = mensagem;
    
    document.body.appendChild(notificacao);
    
    setTimeout(() => notificacao.remove(), 3000);
}

// Função para escapar HTML
function escapeHtml(text) {
    if (!text) return '';
    const div = document.createElement('div');
    div.textContent = text;
    return div.innerHTML;
}

// Função para criar nova comanda com fallback
async function novaComanda() {
    console.log('🔄 Tentando criar nova comanda...');
    
    try {
        const result = await apiCall('nova_comanda.php', {
            method: 'POST',
            body: JSON.stringify({})
        });
        
        console.log('📋 Resultado da criação:', result);
        
        if (result.success) {
            comandaAtualId = result.comanda_id;
            itensComanda = [];
            atualizarInterfaceComanda();
            mostrarNotificacao('Nova comanda #' + comandaAtualId + ' criada!', 'success');
        } else {
            mostrarNotificacao('Erro ao criar comanda: ' + (result.message || 'Erro desconhecido'), 'error');
        }
    } catch (error) {
        console.error('❌ Erro detalhado na criação:', error);
        
        // FALLBACK: criar comanda localmente para teste
        const novaComandaId = Math.floor(Math.random() * 900) + 100;
        comandaAtualId = novaComandaId;
        itensComanda = [];
        atualizarInterfaceComanda();
        mostrarNotificacao('Comanda #' + novaComandaId + ' criada (modo teste)', 'warning');
    }
}

// Função auxiliar para API com melhor tratamento
async function apiCall(endpoint, options = {}) {
    const url = API_BASE + endpoint;
    console.log('📡 Chamando API:', url);
    
    try {
        const response = await fetch(url, {
            headers: {
                'Content-Type': 'application/json',
                ...(options.headers || {})
            },
            ...options
        });
        
        console.log('📦 Resposta HTTP:', response.status, response.statusText);
        
        // Verificar se a resposta é JSON válido
        const text = await response.text();
        console.log('📄 Resposta bruta:', text.substring(0, 200));
        
        if (!response.ok) {
            throw new Error(`Erro HTTP: ${response.status} - ${response.statusText}`);
        }
        
        // Tentar parsear como JSON
        let data;
        try {
            data = JSON.parse(text);
        } catch (parseError) {
            console.error('❌ Erro ao parsear JSON:', parseError);
            throw new Error('Resposta da API não é JSON válido: ' + text.substring(0, 100));
        }
        
        console.log('✅ Resposta API:', data);
        return data;
        
    } catch (error) {
        console.error('❌ Erro na API:', error);
        mostrarNotificacao('Erro de conexão: ' + error.message, 'error');
        throw error;
    }
}

// Inicialização
document.addEventListener('DOMContentLoaded', function() {
    console.log('✅ DOM Carregado - Sistema de caixa pronto!');
    
    // Aguardar um pouco para garantir que todos os elementos estejam carregados
    setTimeout(() => {
        // Adicionar eventos
        const searchInput = document.getElementById('search-produto');
        if (searchInput) {
            searchInput.addEventListener('keypress', function(e) {
                if (e.key === 'Enter') filtrarProdutos();
            });
        }
        
        // Inicializar filtros
        filtrarProdutos();
        
        // Se já existe uma comanda, carregar os itens
        if (comandaAtualId) {
            console.log('🔄 Comanda existente encontrada:', comandaAtualId);
            carregarItensComanda();
        } else {
            console.log('ℹ️ Nenhuma comanda aberta');
            // Forçar atualização da interface
            atualizarInterfaceComanda();
        }
    }, 100);
});

// Funções globais
window.novaComanda = novaComanda;
window.adicionarProduto = adicionarProduto;
window.removerItem = removerItem;
window.finalizarComanda = finalizarComanda;
window.filtrarProdutos = filtrarProdutos;
window.limparFiltros = limparFiltros;