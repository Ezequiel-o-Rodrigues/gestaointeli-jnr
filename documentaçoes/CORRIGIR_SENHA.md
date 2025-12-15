# 🔑 CORRIGIR ERRO DE SENHA

## ❌ **Erro Atual:**
```
Access denied for user 'u903648047_junior'@'localhost' (using password: YES)
```

## 🔧 **Soluções:**

### **1. Verificar Senha no cPanel:**
1. Acesse **cPanel da Hostinger**
2. Vá em **Bancos de Dados MySQL**
3. Procure o usuário `u903648047_junior`
4. **Anote a senha correta** ou **redefina uma nova**

### **2. Atualizar database.php:**
Edite o arquivo `config/database.php` e coloque a senha correta:

```php
private $password = "SUA_SENHA_REAL_AQUI";
```

### **3. Verificar Dados:**
- **Host:** localhost ✅
- **Database:** u903648047_sis_restaurant ✅  
- **Username:** u903648047_junior ✅
- **Password:** ❌ INCORRETA

### **4. Teste Novamente:**
Após corrigir a senha, acesse:
`seusite.com/api/teste_conexao.php`

## 💡 **Dica:**
Se não souber a senha, crie uma nova no cPanel da Hostinger em "Bancos de Dados MySQL".