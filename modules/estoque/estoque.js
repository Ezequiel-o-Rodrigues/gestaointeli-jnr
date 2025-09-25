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

        // Filtros
        document.getElementById('filtro-produto').addEventListener('keypress', (e) => {
            if (e.key === 'Enter') this.filtrarProdutos();
        });
    }

    abrirModalEntrada(produtoId) {
        // Buscar dados do produto
        fetch(`../../api/produto_info.php?id=${produtoId}`)
            .then(response => response.json())
            .then(produto => {
                document.getElementById('produto_id_entrada').value = produto.id;
                document.getElementById('nome-produto-entrada').textContent = produto.nome;
                document.getElementById('modal-entrada').style.display = 'block';
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

        try {
            const response = await fetch('../../api/registrar_entrada.php', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(formData)
            });

            const result = await response.json();

            if (result.success) {
                alert('Entrada registrada com sucesso!');
                this.fecharModalEntrada();
                location.reload(); // Recarregar para atualizar dados
            } else {
                alert('Erro: ' + result.message);
            }
        } catch (error) {
            console.error('Erro:', error);
            alert('Erro ao registrar entrada');
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

        try {
            const response = await fetch('../../api/salvar_produto.php', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify(formData)
            });

            const result = await response.json();

            if (result.success) {
                alert('Produto salvo com sucesso!');
                this.fecharModalProduto();
                location.reload();
            } else {
                alert('Erro: ' + result.message);
            }
        } catch (error) {
            console.error('Erro:', error);
            alert('Erro ao salvar produto');
        }
    }

    async carregarDadosProduto(produtoId) {
        try {
            const response = await fetch(`../../api/produto_info.php?id=${produtoId}`);
            const produto = await response.json();

            document.getElementById('produto_id').value = produto.id;
            document.getElementById('nome_produto').value = produto.nome;
            document.getElementById('categoria_produto').value = produto.categoria_id;
            document.getElementById('preco_produto').value = produto.preco;
            document.getElementById('estoque_minimo_produto').value = produto.estoque_minimo;
        } catch (error) {
            console.error('Erro:', error);
        }
    }

    async toggleProduto(produtoId, novoStatus) {
        if (confirm(`Deseja ${novoStatus ? 'ativar' : 'desativar'} este produto?`)) {
            try {
                const response = await fetch('../../api/toggle_produto.php', {
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
                    alert('Produto atualizado com sucesso!');
                    location.reload();
                }
            } catch (error) {
                console.error('Erro:', error);
                alert('Erro ao atualizar produto');
            }
        }
    }

    filtrarProdutos() {
        const filtroNome = document.getElementById('filtro-produto').value.toLowerCase();
        const filtroCategoria = document.getElementById('filtro-categoria').value;

        const linhas = document.querySelectorAll('#tabela-produtos tbody tr');

        linhas.forEach(linha => {
            const nome = linha.cells[0].textContent.toLowerCase();
            const categoria = linha.cells[1].textContent;
            const categoriaId = linha.cells[1].getAttribute('data-categoria-id') || '';

            const matchNome = nome.includes(filtroNome);
            const matchCategoria = !filtroCategoria || categoriaId === filtroCategoria;

            linha.style.display = matchNome && matchCategoria ? '' : 'none';
        });
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

function abrirModalProduto() {
    estoque.abrirModalProduto();
}

function fecharModalProduto() {
    estoque.fecharModalProduto();
}

function editarProduto(produtoId) {
    estoque.abrirModalProduto(produtoId);
}

function toggleProduto(produtoId, novoStatus) {
    estoque.toggleProduto(produtoId, novoStatus);
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