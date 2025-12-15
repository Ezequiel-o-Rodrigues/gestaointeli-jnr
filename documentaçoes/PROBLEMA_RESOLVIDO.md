# ✅ PROBLEMA RESOLVIDO!

## 🔧 **Correções Feitas:**

### 1. **login.php**
- ❌ `header('Location: /gestaointeli-jnr/');`
- ✅ `header('Location: /');`

### 2. **config/auth.php**  
- ❌ `header('Location: /gestaointeli-jnr/login.php?expired=1');`
- ✅ `header('Location: /login.php?expired=1');`

## 🎯 **Agora deve funcionar:**

1. **Login** → Redireciona para `/` (raiz do site)
2. **Sessão expirada** → Redireciona para `/login.php`
3. **Todos os caminhos** → Funcionam na raiz

## 🚀 **Teste:**
1. Acesse: `https://ezzedev.com.br/login.php`
2. Faça login
3. Deve ir para: `https://ezzedev.com.br/` (sem gestaointeli-jnr)

**PROBLEMA RESOLVIDO! 🎉**