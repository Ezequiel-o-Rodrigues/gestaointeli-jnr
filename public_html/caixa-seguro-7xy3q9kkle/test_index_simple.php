<?php
require_once __DIR__ . '/config/auth_simple.php';

echo "<h1>🏠 Index de Teste Simplificado</h1>";

// Verificar se está logado
if (!isset($_SESSION['usuario_logado']) || $_SESSION['usuario_logado'] !== true) {
    echo "<p>❌ Usuário não está logado!</p>";
    echo "<p><a href='test_login_simple.php'>Fazer Login</a></p>";
    exit;
}

echo "<div style='background: #d4edda; padding: 15px; border-radius: 5px; margin: 20px 0;'>";
echo "<h3>✅ Usuário logado com sucesso!</h3>";
echo "<p><strong>Nome:</strong> " . ($_SESSION['usuario_nome'] ?? 'N/A') . "</p>";
echo "<p><strong>Email:</strong> " . ($_SESSION['usuario_email'] ?? 'N/A') . "</p>";
echo "<p><strong>Perfil:</strong> " . ($_SESSION['usuario_perfil'] ?? 'N/A') . "</p>";
echo "<p><strong>Última Atividade:</strong> " . (isset($_SESSION['last_activity']) ? date('Y-m-d H:i:s', $_SESSION['last_activity']) : 'N/A') . "</p>";
echo "</div>";

echo "<h3>Navegação de Teste</h3>";
echo "<ul>";
echo "<li><a href='modules/caixa/'>Módulo Caixa</a></li>";
echo "<li><a href='test_login_simple.php?logout=1'>Fazer Logout</a></li>";
echo "<li><a href='debug_session.php'>Debug da Sessão</a></li>";
echo "</ul>";

// Simular algumas operações
echo "<h3>Teste de Persistência da Sessão</h3>";
echo "<p>Recarregue esta página várias vezes para verificar se a sessão persiste.</p>";
echo "<p><a href='?'>🔄 Recarregar Página</a></p>";

// Contador de recarregamentos
if (!isset($_SESSION['contador_recarregamentos'])) {
    $_SESSION['contador_recarregamentos'] = 0;
}
$_SESSION['contador_recarregamentos']++;

echo "<p><strong>Recarregamentos nesta sessão:</strong> " . $_SESSION['contador_recarregamentos'] . "</p>";
?>