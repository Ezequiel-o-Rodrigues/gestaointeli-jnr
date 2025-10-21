class Estoque {
    constructor() {
        this.init();
    }

    init() {
        this.configurarEventListeners();
        this.carregarDados();
    }

    configurarEventListeners() {
        // Formulário de entrada
        document.getElementById('form-entrada').addEventListener('submit', (e) => {
            e.preventDefault();
            this.registrarEntrada();
        });

        // Formulário de produto
        document.getElementById('form-produto').addEventListener('submit', (e) => {
            e.preventDefault();
            this.salvarProduto();
        });
    }

    abrirModalEntrada(produtoId) {
        // Buscar dados do produto - ✅ CORRIGIDO
        fetch(PathConfig.api(`produto_info.php?id=${produtoId}`))
            .then(response => response.json())
            .then(produto => {
                document.getElementById('produto_id_entrada').value = produto.id;
                document.getElementById('nome-produto-entrada').textContent = produto.nome;
                document.getElementById('modal-entrada').style.display = 'block';
            })
            .catch(error => {
                console.error('Erro:', error);
                this.showToast('Erro ao carregar dados do produto', 'error');
            });
    }

    fecharModalEntrada() {
        document.getElementById('modal-entrada').style.display = 'none';
        document.getElementById('form-entrada').reset();
    }

    abrirModalProduto(produtoId = null) {
        const modal = document.getElementById('modal-produto');
        const titulo = document.getElementById('titulo-modal-produto');
        
        if (produtoId) {
            titulo.textContent = 'Editar Produto';
            this.carregarDadosProduto(produtoId);
        } else {
            titulo.textContent = 'Novo Produto';
            document.getElementById('form-produto').reset();
        }
        
        modal.style.display = 'block';
    }

    fecharModalProduto() {
        document.getElementById('modal-produto').style.display = 'none';
    }

    async registrarEntrada() {
        const formData = {
            produto_id: document.getElementById('produto_id_entrada').value,
            quantidade: document.getElementById('quantidade_entrada').value,
            fornecedor_id: document.getElementById('fornecedor_entrada').value || null,
            observacao: document.getElementById('observacao_entrada').value
        };

        const btn = document.querySelector('#form-entrada button[type="submit"]');
        const originalContent = btn.innerHTML;
        btn.innerHTML = '<i class="fas fa-spinner fa-pulse"></i> Registrando...';
        btn.disabled = true;

        try {
            // ✅ CORRIGIDO
            const response = await fetch(PathConfig.api('registrar_entrada.php'), {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(formData)
            });

            const result = await response.json();

            if (result.success) {
                this.showToast('Entrada registrada com sucesso!', 'success');
                this.fecharModalEntrada();
                setTimeout(() => {
                    location.reload(); // Recarregar para atualizar dados
                }, 1500);
            } else {
                throw new Error(result.message || 'Erro ao registrar entrada');
            }
        } catch (error) {
            console.error('Erro:', error);
            this.showToast('Erro: ' + error.message, 'error');
        } finally {
            btn.innerHTML = originalContent;
            btn.disabled = false;
        }
    }

    async salvarProduto() {
        const formData = {
            id: document.getElementById('produto_id').value || null,
            nome: document.getElementById('nome_produto').value,
            categoria_id: document.getElementById('categoria_produto').value,
            preco: document.getElementById('preco_produto').value,
            estoque_minimo: document.getElementById('estoque_minimo_produto').value,
            estoque_inicial: document.getElementById('estoque_inicial_produto').value || 0
        };

        const btn = document.querySelector('#form-produto button[type="submit"]');
        const originalContent = btn.innerHTML;
        btn.innerHTML = '<i class="fas fa-spinner fa-pulse"></i> Salvando...';
        btn.disabled = true;

        try {
            // ✅ CORRIGIDO
            const response = await fetch(PathConfig.api('salvar_produto.php'), {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(formData)
            });

            const result = await response.json();

            if (result.success) {
                this.showToast('Produto salvo com sucesso!', 'success');
                this.fecharModalProduto();
                setTimeout(() => {
                    location.reload();
                }, 1500);
            } else {
                throw new Error(result.message || 'Erro ao salvar produto');
            }
        } catch (error) {
            console.error('Erro:', error);
            this.showToast('Erro: ' + error.message, 'error');
        } finally {
            btn.innerHTML = originalContent;
            btn.disabled = false;
        }
    }

    async carregarDadosProduto(produtoId) {
        try {
            // ✅ CORRIGIDO
            const response = await fetch(PathConfig.api(`produto_info.php?id=${produtoId}`));
            const produto = await response.json();

            document.getElementById('produto_id').value = produto.id;
            document.getElementById('nome_produto').value = produto.nome;
            document.getElementById('categoria_produto').value = produto.categoria_id;
            document.getElementById('preco_produto').value = produto.preco;
            document.getElementById('estoque_minimo_produto').value = produto.estoque_minimo;
        } catch (error) {
            console.error('Erro:', error);
            this.showToast('Erro ao carregar dados do produto', 'error');
        }
    }

    async toggleProduto(produtoId, novoStatus, button) {
        const confirmMessage = novoStatus ? 
            'Deseja ativar este produto?' : 
            'Deseja desativar este produto?';
            
        if (!confirm(confirmMessage)) return;

        const originalContent = button.innerHTML;
        button.innerHTML = '<i class="fas fa-spinner fa-pulse"></i>';
        button.disabled = true;

        try {
            // ✅ CORRIGIDO
            const response = await fetch(PathConfig.api('toggle_produto.php'), {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    produto_id: produtoId,
                    ativo: novoStatus
                })
            });

            const result = await response.json();

            if (result.success) {
                this.showToast(`Produto ${novoStatus ? 'ativado' : 'desativado'} com sucesso!`, 'success');
                setTimeout(() => {
                    location.reload();
                }, 1500);
            } else {
                throw new Error(result.message || 'Erro ao atualizar produto');
            }
        } catch (error) {
            console.error('Erro:', error);
            this.showToast('Erro: ' + error.message, 'error');
            button.innerHTML = originalContent;
            button.disabled = false;
        }
    }

    // Função para filtrar produtos (similar ao listagens.php)
    filtrarProdutos() {
        const categoria = document.getElementById('filtro-categoria').value;
        const status = document.getElementById('filtro-status').value;
        const searchTerm = document.getElementById('filtro-produto').value.toLowerCase();
        
        document.querySelectorAll('.item-row:not(.item-header)').forEach(row => {
            const rowCategoria = row.getAttribute('data-categoria');
            const rowStatus = row.getAttribute('data-status');
            const rowSearch = row.getAttribute('data-search').toLowerCase();
            
            const categoriaMatch = categoria === 'all' || rowCategoria === categoria;
            const statusMatch = status === 'all' || rowStatus === status;
            const searchMatch = rowSearch.includes(searchTerm);
            
            if (categoriaMatch && statusMatch && searchMatch) {
                row.style.display = 'grid';
            } else {
                row.style.display = 'none';
            }
        });
        
        // Mostrar/ocultar cards baseado no filtro de categoria
        document.querySelectorAll('.card[id$="-card"]').forEach(card => {
            const cardId = card.id;
            const cardCategoria = cardId.replace('categoria-', '').replace('-card', '');
            
            if (categoria === 'all' || cardCategoria === categoria) {
                card.style.display = 'block';
            } else {
                card.style.display = 'none';
            }
        });
    }

    // Função para mostrar mensagens toast
    showToast(message, type) {
        const toast = document.createElement('div');
        toast.className = `toast ${type}`;
        toast.textContent = message;
        document.body.appendChild(toast);
        
        setTimeout(() => {
            toast.classList.add('show');
        }, 100);
        
        setTimeout(() => {
            toast.classList.remove('show');
            setTimeout(() => {
                toast.remove();
            }, 300);
        }, 3000);
    }

    carregarDados() {
        // Implementar carregamento adicional de dados se necessário
    }
}

// Inicializar estoque
const estoque = new Estoque();

// Funções globais
function abrirModalEntrada(produtoId) {
    estoque.abrirModalEntrada(produtoId);
}

function fecharModalEntrada() {
    estoque.fecharModalEntrada();
}

function abrirModalProduto(produtoId = null) {
    if (produtoId) {
        estoque.abrirModalProduto(produtoId);
    } else {
        estoque.abrirModalProduto();
    }
}

function fecharModalProduto() {
    estoque.fecharModalProduto();
}

function editarProduto(produtoId) {
    estoque.abrirModalProduto(produtoId);
}

function toggleProduto(produtoId, novoStatus, button) {
    estoque.toggleProduto(produtoId, novoStatus, button);
}

function filtrarProdutos() {
    estoque.filtrarProdutos();
}

// Fechar modal ao clicar fora
window.onclick = function(event) {
    const modals = document.getElementsByClassName('modal');
    for (let modal of modals) {
        if (event.target === modal) {
            modal.style.display = 'none';
        }
    }
}