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
            const response = await fetch('../../api/relatorio_vendas_7dias.php');
            const dados = await response.json();

            if (dados.success && this.graficoVendas) {
                this.graficoVendas.data.labels = dados.labels;
                this.graficoVendas.data.datasets[0].data = dados.valores;
                this.graficoVendas.update();
            }
        } catch (error) {
            console.error('Erro ao carregar vendas:', error);
        }
    }

    async carregarTopCategorias() {
        try {
            const response = await fetch('../../api/relatorio_top_categorias.php');
            const dados = await response.json();

            if (dados.success && this.graficoCategorias) {
                this.graficoCategorias.data.labels = dados.labels;
                this.graficoCategorias.data.datasets[0].data = dados.valores;
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

        if (!alertas || alertas.length === 0) {
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
        let params = `?data_inicio=${dataInicio}&data_fim=${dataFim}`;

        switch(tipoRelatorio) {
            case 'vendas':
                url = '../../api/relatorio_vendas_periodo.php';
                params += '&tipo=diario';
                break;
            case 'produtos':
                url = '../../api/relatorio_produtos_vendidos.php';
                break;
            case 'analise_estoque':
                url = '../../api/relatorio_analise_estoque.php';
                break;
        }

        console.log('URL da requisição:', url + params);

        const response = await fetch(url + params);
        const resultado = await response.json();

        console.log('Resultado da API:', resultado);

        if (resultado.success) {
            let dadosArray = Array.isArray(resultado.data) ? resultado.data : [];
            this.exibirResultados(dadosArray, tipoRelatorio, resultado.totais, resultado.periodo);
        } else {
            alert('Erro ao gerar relatório: ' + (resultado.message || 'Erro desconhecido'));
        }
    } catch (error) {
        console.error('Erro completo ao gerar relatório:', error);
        alert('Erro ao gerar relatório: ' + error.message);
    }
}

    exibirResultados(dados, tipo, totais = {}, periodo = {}) {
    const container = document.querySelector('.resultados-relatorio');
    
    let html = '';
    switch(tipo) {
        case 'vendas':
            html = this.criarTabelaVendas(dados);
            break;
        case 'produtos':
            html = this.criarTabelaProdutos(dados);
            break;
        case 'analise_estoque':
            html = this.criarTabelaAnaliseEstoque(dados, totais, periodo);
            break;
        default:
            html = '<div class="sem-dados">Tipo de relatório não reconhecido</div>';
    }

    container.innerHTML = html;
}
    criarTabelaVendas(dados) {
        if (!Array.isArray(dados) || dados.length === 0) {
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
                    <td>${item.data || item.data_venda || item.periodo || item.mes_ano || 'N/A'}</td>
                    <td>${item.total_comandas || 0}</td>
                    <td>${this.formatarMoeda(item.valor_total || item.valor_total_vendas)}</td>
                    <td>${this.formatarMoeda(item.total_gorjetas)}</td>
                    <td>${this.formatarMoeda(item.ticket_medio)}</td>
                    </tr>`;
        });

        const totalVendas = dados.reduce((sum, item) => sum + parseFloat(item.valor_total || item.valor_total_vendas || 0), 0);
        const totalComandas = dados.reduce((sum, item) => sum + parseInt(item.total_comandas || 0), 0);

        html += `<tr class="total-row">
                <td><strong>Total</strong></td>
                <td><strong>${totalComandas}</strong></td>
                <td><strong>${this.formatarMoeda(totalVendas)}</strong></td>
                <td colspan="2"></td>
                </tr>`;
        html += `</tbody></table></div>`;
        return html;
    }

    criarTabelaAnaliseEstoque(dados, totais, periodo) {
    if (!Array.isArray(dados) || dados.length === 0) {
        return '<div class="sem-dados">Nenhum dado encontrado para análise de estoque no período selecionado</div>';
    }

    const { data_inicio, data_fim } = periodo;

    let html = `<h3>🔍 Análise de Estoque e Perdas</h3>
               <div class="periodo-info">
                   <strong>Período:</strong> ${this.formatarData(data_inicio)} à ${this.formatarData(data_fim)}
               </div>
               <div class="totais-analise">
                   <div class="total-item">
                       <span class="total-label">Produtos com Perdas:</span>
                       <span class="total-value ${totais.total_produtos_com_perda > 0 ? 'alerta' : ''}">${totais.total_produtos_com_perda}</span>
                   </div>
                   <div class="total-item">
                       <span class="total-label">Quantidade Perdida:</span>
                       <span class="total-value ${totais.total_perdas_quantidade > 0 ? 'alerta' : ''}">${totais.total_perdas_quantidade} unidades</span>
                   </div>
                   <div class="total-item">
                       <span class="total-label">Valor das Perdas:</span>
                       <span class="total-value ${totais.total_perdas_valor > 0 ? 'alerta' : ''}">${this.formatarMoeda(totais.total_perdas_valor)}</span>
                   </div>
                   <div class="total-item">
                       <span class="total-label">Faturamento Total:</span>
                       <span class="total-value">${this.formatarMoeda(totais.total_faturamento)}</span>
                   </div>
               </div>
               <div class="table-responsive">
               <table class="table analise-estoque-table">
               <thead>
               <tr>
                   <th>Produto</th>
                   <th>Categoria</th>
                   <th>Estoque Inicial</th>
                   <th>+ Entradas</th>
                   <th>- Vendidos</th>
                   <th>= Estoque Teórico</th>
                   <th>Estoque Real</th>
                   <th>Perdas (Qtd)</th>
                   <th>Perdas (R$)</th>
                   <th>Faturamento</th>
               </tr>
               </thead><tbody>`;

    dados.forEach(item => {
        const temPerda = item.perdas_quantidade > 0;
        const classeLinha = temPerda ? 'perda-destaque' : 'sem-perda';
        
        html += `<tr class="${classeLinha}">
                <td><strong>${item.nome}</strong></td>
                <td>${item.categoria}</td>
                <td>${item.estoque_inicial}</td>
                <td>${item.entradas_periodo}</td>
                <td>${item.vendidas_periodo}</td>
                <td><strong>${item.estoque_teorico_final}</strong></td>
                <td>${item.estoque_real_atual}</td>
                <td class="${temPerda ? 'destaque-perda' : ''}">${item.perdas_quantidade}</td>
                <td class="${temPerda ? 'destaque-perda' : ''}">${this.formatarMoeda(item.perdas_valor)}</td>
                <td>${this.formatarMoeda(item.faturamento_periodo)}</td>
                </tr>`;
    });

    html += `</tbody></table></div>
            <div class="legenda-analise">
                <div class="legenda-item">
                    <div class="legenda-cor perda-destaque"></div>
                    <span>Produto com perdas identificadas</span>
                </div>
                <div class="legenda-item">
                    <div class="legenda-cor sem-perda"></div>
                    <span>Sem perdas no período</span>
                </div>
            </div>`;
    
    return html;
}

    criarTabelaProdutos(dados) {
        if (!Array.isArray(dados) || dados.length === 0) {
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
                    <td>${item.nome || 'N/A'}</td>
                    <td>${item.categoria || 'N/A'}</td>
                    <td>${item.total_vendido || item.quantidade || 0}</td>
                    <td>${this.formatarMoeda(item.valor_total_vendido || item.valor_total)}</td>
                    <td>${item.total_comandas || '-'}</td>
                    </tr>`;
        });

        html += `</tbody></table></div>`;
        return html;
    }

    criarTabelaEstoque(dados) {
        if (!Array.isArray(dados) || dados.length === 0) {
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
                    <td>${item.nome || item.nome_produto || 'N/A'}</td>
                    <td>${item.categoria || 'N/A'}</td>
                    <td class="destaque-perda">${item.diferenca_estoque || 0}</td>
                    <td>${item.total_entradas || 0}</td>
                    <td>${item.total_vendido || 0}</td>
                    <td>${item.estoque_atual || 0}</td>
                    </tr>`;
        });

        html += `</tbody></table></div>`;
        return html;
    }

    formatarMoeda(valor) {
        const numero = parseFloat(valor) || 0;
        return new Intl.NumberFormat('pt-BR', {
            style: 'currency',
            currency: 'BRL'
        }).format(numero);
    }

    exportarRelatorio() {
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
    
    formatarData(data) {
    return new Date(data + 'T00:00:00').toLocaleDateString('pt-BR');
}
}



// Inicializar relatórios
const relatorios = new Relatorios();

// CSS adicional para a análise de estoque
const style = document.createElement('style');
style.textContent = `
.periodo-info {
    background: #e3f2fd;
    padding: 10px 15px;
    border-radius: 5px;
    margin-bottom: 15px;
    border-left: 4px solid #2196f3;
}

.totais-analise {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
    gap: 15px;
    margin-bottom: 20px;
}

.total-item {
    background: white;
    padding: 15px;
    border-radius: 8px;
    text-align: center;
    border-left: 4px solid #4caf50;
}

.total-item .total-label {
    display: block;
    font-size: 0.9em;
    color: #666;
    margin-bottom: 5px;
}

.total-item .total-value {
    display: block;
    font-size: 1.4em;
    font-weight: bold;
    color: #2c3e50;
}

.total-item .total-value.alerta {
    color: #e74c3c;
}

.analise-estoque-table {
    font-size: 0.9em;
}

.analise-estoque-table th {
    background: #34495e;
    color: white;
    position: sticky;
    top: 0;
}

.perda-destaque {
    background: #fff5f5 !important;
    font-weight: bold;
}

.sem-perda {
    background: #f0fff4 !important;
}

.destaque-perda {
    color: #e74c3c;
    font-weight: bold;
}

.legenda-analise {
    display: flex;
    gap: 20px;
    margin-top: 15px;
    justify-content: center;
}

.legenda-item {
    display: flex;
    align-items: center;
    gap: 8px;
}

.legenda-cor {
    width: 20px;
    height: 20px;
    border-radius: 3px;
}

.legenda-cor.perda-destaque {
    background: #fff5f5;
    border: 2px solid #f8d7da;
}

.legenda-cor.sem-perda {
    background: #f0fff4;
    border: 2px solid #d1f7d1;
}
`;
document.head.appendChild(style);

// Funções globais para os botões HTML
function gerarRelatorio() {
    relatorios.gerarRelatorio();
}

function exportarRelatorio() {
    relatorios.exportarRelatorio();
}