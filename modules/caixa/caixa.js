// modules/caixa/caixa.js
class CaixaSystem {
    constructor() {
        this.comandaAtual = null;
        this.itensComanda = [];
        this.produtos = [];
        this.carregando = false;
        
        this.init();
    }
    
    async init() {
        await this.carregarProdutos();
        this.configurarEventos();
        this.mostrarToast('Sistema de caixa carregado', 'success');
    }
    
    configurarEventos() {
        // Nova comanda
        document.getElementById('btn-nova-comanda').addEventListener('click', () => {
            this.novaComanda();
        });
        
        // Finalizar venda
        document.getElementById('btn-finalizar').addEventListener('click', () => {
            this.finalizarComanda();
        });
        
        // Cancelar
        document.getElementById('btn-cancelar').addEventListener('click', () => {
            this.cancelarComanda();
        });
        
        // Busca de produtos
        const buscaInput = document.getElementById('busca-produto');
        if (buscaInput) {
            buscaInput.addEventListener('input', (e) => {
                this.filtrarProdutos(e.target.value);
            });
        }
        
        // Filtro por categoria
        document.querySelectorAll('.categoria-btn').forEach(btn => {
            btn.addEventListener('click', (e) => {
                this.filtrarPorCategoria(e.target.dataset.categoria);
            });
        });
        
        // Foco automático na busca
        if (buscaInput) {
            buscaInput.focus();
        }
    }
    
    async carregarProdutos() {
        try {
            this.mostrarLoadingProdutos(true);
            
            // AJUSTE: tentar endpoint API padrão (se houver) — se não existir, o código atual do servidor renderiza produtos em PHP
            const response = await fetch('../../api/produtos_categoria.php');
            const data = await response.json();
            
            if (data.success && data.produtos) {
                this.produtos = data.produtos;
            } else if (Array.isArray(data)) {
                // alguns endpoints podem retornar diretamente um array
                this.produtos = data;
            } else if (data.produtos) {
                this.produtos = data.produtos;
                this.renderizarProdutos(this.produtos);
            } else {
                throw new Error(data.message || 'Erro ao carregar produtos');
            }
        } catch (error) {
            console.error('Erro ao carregar produtos:', error);
            this.mostrarToast('Erro ao carregar produtos', 'error');
        } finally {
            this.mostrarLoadingProdutos(false);
        }
    }
    
    renderizarProdutos(produtos) {
        const container = document.getElementById('lista-produtos');
        if (!container) return;
        
        container.innerHTML = '';
        
        if (produtos.length === 0) {
            container.innerHTML = '<div class="produto-vazio">Nenhum produto encontrado</div>';
            return;
        }
        
        produtos.forEach(produto => {
            const produtoEl = this.criarElementoProduto(produto);
            container.appendChild(produtoEl);
        });
    }
    
    criarElementoProduto(produto) {
        const div = document.createElement('div');
        div.className = 'produto-card';
        div.innerHTML = `
            <div class="produto-info">
                <h4 class="produto-nome">${this.escapeHtml(produto.nome)}</h4>
                <p class="produto-preco">R$ ${parseFloat(produto.preco).toFixed(2)}</p>
                <div class="produto-estoque ${produto.estoque_atual <= produto.estoque_minimo ? 'estoque-baixo' : ''}">
                    Estoque: ${produto.estoque_atual}
                    ${produto.estoque_atual <= produto.estoque_minimo ? '⚠️' : ''}
                </div>
            </div>
            <button class="btn-add-item" data-produto-id="${produto.id}">
                Adicionar
            </button>
        `;
        
        div.querySelector('.btn-add-item').addEventListener('click', () => {
            this.adicionarItem(produto.id, 1);
        });
        
        return div;
    }
    
    async novaComanda() {
        if (this.carregando) return;
        
        try {
            this.carregando = true;
            
            // Usar endpoint PHP do projeto
            const response = await fetch('../../api/nova_comanda.php', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' }
            });

            const data = await response.json();

            if (data.success) {
                // API pode retornar comanda (objeto) ou apenas comanda_id
                if (data.comanda) {
                    this.comandaAtual = data.comanda;
                } else if (data.comanda_id) {
                    this.comandaAtual = { id: data.comanda_id };
                } else {
                    // fallback: tentar mensagem/estrutura diversa
                    this.comandaAtual = { id: null };
                }

                this.itensComanda = [];
                this.atualizarUIComanda();
                this.mostrarToast('Nova comanda criada', 'success');
            } else {
                throw new Error(data.message || 'Erro ao criar comanda');
            }
        } catch (error) {
            console.error('Erro ao criar comanda:', error);
            this.mostrarToast('Erro ao criar comanda', 'error');
        } finally {
            this.carregando = false;
        }
    }
    
    async adicionarItem(produtoId, quantidade = 1) {
        if (!this.comandaAtual) {
            this.mostrarToast('Crie uma comanda primeiro', 'warning');
            return;
        }
        
        if (this.carregando) return;
        
        try {
            this.carregando = true;
            
            // Usar endpoint PHP instalado no projeto
            const response = await fetch('../../api/adicionar_item.php', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    comanda_id: this.comandaAtual.id,
                    produto_id: produtoId,
                    quantidade: quantidade
                })
            });
            
            const data = await response.json();
            
            if (data.success) {
                await this.carregarItensComanda();
                this.mostrarToast('Item adicionado à comanda', 'success');
            } else {
                this.mostrarToast(data.message || 'Erro ao adicionar item', 'error');
            }
        } catch (error) {
            console.error('Erro ao adicionar item:', error);
            this.mostrarToast('Erro ao adicionar item', 'error');
        } finally {
            this.carregando = false;
        }
    }
    
    async carregarItensComanda() {
        if (!this.comandaAtual) return;
        
        try {
            // Usar endpoint PHP do projeto
            const response = await fetch(`../../api/itens_comanda.php?comanda_id=${this.comandaAtual.id}`);
            const data = await response.json();

            // aceitar formatos diferentes retornados pela API
            if (data.success && data.itens) {
                this.itensComanda = data.itens;
            } else if (data.itens) {
                this.itensComanda = data.itens;
            } else if (Array.isArray(data)) {
                this.itensComanda = data;
            } else if (data.itens_comanda) {
                this.itensComanda = data.itens_comanda;
            }

            this.atualizarListaItens();
            this.atualizarTotal();
            this.atualizarBotaoFinalizar();
        } catch (error) {
            console.error('Erro ao carregar itens:', error);
        }
    }
    
    atualizarListaItens() {
        const container = document.getElementById('lista-itens');
        const totalElement = document.getElementById('total-comanda');
        
        if (!container) return;
        
        if (this.itensComanda.length === 0) {
            container.innerHTML = '<div class="item-vazio">Nenhum item adicionado</div>';
            if (totalElement) totalElement.textContent = '0.00';
            return;
        }
        
        container.innerHTML = '';
        this.itensComanda.forEach(item => {
            const itemEl = this.criarElementoItem(item);
            container.appendChild(itemEl);
        });
    }
    
    criarElementoItem(item) {
        const div = document.createElement('div');
        div.className = 'item-comanda';
        div.innerHTML = `
            <div class="item-info">
                <span class="item-nome">${this.escapeHtml(item.nome_produto)}</span>
                <span class="item-quantidade">${item.quantidade}x</span>
                <span class="item-subtotal">R$ ${parseFloat(item.subtotal).toFixed(2)}</span>
            </div>
            <button class="btn-remover-item" data-item-id="${item.id}">
                ✕
            </button>
        `;
        
        div.querySelector('.btn-remover-item').addEventListener('click', () => {
            this.removerItem(item.id);
        });
        
        return div;
    }
    
    async removerItem(itemId) {
        if (!this.comandaAtual || this.carregando) return;
        
        try {
            this.carregando = true;
            
            // Usar endpoint PHP do projeto
            const response = await fetch('../../api/remover_item.php', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    item_id: itemId
                })
            });
            
            const data = await response.json();
            
            if (data.success) {
                await this.carregarItensComanda();
                this.mostrarToast('Item removido', 'success');
            } else {
                this.mostrarToast(data.message, 'error');
            }
        } catch (error) {
            console.error('Erro ao remover item:', error);
            this.mostrarToast('Erro ao remover item', 'error');
        } finally {
            this.carregando = false;
        }
    }
    
    async finalizarComanda() {
        if (!this.comandaAtual || this.itensComanda.length === 0) {
            this.mostrarToast('Comanda vazia', 'warning');
            return;
        }
        
        if (this.carregando) return;
        
        // Primeiro validar estoque
        const estoqueOk = await this.validarEstoqueFinalizacao();
        if (!estoqueOk) {
            this.mostrarToast('Estoque insuficiente para finalizar venda', 'error');
            return;
        }
        
        // Confirmar finalização
        if (!confirm('Finalizar comanda e baixar estoque?')) {
            return;
        }
        
        try {
            this.carregando = true;
            
            // Usar endpoint PHP do projeto
            const response = await fetch('../../api/finalizar_comanda.php', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    comanda_id: this.comandaAtual.id
                })
            });
            
            const data = await response.json();
            
            if (data.success) {
                this.mostrarToast('Comanda finalizada com sucesso!', 'success');
                this.limparComanda();
            } else {
                this.mostrarToast(data.message, 'error');
            }
        } catch (error) {
            console.error('Erro ao finalizar comanda:', error);
            this.mostrarToast('Erro ao finalizar comanda', 'error');
        } finally {
            this.carregando = false;
        }
    }
    
    async validarEstoqueFinalizacao() {
        if (!this.comandaAtual) return false;
        
        try {
            // Usar endpoint PHP do projeto
            const response = await fetch('../../api/verificar_estoque.php', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json',
                },
                body: JSON.stringify({
                    comanda_id: this.comandaAtual.id
                })
            });
            
            const data = await response.json();
            // aceitar diferentes formatos
            if (typeof data.estoque_suficiente !== 'undefined') return data.estoque_suficiente;
            if (typeof data.success !== 'undefined' && data.success === false) return false;
            return true;
        } catch (error) {
            console.error('Erro ao validar estoque:', error);
            return false;
        }
    }
    
    cancelarComanda() {
        if (!this.comandaAtual) {
            this.mostrarToast('Nenhuma comanda ativa', 'warning');
            return;
        }
        
        if (confirm('Cancelar comanda atual? Os itens serão perdidos.')) {
            this.limparComanda();
            this.mostrarToast('Comanda cancelada', 'info');
        }
    }
    
    limparComanda() {
        this.comandaAtual = null;
        this.itensComanda = [];
        this.atualizarUIComanda();
    }
    
    atualizarUIComanda() {
        const numeroElement = document.getElementById('comanda-numero');
        const statusElement = document.getElementById('comanda-status');
        const totalElement = document.getElementById('total-comanda');
        
        if (!numeroElement || !statusElement) return;
        
        if (this.comandaAtual) {
            numeroElement.textContent = this.comandaAtual.id;
            statusElement.textContent = 'Aberta';
            statusElement.className = 'comanda-status status-aberta';
        } else {
            numeroElement.textContent = '--';
            statusElement.textContent = 'Nenhuma comanda ativa';
            statusElement.className = 'comanda-status status-inativa';
            if (totalElement) totalElement.textContent = '0.00';
            this.atualizarListaItens();
        }
        
        this.atualizarBotaoFinalizar();
    }
    
    atualizarTotal() {
        const totalElement = document.getElementById('total-comanda');
        if (!totalElement) return;
        
        const total = this.itensComanda.reduce((sum, item) => sum + parseFloat(item.subtotal), 0);
        totalElement.textContent = total.toFixed(2);
    }
    
    atualizarBotaoFinalizar() {
        const btnFinalizar = document.getElementById('btn-finalizar');
        if (btnFinalizar) {
            btnFinalizar.disabled = !this.comandaAtual || this.itensComanda.length === 0;
        }
    }
    
    filtrarProdutos(termo) {
        const produtosFiltrados = this.produtos.filter(produto =>
            produto.nome.toLowerCase().includes(termo.toLowerCase())
        );
        this.renderizarProdutos(produtosFiltrados);
    }
    
    filtrarPorCategoria(categoria) {
        // Ativar botão da categoria
        document.querySelectorAll('.categoria-btn').forEach(btn => {
            btn.classList.toggle('active', btn.dataset.categoria === categoria);
        });
        
        if (categoria === 'todas') {
            this.renderizarProdutos(this.produtos);
        } else {
            const produtosFiltrados = this.produtos.filter(produto =>
                produto.categoria_nome === categoria
            );
            this.renderizarProdutos(produtosFiltrados);
        }
    }
    
    mostrarLoadingProdutos(mostrar) {
        const loading = document.getElementById('loading-produtos');
        const lista = document.getElementById('lista-produtos');
        
        if (!loading || !lista) return;
        
        if (mostrar) {
            loading.style.display = 'block';
            lista.style.display = 'none';
        } else {
            loading.style.display = 'none';
            lista.style.display = 'grid';
        }
    }
    
    mostrarToast(mensagem, tipo = 'info') {
        // Implementação simples de toast
        const toastContainer = document.getElementById('toast-container');
        if (!toastContainer) return;
        
        const toast = document.createElement('div');
        toast.className = `toast toast-${tipo}`;
        toast.textContent = mensagem;
        
        toastContainer.appendChild(toast);
        
        setTimeout(() => {
            toast.remove();
        }, 3000);
    }
    
    escapeHtml(text) {
        const div = document.createElement('div');
        div.textContent = text;
        return div.innerHTML;
    }
}

// Inicializar sistema quando DOM estiver pronto
document.addEventListener('DOMContentLoaded', () => {
    window.caixaSystem = new CaixaSystem();
});