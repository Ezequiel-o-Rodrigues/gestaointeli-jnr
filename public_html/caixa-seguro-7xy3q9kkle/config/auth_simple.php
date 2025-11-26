<?php
// Versão simplificada do auth.php para teste

// Configurações básicas de sessão
session_name('gestaointeli_sessao');

// Configurações simples para localhost
ini_set('session.cookie_lifetime', 0); // Até fechar o navegador
ini_set('session.gc_maxlifetime', 28800); // 8 horas
ini_set('session.cookie_secure', '0'); // HTTP para localhost
ini_set('session.cookie_httponly', '1'); // Segurança básica

// Iniciar sessão
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

// Log básico
error_log("AUTH_SIMPLE: Sessão iniciada - ID: " . session_id());
error_log("AUTH_SIMPLE: Dados da sessão: " . print_r($_SESSION, true));

// Verificação simples de expiração (apenas se usuário logado)
if (isset($_SESSION['usuario_logado']) && $_SESSION['usuario_logado'] === true) {
    // Atualizar atividade
    $_SESSION['last_activity'] = time();
    error_log("AUTH_SIMPLE: Usuário logado - " . ($_SESSION['usuario_nome'] ?? 'desconhecido'));
}
?>