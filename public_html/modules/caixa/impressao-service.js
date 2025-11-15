// modules/caixa/impressao-service.js
class ImpressaoService {
    constructor() {
        this.device = null;
        this.vendorId = 0x0416; // ID comum para impressoras térmicas
        this.productId = 0x5011; // Ajuste conforme sua impressora
    }

    // Verificar se Web USB é suportado
    isSupported() {
        return navigator.usb && typeof navigator.usb.requestDevice === 'function';
    }

    // Conectar à impressora
    async conectarImpressora() {
        try {
            if (!this.isSupported()) {
                throw new Error('Web USB não é suportado neste navegador');
            }

            // Solicitar dispositivo
            this.device = await navigator.usb.requestDevice({
                filters: [
                    { vendorId: this.vendorId, productId: this.productId },
                    { vendorId: 0x067B }, // Prolific
                    { vendorId: 0x04B8 }, // Epson
                    { vendorId: 0x0FE6 }  // STMicroelectronics
                ]
            });

            console.log('Dispositivo selecionado:', this.device);

            // Abrir conexão
            await this.device.open();
            
            // Selecionar configuração
            if (this.device.configuration === null) {
                await this.device.selectConfiguration(1);
            }
            
            // Claim interface
            await this.device.claimInterface(0);

            console.log('Impressora conectada com sucesso!');
            return true;

        } catch (error) {
            console.error('Erro ao conectar impressora:', error);
            
            if (error.name === 'NotFoundError') {
                throw new Error('Nenhuma impressora encontrada. Verifique a conexão USB.');
            } else if (error.name === 'SecurityError') {
                throw new Error('Permissão negada para acessar a impressora.');
            } else {
                throw new Error('Erro de conexão: ' + error.message);
            }
        }
    }

    // Enviar dados para impressão
    async imprimir(texto) {
        try {
            if (!this.device) {
                throw new Error('Impressora não conectada');
            }

            // Converter texto para ArrayBuffer com codificação correta
            const encoder = new TextEncoder();
            const data = encoder.encode(texto);

            console.log('Enviando dados para impressão:', data);

            // Enviar dados (endpoint 0x02 é comum para impressão)
            const result = await this.device.transferOut(2, data);
            
            console.log('Dados enviados com sucesso:', result);
            return true;

        } catch (error) {
            console.error('Erro na impressão:', error);
            throw new Error('Falha na impressão: ' + error.message);
        }
    }

    // Desconectar impressora
    async desconectar() {
        try {
            if (this.device) {
                await this.device.close();
                this.device = null;
                console.log('Impressora desconectada');
            }
        } catch (error) {
            console.error('Erro ao desconectar:', error);
        }
    }

    // Método completo: conectar + imprimir
    async imprimirComprovante(conteudo) {
        try {
            // Tentar usar dispositivo já conectado
            if (!this.device) {
                await this.conectarImpressora();
            }

            await this.imprimir(conteudo);
            return { success: true, message: 'Comprovante impresso com sucesso' };

        } catch (error) {
            console.error('Erro no processo de impressão:', error);
            return { 
                success: false, 
                message: error.message,
                needsConnection: error.message.includes('não conectada') || error.message.includes('encontrada')
            };
        }
    }
}

// Instância global
window.impressaoService = new ImpressaoService();