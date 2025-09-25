// Funções globais do sistema
class SistemaRestaurante {
    constructor() {
        this.comandaAtual = null;
        this.init();
    }

    init() {
        this.carregarComandaAberta();
        this.configurarEventListeners();
    }

    carregarComandaAberta() {
        // Verificar se existe comanda aberta
        fetch('api/comanda_aberta.php')
            .then(response => response.json())
            .then(data => {
                if (data.comanda) {
                    this.comandaAtual = data.comanda;
                    this.atualizarInterfaceComanda();
                }
            });
    }

    configurarEventListeners() {
        // Event listeners globais
        document.addEventListener('keydown', this.handleKeyboard.bind(this));
    }

    handleKeyboard(event) {
        // Atalhos de teclado
        if (event.ctrlKey) {
            switch(event.key) {
                case 'n':
                    event.preventDefault();
                    this.novaComanda();
                    break;
                case 'f':
                    event.preventDefault();
                    this.finalizarComanda();
                    break;
            }
        }
    }

    formatarMoeda(valor) {
        return new Intl.NumberFormat('pt-BR', {
            style: 'currency',
            currency: 'BRL'
        }).format(valor);
    }

    mostrarNotificacao(mensagem, tipo = 'info') {
        // Implementar sistema de notificações
        console.log(`${tipo.toUpperCase()}: ${mensagem}`);
    }
}

// Inicializar sistema quando DOM estiver pronto
document.addEventListener('DOMContentLoaded', function() {
    window.sistema = new SistemaRestaurante();
});