class Relatorios {
    constructor() {
        this.graficoVendas = null;
        this.graficoCategorias = null;
        this.graficoMensal = null;
        this.init();
    }

    init() {
        this.inicializarGraficos();
        this.carregarDadosIniciais();
        this.carregarAlertasPerda();
    }

    inicializarGraficos() {
        const ctxVendas = document.getElementById('grafico-vendas');
        const ctxCategorias = document.getElementById('grafico-categorias');
        const ctxMensal = document.getElementById('grafico-mensal');

        if (ctxVendas) {
            this.graficoVendas = new Chart(ctxVendas.getContext('2d'), {
                type: 'line',
                data: {
                    labels: [],
                    datasets: [{
                        label: 'Vendas (R$)',
                        data: [],
                        borderColor: '#3498db',
                        backgroundColor: 'rgba(52, 152, 219, 0.1)',
                        tension: 0.4,
                        fill: true
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        title: {
                            display: true,
                            text: 'Vendas dos Últimos 7 Dias'
                        }
                    }
                }
            });
        }

        if (ctxCategorias) {
            this.graficoCategorias = new Chart(ctxCategorias.getContext('2d'), {
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

        if (ctxMensal) {
            this.graficoMensal = new Chart(ctxMensal.getContext('2d'), {
                type: 'bar',
                data: {
                    labels: [],
                    datasets: [{
                        label: 'Vendas Mensais (R$)',
                        data: [],
                        backgroundColor: 'rgba(52, 152, 219, 0.8)',
                        borderColor: '#3498db',
                        borderWidth: 1
                    }]
                },
                options: {
                    responsive: true,
                    maintainAspectRatio: false,
                    plugins: {
                        title: {
                            display: true,
                            text: 'Vendas por Mês'
                        }
                    }
                }
            });
        }
    }

    async carregarDadosIniciais() {
        await this.carregarVendasUltimos7Dias();
        await this.carregarTopCategorias();
        await this.carregarVendasMensais();
    }

    async carregarVendasUltimos7Dias() {
        try {
            const dataInicio = new Date();
            dataInicio.setDate(dataInicio.getDate() - 7);
            
            const response = await fetch(`../../api/relatorio_vendas_periodo.php?tipo=diario&data_inicio=${dataInicio.toISOString().split('T')[0]}&data_fim=${new Date().toISOString().split('T')[0]}`);
            const dados = await response.json();

            if (dados.success && this.graficoVendas) {
                const labels = dados.data.map(item => {
                    const data = new Date(item.data_venda);
                    return data.toLocaleDateString('pt-BR', { weekday: 'short', day: '2-digit' });
                });
                const valores = dados.data.map(item => parseFloat(item.valor_total_vendas));

                this.graficoVendas.data.labels = labels;
                this.graficoVendas.data.datasets[0].data = valores;
                this.graficoVendas.update();
            }
        } catch (error) {
            console.error('Erro ao carregar vendas:', error);
        }
    }

    async carregarTopCategorias() {
        try {
            const response = await fetch('../../api/relatorio_produtos_vendidos.php?limit=8');
            const dados = await response.json();

            if (dados.success && this.graficoCategorias) {
                // Agrupar por categoria
                const categorias = {};
                dados.data.forEach(produto => {
                    if (!categorias[produto.categoria]) {
                        categorias[produto.categoria] = 0;
                    }
                    categorias[produto.categoria] += parseFloat(produto.valor_total_vendido);
                });

                const labels = Object.keys(categorias);
                const valores = Object.values(categorias);

                this.graficoCategorias.data.labels = labels;
                this.graficoCategorias.data.datasets[0].data = valores;
                this.graficoCategorias.update();
            }
        } catch (error) {
            console.error('Erro ao carregar categorias:', error);
        }
    }

    async carregarVendasMensais() {
        try {
            const response = await fetch('../../api/relatorio_vendas_mensais.php');
            const dados = await response.json();

            if (dados.success && this.graficoMensal) {
                this.graficoMensal.data.labels = dados.grafico.labels;
                this.graficoMensal.data.datasets[0].data = dados.grafico.valores;
                this.graficoMensal.update();
            }
        } catch (error) {
            console.error('Erro ao carregar vendas mensais:', error);
        }
    }

    async carregarAlertasPerda() {
        try {
            const response = await fetch('../../api/relatorio_alertas_perda.php');
            const dados = await response.json();

            if (dados.success) {
                this.exibirAlertasPerda(dados.data);
            }
        } catch (error) {
            console.error('Erro ao carregar alertas:', error);
        }
    }

    exibirAlertasPerda(alertas) {
        const container = document.getElementById('alertas-perda-container');
        if (!container) return;

        if (alertas.length === 0) {
            container.innerHTML = '<div class="alerta-item sucesso">✅ Nenhuma perda de estoque identificada</div>';
            return;
        }

        let html = '<h4>🚨 Alertas de Perda de Estoque</h4>';
        
        alertas.forEach(alerta => {
            html += `
                <div class="alerta-item perda">
                    <strong>${alerta.nome}</strong> (${alerta.categoria})
                    <br>
                    <small>Diferença no estoque: ${alerta.diferenca_estoque} unidades</small>
                    <br>
                    <small>Entradas: ${alerta.total_entradas} | Vendidos: ${alerta.total_vendido} | Estoque atual: ${alerta.estoque_atual}</small>
                </div>
            `;
        });

        container.innerHTML = html;
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
            let url = '';
            switch(tipoRelatorio) {
                case 'vendas':
                    url = `../../api/relatorio_vendas_periodo.php?data_inicio=${dataInicio}&data_fim=${dataFim}&tipo=diario`;
                    break;
                case 'produtos':
                    url = `../../api/relatorio_produtos_vendidos.php?data_inicio=${dataInicio}&data_fim=${dataFim}`;
                    break;
                case 'estoque':
                    url = `../../api/relatorio_alertas_perda.php`;
                    break;
            }

            const response = await fetch(url);
            const dados = await response.json();

            if (dados.success) {
                this.exibirResultados(dados.data, tipoRelatorio);
            } else {
                alert('Erro ao gerar relatório: ' + dados.message);
            }
        } catch (error) {
            console.error('Erro ao gerar relatório:', error);
            alert('Erro ao gerar relatório');
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
        if (dados.length === 0) {
            return '<div class="sem-dados">Nenhuma venda encontrada no período selecionado</div>';
        }

        let html = `<h3>📈 Vendas por Período</h3>
                   <div class="table-responsive">
                   <table class="table">
                   <thead>
                   <tr><th>Data</th><th>Comandas</th><th>Valor Total</th><th>Gorjetas</th><th>Ticket Médio</th></tr>
                   </thead><tbody>`;

        dados.forEach(item => {
            html += `<tr>
                    <td>${item.data_venda || item.periodo || item.mes_ano}</td>
                    <td>${item.total_comandas}</td>
                    <td>${this.formatarMoeda(item.valor_total_vendas)}</td>
                    <td>${this.formatarMoeda(item.total_gorjetas)}</td>
                    <td>${this.formatarMoeda(item.ticket_medio)}</td>
                    </tr>`;
        });

        const totalVendas = dados.reduce((sum, item) => sum + parseFloat(item.valor_total_vendas), 0);
        const totalComandas = dados.reduce((sum, item) => sum + parseInt(item.total_comandas), 0);

        html += `<tr class="total-row">
                <td><strong>Total</strong></td>
                <td><strong>${totalComandas}</strong></td>
                <td><strong>${this.formatarMoeda(totalVendas)}</strong></td>
                <td colspan="2"></td>
                </tr>`;
        html += `</tbody></table></div>`;
        return html;
    }

    criarTabelaProdutos(dados) {
        if (dados.length === 0) {
            return '<div class="sem-dados">Nenhum produto vendido no período selecionado</div>';
        }

        let html = `<h3>🏆 Produtos Mais Vendidos</h3>
                   <div class="table-responsive">
                   <table class="table">
                   <thead>
                   <tr><th>Produto</th><th>Categoria</th><th>Quantidade</th><th>Valor Total</th><th>Comandas</th></tr>
                   </thead><tbody>`;

        dados.forEach(item => {
            html += `<tr>
                    <td>${item.nome}</td>
                    <td>${item.categoria}</td>
                    <td>${item.total_vendido}</td>
                    <td>${this.formatarMoeda(item.valor_total_vendido)}</td>
                    <td>${item.total_comandas || '-'}</td>
                    </tr>`;
        });

        html += `</tbody></table></div>`;
        return html;
    }

    criarTabelaEstoque(dados) {
        if (dados.length === 0) {
            return '<div class="sem-dados">✅ Nenhum alerta de perda de estoque</div>';
        }

        let html = `<h3>🚨 Alertas de Perda de Estoque</h3>
                   <div class="table-responsive">
                   <table class="table">
                   <thead>
                   <tr><th>Produto</th><th>Categoria</th><th>Diferença</th><th>Entradas</th><th>Vendidos</th><th>Estoque Atual</th></tr>
                   </thead><tbody>`;

        dados.forEach(item => {
            html += `<tr>
                    <td>${item.nome}</td>
                    <td>${item.categoria}</td>
                    <td class="destaque-perda">${item.diferenca_estoque}</td>
                    <td>${item.total_entradas}</td>
                    <td>${item.total_vendido}</td>
                    <td>${item.estoque_atual}</td>
                    </tr>`;
        });

        html += `</tbody></table></div>`;
        return html;
    }

    formatarMoeda(valor) {
        return new Intl.NumberFormat('pt-BR', {
            style: 'currency',
            currency: 'BRL'
        }).format(valor || 0);
    }

    exportarRelatorio() {
        // Implementação básica - pode ser expandida para PDF/Excel
        const tabela = document.querySelector('.resultados-relatorio table');
        if (!tabela) {
            alert('Gere um relatório primeiro para exportar');
            return;
        }

        const html = tabela.outerHTML;
        const blob = new Blob([html], { type: 'application/vnd.ms-excel' });
        const url = URL.createObjectURL(blob);
        const a = document.createElement('a');
        a.href = url;
        a.download = 'relatorio.xls';
        a.click();
        URL.revokeObjectURL(url);
    }
}

// Inicializar relatórios
const relatorios = new Relatorios();

// Funções globais para os botões HTML
function gerarRelatorio() {
    relatorios.gerarRelatorio();
}

function exportarRelatorio() {
    relatorios.exportarRelatorio();
}