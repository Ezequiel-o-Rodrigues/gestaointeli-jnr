class Caixa {
    constructor() {
        this.comandaId = null;
        this.itens = [];
        this.categoriaAtual = null;
        this.init();
    }

    init() {
        this.carregarComandaAberta();
        this.configurarEventListeners();
    }

    async carregarComandaAberta() {
        try {
            const response = await fetch('../../api/comanda_aberta.php');
            const data = await response.json();
            
            if (data.comanda) {
                this.comandaId = data.comanda.id;
                this.atualizarInterfaceComanda();
                this.carregarItensComanda();
            }
        } catch (error) {
            console.error('Erro ao carregar comanda:', error);
        }
    }

    async novaComanda() {
        try {
            const response = await fetch('../../api/nova_comanda.php', {
                method: 'POST'
            });
            const data = await response.json();
            
            if (data.success) {
                this.comandaId = data.comanda_id;
                this.itens = [];
                this.atualizarInterfaceComanda();
                this.mostrarNotificacao('Nova comanda criada!', 'success');
            }
        } catch (error) {
            console.error('Erro ao criar comanda:', error);
        }
    }

    async carregarProdutos(categoriaId) {
        this.categoriaAtual = categoriaId;
        
        try {
            const response = await fetch(`../../api/produtos_categoria.php?categoria_id=${categoriaId}`);
            const produtos = await response.json();
            
            this.exibirProdutos(produtos);
            document.getElementById('categorias-grid').style.display = 'none';
            document.getElementById('produtos-section').style.display = 'block';
        } catch (error) {
            console.error('Erro ao carregar produtos:', error);
        }
    }

    exibirProdutos(produtos) {
        const grid = document.getElementById('produtos-grid');
        grid.innerHTML = produtos.map(produto => `
            <div class="produto-card" onclick="caixa.adicionarProduto(${produto.id})">
                <h4>${produto.nome}</h4>
                <div class="preco">${this.formatarMoeda(produto.preco)}</div>
                <small>Estoque: ${produto.estoque_atual}</small>
            </div>
        `).join('');
    }

    voltarCategorias() {
        document.getElementById('produtos-section').style.display = 'none';
        document.getElementById('categorias-grid').style.display = 'grid';
    }

    async adicionarProduto(produtoId) {
        if (!this.comandaId) {
            this.mostrarNotificacao('Crie uma comanda primeiro!', 'warning');
            return;
        }

        try {
            const response = await fetch('../../api/adicionar_item.php', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    comanda_id: this.comandaId,
                    produto_id: produtoId,
                    quantidade: 1
                })
            });
            
            const data = await response.json();
            
            if (data.success) {
                this.carregarItensComanda();
                this.mostrarNotificacao('Produto adicionado!', 'success');
            }
        } catch (error) {
            console.error('Erro ao adicionar produto:', error);
        }
    }

    async carregarItensComanda() {
        if (!this.comandaId) return;

        try {
            const response = await fetch(`../../api/itens_comanda.php?comanda_id=${this.comandaId}`);
            const data = await response.json();
            
            this.itens = data.itens;
            this.atualizarInterfaceComanda();
        } catch (error) {
            console.error('Erro ao carregar itens:', error);
        }
    }

    atualizarInterfaceComanda() {
        const comandaElement = document.getElementById('numero-comanda');
        const itensElement = document.getElementById('itens-comanda');
        const btnFinalizar = document.getElementById('btn-finalizar');

        if (this.comandaId) {
            comandaElement.textContent = `Comanda: #${this.comandaId}`;
            
            if (this.itens.length > 0) {
                itensElement.innerHTML = this.itens.map(item => `
                    <div class="item-comanda">
                        <span>${item.nome} x${item.quantidade}</span>
                        <span>${this.formatarMoeda(item.subtotal)}</span>
                    </div>
                `).join('');
                
                btnFinalizar.disabled = false;
            } else {
                itensElement.innerHTML = '<p class="empty-message">Nenhum item adicionado</p>';
                btnFinalizar.disabled = true;
            }

            this.calcularTotais();
        } else {
            comandaElement.textContent = 'Comanda: --';
            itensElement.innerHTML = '<p class="empty-message">Nenhuma comanda aberta</p>';
            btnFinalizar.disabled = true;
        }
    }

    calcularTotais() {
        const subtotal = this.itens.reduce((sum, item) => sum + parseFloat(item.subtotal), 0);
        // Calcular taxa (implementar lógica das configurações)
        const taxa = 0;
        const total = subtotal + taxa;

        document.getElementById('subtotal').textContent = this.formatarMoeda(subtotal);
        document.getElementById('taxa').textContent = this.formatarMoeda(taxa);
        document.getElementById('total').textContent = this.formatarMoeda(total);
    }

    async finalizarComanda() {
        if (!this.comandaId || this.itens.length === 0) return;

        if (confirm('Deseja finalizar esta comanda?')) {
            try {
                const response = await fetch('../../api/finalizar_comanda.php', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json'
                    },
                    body: JSON.stringify({
                        comanda_id: this.comandaId
                    })
                });
                
                const data = await response.json();
                
                if (data.success) {
                    this.mostrarNotificacao('Comanda finalizada com sucesso!', 'success');
                    this.comandaId = null;
                    this.itens = [];
                    this.atualizarInterfaceComanda();
                }
            } catch (error) {
                console.error('Erro ao finalizar comanda:', error);
            }
        }
    }
}

// Inicializar caixa
const caixa = new Caixa();

// Funções globais para onclick
function novaComanda() {
    caixa.novaComanda();
}

function carregarProdutos(categoriaId) {
    caixa.carregarProdutos(categoriaId);
}

function voltarCategorias() {
    caixa.voltarCategorias();
}

function finalizarComanda() {
    caixa.finalizarComanda();
}