class Relatorios {
    constructor() {
        this.graficoVendas = null;
        this.graficoCategorias = null;
        this.init();
    }

    init() {
        this.inicializarGraficos();
        this.carregarDadosIniciais();
    }

    inicializarGraficos() {
        const ctxVendas = document.getElementById('grafico-vendas').getContext('2d');
        const ctxCategorias = document.getElementById('grafico-categorias').getContext('2d');

        this.graficoVendas = new Chart(ctxVendas, {
            type: 'line',
            data: {
                labels: [],
                datasets: [{
                    label: 'Vendas (R$)',
                    data: [],
                    borderColor: '#3498db',
                    backgroundColor: 'rgba(52, 152, 219, 0.1)',
                    tension: 0.4
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false
            }
        });

        this.graficoCategorias = new Chart(ctxCategorias, {
            type: 'doughnut',
            data: {
                labels: [],
                datasets: [{
                    data: [],
                    backgroundColor: [
                        '#3498db', '#2ecc71', '#e74c3c', '#f39c12', 
                        '#9b59b6', '#1abc9c', '#d35400', '#34495e'
                    ]
                }]
            },
            options: {
                responsive: true,
                maintainAspectRatio: false
            }
        });
    }

    async carregarDadosIniciais() {
        await this.carregarVendasUltimos7Dias();
        await this.carregarTopCategorias();
    }

    async carregarVendasUltimos7Dias() {
        try {
            const response = await fetch('../../api/relatorio_vendas_7dias.php');
            const dados = await response.json();

            this.graficoVendas.data.labels = dados.labels;
            this.graficoVendas.data.datasets[0].data = dados.valores;
            this.graficoVendas.update();
        } catch (error) {
            console.error('Erro ao carregar vendas:', error);
        }
    }

    async carregarTopCategorias() {
        try {
            const response = await fetch('../../api/relatorio_top_categorias.php');
            const dados = await response.json();

            this.graficoCategorias.data.labels = dados.labels;
            this.graficoCategorias.data.datasets[0].data = dados.valores;
            this.graficoCategorias.update();
        } catch (error) {
            console.error('Erro ao carregar categorias:', error);
        }
    }

    async gerarRelatorio() {
        const dataInicio = document.getElementById('data-inicio').value;
        const dataFim = document.getElementById('data-fim').value;
        const tipoRelatorio = document.getElementById('tipo-relatorio').value;

        if (!dataInicio || !dataFim) {
            alert('Selecione as datas de início e fim');
            return;
        }

        try {
            const response = await fetch('../../api/gerar_relatorio.php', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    data_inicio: dataInicio,
                    data_fim: dataFim,
                    tipo: tipoRelatorio
                })
            });

            const dados = await response.json();
            this.exibirResultados(dados, tipoRelatorio);
        } catch (error) {
            console.error('Erro ao gerar relatório:', error);
        }
    }

    exibirResultados(dados, tipo) {
        const container = document.querySelector('.resultados-relatorio');
        
        switch(tipo) {
            case 'vendas':
                container.innerHTML = this.criarTabelaVendas(dados);
                break;
            case 'produtos':
                container.innerHTML = this.criarTabelaProdutos(dados);
                break;
            case 'estoque':
                container.innerHTML = this.criarTabelaEstoque(dados);
                break;
        }
    }

    criarTabelaVendas(dados) {
        let html = `<h3>Vendas por Período</h3>
                   <div class="table-responsive">
                   <table class="table">
                   <thead>
                   <tr><th>Data</th><th>Comandas</th><th>Valor Total</th><th>Ticket Médio</th></tr>
                   </thead><tbody>`;

        dados.forEach(item => {
            html += `<tr>
                    <td>${item.data}</td>
                    <td>${item.total_comandas}</td>
                    <td>${this.formatarMoeda(item.valor_total)}</td>
                    <td>${this.formatarMoeda(item.ticket_medio)}</td>
                    </tr>`;
        });

        html += `</tbody></table></div>`;
        return html;
    }

    criarTabelaProdutos(dados) {
        let html = `<h3>Produtos Mais Vendidos</h3>
                   <div class="table-responsive">
                   <table class="table">
                   <thead>
                   <tr><th>Produto</th><th>Categoria</th><th>Quantidade</th><th>Valor Total</th></tr>
                   </thead><tbody>`;

        dados.forEach(item => {
            html += `<tr>
                    <td>${item.nome}</td>
                    <td>${item.categoria}</td>
                    <td>${item.total_vendido}</td>
                    <td>${this.formatarMoeda(item.valor_total_vendido)}</td>
                    </tr>`;
        });

        html += `</tbody></table></div>`;
        return html;
    }

    criarTabelaEstoque(dados) {
        let html = `<h3>Movimentação de Estoque</h3>
                   <div class="table-responsive">
                   <table class="table">
                   <thead>
                   <tr><th>Data</th><th>Produto</th><th>Tipo</th><th>Quantidade</th><th>Observação</th></tr>
                   </thead><tbody>`;

        dados.forEach(item => {
            html += `<tr>
                    <td>${item.data_movimentacao}</td>
                    <td>${item.nome_produto}</td>
                    <td>${item.tipo === 'entrada' ? '📥 Entrada' : '📤 Saída'}</td>
                    <td>${item.quantidade}</td>
                    <td>${item.observacao || '-'}</td>
                    </tr>`;
        });

        html += `</tbody></table></div>`;
        return html;
    }

    formatarMoeda(valor) {
        return new Intl.NumberFormat('pt-BR', {
            style: 'currency',
            currency: 'BRL'
        }).format(valor);
    }

    exportarRelatorio() {
        // Implementar exportação para PDF/Excel
        alert('Funcionalidade de exportação em desenvolvimento');
    }
}

// Inicializar relatórios (APENAS UMA INSTÂNCIA)
const relatorios = new Relatorios();

// Funções globais para os botões HTML
function gerarRelatorio() {
    relatorios.gerarRelatorio();
}

function exportarRelatorio() {
    relatorios.exportarRelatorio();
}