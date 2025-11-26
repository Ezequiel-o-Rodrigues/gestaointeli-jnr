<?php
require_once __DIR__ . '/config/auth_simple.php';

echo "<h1>🧪 Teste de Login Simplificado</h1>";

// Processar login
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $email = $_POST['email'] ?? '';
    $senha = $_POST['senha'] ?? '';
    
    echo "<p>Tentando login com: $email</p>";
    
    if (!empty($email) && !empty($senha)) {
        require_once __DIR__ . '/config/database.php';
        
        try {
            $database = new Database();
            $db = $database->getConnection();
            
            $stmt = $db->prepare("SELECT id, nome, email, senha, perfil, ativo FROM usuarios WHERE email = ? AND ativo = 1");
            $stmt->execute([$email]);
            $usuario = $stmt->fetch(PDO::FETCH_ASSOC);
            
            if ($usuario && password_verify($senha, $usuario['senha'])) {
                echo "<p>✅ Senha válida!</p>";
                
                // Login bem-sucedido
                $_SESSION['usuario_id'] = $usuario['id'];
                $_SESSION['usuario_nome'] = $usuario['nome'];
                $_SESSION['usuario_email'] = $usuario['email'];
                $_SESSION['usuario_perfil'] = $usuario['perfil'];
                $_SESSION['usuario_logado'] = true;
                $_SESSION['last_activity'] = time();
                
                echo "<p>✅ Sessão criada!</p>";
                echo "<p><a href='test_index_simple.php'>Ir para Index de Teste</a></p>";
            } else {
                echo "<p>❌ Email ou senha incorretos</p>";
            }
        } catch (Exception $e) {
            echo "<p>❌ Erro: " . $e->getMessage() . "</p>";
        }
    } else {
        echo "<p>❌ Preencha todos os campos</p>";
    }
}

// Verificar se já está logado
if (isset($_SESSION['usuario_logado']) && $_SESSION['usuario_logado'] === true) {
    echo "<div style='background: #d4edda; padding: 15px; border-radius: 5px; margin: 20px 0;'>";
    echo "<h3>✅ Usuário já está logado!</h3>";
    echo "<p><strong>Nome:</strong> " . ($_SESSION['usuario_nome'] ?? 'N/A') . "</p>";
    echo "<p><strong>Email:</strong> " . ($_SESSION['usuario_email'] ?? 'N/A') . "</p>";
    echo "<p><a href='test_index_simple.php'>Ir para Index de Teste</a></p>";
    echo "<p><a href='?logout=1'>Fazer Logout</a></p>";
    echo "</div>";
}

// Processar logout
if (isset($_GET['logout'])) {
    $_SESSION = array();
    session_destroy();
    echo "<p>✅ Logout realizado! <a href='?'>Recarregar</a></p>";
}
?>

<!DOCTYPE html>
<html>
<head>
    <title>Teste Login Simplificado</title>
    <style>
        body { font-family: Arial, sans-serif; max-width: 600px; margin: 50px auto; padding: 20px; }
        form { background: #f8f9fa; padding: 20px; border-radius: 5px; }
        input { width: 100%; padding: 10px; margin: 10px 0; border: 1px solid #ddd; border-radius: 3px; }
        button { background: #007bff; color: white; padding: 10px 20px; border: none; border-radius: 3px; cursor: pointer; }
    </style>
</head>
<body>
    <form method="post">
        <h3>Login de Teste</h3>
        <input type="email" name="email" placeholder="Email" value="admin@sistema.com" required>
        <input type="password" name="senha" placeholder="Senha" value="123456" required>
        <button type="submit">Entrar</button>
    </form>
    
    <p><a href="debug_session.php">Debug Completo</a> | <a href="login.php">Login Original</a></p>
</body>
</html>