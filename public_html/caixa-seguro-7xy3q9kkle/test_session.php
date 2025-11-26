<?php
require_once __DIR__ . '/config/auth.php';

echo "<h2>🔍 Teste de Sessão</h2>";
echo "<p><strong>Session ID:</strong> " . session_id() . "</p>";
echo "<p><strong>Status da Sessão:</strong> " . session_status() . "</p>";
echo "<p><strong>Dados da Sessão:</strong></p>";
echo "<pre>";
print_r($_SESSION);
echo "</pre>";

echo "<h3>Verificações:</h3>";
echo "<ul>";
echo "<li>usuario_logado existe: " . (isset($_SESSION['usuario_logado']) ? 'SIM' : 'NÃO') . "</li>";
echo "<li>usuario_logado é true: " . (isset($_SESSION['usuario_logado']) && $_SESSION['usuario_logado'] === true ? 'SIM' : 'NÃO') . "</li>";
echo "<li>usuario_nome: " . ($_SESSION['usuario_nome'] ?? 'NÃO DEFINIDO') . "</li>";
echo "<li>last_activity: " . (isset($_SESSION['last_activity']) ? date('Y-m-d H:i:s', $_SESSION['last_activity']) : 'NÃO DEFINIDO') . "</li>";
echo "</ul>";

echo "<h3>Configurações PHP:</h3>";
echo "<ul>";
echo "<li>session.cookie_lifetime: " . ini_get('session.cookie_lifetime') . "</li>";
echo "<li>session.gc_maxlifetime: " . ini_get('session.gc_maxlifetime') . "</li>";
echo "<li>session.cookie_secure: " . ini_get('session.cookie_secure') . "</li>";
echo "<li>session.cookie_httponly: " . ini_get('session.cookie_httponly') . "</li>";
echo "</ul>";

echo "<p><a href='login.php'>← Voltar para Login</a> | <a href='index.php'>Ir para Index</a></p>";
?>