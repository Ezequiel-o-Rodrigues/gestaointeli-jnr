// 📁 js/path-config.js
class PathConfig {
    static getBasePath() {
        // Configuração fixa para localhost XAMPP
        return '/gestaointeli-jnr/public_html/caixa-seguro-7xy3q9kkle';
    }

    static url(path = '') {
        const base = this.getBasePath();
        return `${base}/${path.replace(/^\//, '')}`;
    }

    static api(endpoint = '') {
        return this.url(`api/${endpoint}`);
    }

    static modules(module = '') {
        return this.url(`modules/${module}`);
    }

    static assets(path = '') {
        return this.url(`assets/${path}`);
    }
}

// Exemplos de uso:
// PathConfig.api('comanda_aberta.php')
// PathConfig.modules('estoque/script.js')
// PathConfig.assets('css/style.css')