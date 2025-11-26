<?php
// Arquivo de debug completo para identificar o problema de sessão

echo "<h1>🔍 Debug Completo de Sessão</h1>";

// 1. Verificar configurações PHP antes de iniciar sessão
echo "<h2>1. Configurações PHP (antes da sessão)</h2>";
echo "<ul>";
echo "<li>session.cookie_lifetime: " . ini_get('session.cookie_lifetime') . "</li>";
echo "<li>session.gc_maxlifetime: " . ini_get('session.gc_maxlifetime') . "</li>";
echo "<li>session.cookie_secure: " . ini_get('session.cookie_secure') . "</li>";
echo "<li>session.cookie_httponly: " . ini_get('session.cookie_httponly') . "</li>";
echo "<li>session.use_strict_mode: " . ini_get('session.use_strict_mode') . "</li>";
echo "<li>session.cookie_samesite: " . ini_get('session.cookie_samesite') . "</li>";
echo "</ul>";

// 2. Incluir auth.php e verificar o que acontece
echo "<h2>2. Incluindo auth.php...</h2>";
ob_start();
require_once __DIR__ . '/config/auth.php';
$auth_output = ob_get_clean();

if ($auth_output) {
    echo "<p><strong>Output do auth.php:</strong></p>";
    echo "<pre>" . htmlspecialchars($auth_output) . "</pre>";
} else {
    echo "<p>✅ auth.php incluído sem output</p>";
}

// 3. Verificar estado da sessão após auth.php
echo "<h2>3. Estado da Sessão (após auth.php)</h2>";
echo "<ul>";
echo "<li><strong>Session ID:</strong> " . session_id() . "</li>";
echo "<li><strong>Session Status:</strong> " . session_status() . "</li>";
echo "<li><strong>Session Name:</strong> " . session_name() . "</li>";
echo "</ul>";

// 4. Dados da sessão
echo "<h2>4. Dados da Sessão</h2>";
if (empty($_SESSION)) {
    echo "<p>❌ Sessão está vazia</p>";
} else {
    echo "<pre>";
    print_r($_SESSION);
    echo "</pre>";
}

// 5. Verificações específicas
echo "<h2>5. Verificações Específicas</h2>";
echo "<ul>";
echo "<li>usuario_logado existe: " . (isset($_SESSION['usuario_logado']) ? 'SIM' : 'NÃO') . "</li>";
echo "<li>usuario_logado valor: " . (isset($_SESSION['usuario_logado']) ? var_export($_SESSION['usuario_logado'], true) : 'N/A') . "</li>";
echo "<li>usuario_logado === true: " . (isset($_SESSION['usuario_logado']) && $_SESSION['usuario_logado'] === true ? 'SIM' : 'NÃO') . "</li>";
echo "<li>usuario_nome: " . ($_SESSION['usuario_nome'] ?? 'NÃO DEFINIDO') . "</li>";
echo "<li>last_activity: " . (isset($_SESSION['last_activity']) ? date('Y-m-d H:i:s', $_SESSION['last_activity']) : 'NÃO DEFINIDO') . "</li>";
echo "</ul>";

// 6. Cookies
echo "<h2>6. Cookies</h2>";
if (empty($_COOKIE)) {
    echo "<p>❌ Nenhum cookie encontrado</p>";
} else {
    echo "<pre>";
    print_r($_COOKIE);
    echo "</pre>";
}

// 7. Headers enviados
echo "<h2>7. Headers</h2>";
if (headers_sent($file, $line)) {
    echo "<p>⚠️ Headers já enviados em $file linha $line</p>";
} else {
    echo "<p>✅ Headers ainda não enviados</p>";
}

// 8. Teste de escrita na sessão
echo "<h2>8. Teste de Escrita na Sessão</h2>";
$_SESSION['teste_debug'] = 'valor_teste_' . time();
echo "<p>Valor escrito: " . $_SESSION['teste_debug'] . "</p>";

// 9. Informações do servidor
echo "<h2>9. Informações do Servidor</h2>";
echo "<ul>";
echo "<li>PHP Version: " . PHP_VERSION . "</li>";
echo "<li>Server Software: " . ($_SERVER['SERVER_SOFTWARE'] ?? 'N/A') . "</li>";
echo "<li>Document Root: " . ($_SERVER['DOCUMENT_ROOT'] ?? 'N/A') . "</li>";
echo "<li>Script Name: " . ($_SERVER['SCRIPT_NAME'] ?? 'N/A') . "</li>";
echo "<li>Request URI: " . ($_SERVER['REQUEST_URI'] ?? 'N/A') . "</li>";
echo "<li>HTTP Host: " . ($_SERVER['HTTP_HOST'] ?? 'N/A') . "</li>";
echo "</ul>";

// 10. Simular login
echo "<h2>10. Simular Login</h2>";
if (isset($_GET['simular_login'])) {
    $_SESSION['usuario_logado'] = true;
    $_SESSION['usuario_nome'] = 'Teste Debug';
    $_SESSION['usuario_email'] = 'debug@teste.com';
    $_SESSION['usuario_perfil'] = 'admin';
    $_SESSION['last_activity'] = time();
    
    echo "<p>✅ Login simulado! <a href='?'>Recarregar página</a></p>";
} else {
    echo "<p><a href='?simular_login=1'>🔗 Simular Login</a></p>";
}

echo "<hr>";
echo "<p><a href='login.php'>← Login</a> | <a href='index.php'>Index</a> | <a href='test_session.php'>Teste Simples</a></p>";
?>