# 🏠 SISTEMA CONFIGURADO PARA LOCALHOST XAMPP

## 📁 **Estrutura Local:**
```
c:\xampp\htdocs\
└── gestaointeli-jnr\
    └── public_html\
        └── caixa-seguro-7xy3q9kkle\
            ├── index.php
            ├── login.php
            ├── api/
            ├── config/
            ├── modules/
            └── ...
```

## 🔧 **Arquivos Alterados para Localhost:**

### 1. **config/paths.php**
- ✅ BASE_URL: `/gestaointeli-jnr/public_html/caixa-seguro-7xy3q9kkle`

### 2. **js/path-config.js**
- ✅ getBasePath(): retorna caminho fixo para localhost

### 3. **login.php**
- ✅ Redirecionamentos: `/gestaointeli-jnr/public_html/caixa-seguro-7xy3q9kkle/`

### 4. **config/auth.php**
- ✅ Sessão expirada: caminho completo localhost
- ✅ secure: false (HTTP para localhost)

### 5. **modules/caixa/index.php**
- ✅ base_path: `/gestaointeli-jnr/public_html/caixa-seguro-7xy3q9kkle/`

### 6. **modules/estoque/index.php**
- ✅ Script paths: caminhos completos para localhost

## 🚀 **URLs de Acesso Localhost:**
- **Login:** `http://localhost/gestaointeli-jnr/public_html/caixa-seguro-7xy3q9kkle/login.php`
- **Sistema:** `http://localhost/gestaointeli-jnr/public_html/caixa-seguro-7xy3q9kkle/`
- **API:** `http://localhost/gestaointeli-jnr/public_html/caixa-seguro-7xy3q9kkle/api/`

## ⚙️ **Configurações XAMPP:**
1. **Apache** deve estar rodando
2. **MySQL** deve estar rodando
3. **Banco de dados** configurado em `config/database.php`

## 🔄 **Para voltar ao subdomínio:**
1. Restaurar `config/paths.php` com BASE_URL vazio
2. Restaurar `js/path-config.js` com detecção automática
3. Ajustar redirecionamentos nos arquivos PHP

**✅ SISTEMA ADAPTADO PARA LOCALHOST XAMPP!**