<?php
// Configurações básicas de sessão - versão corrigida
session_name('gestaointeli_sessao');

// Configuração para localhost XAMPP
ini_set('session.cookie_lifetime', 28800); // 8 horas
ini_set('session.gc_maxlifetime', 28800);
ini_set('session.cookie_secure', '0'); // HTTP para localhost
ini_set('session.cookie_httponly', '1'); // Segurança
ini_set('session.use_strict_mode', '1');

// Configurar parâmetros do cookie
session_set_cookie_params([
    'lifetime' => 28800,
    'path' => '/',
    'domain' => '',
    'secure' => false, // HTTP para localhost
    'httponly' => true,
    'samesite' => 'Lax'
]);

// Iniciar sessão
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

// DEBUG: Log da sessão
error_log("Sessão iniciada: " . session_id());
error_log("Dados da sessão: " . print_r($_SESSION, true));

// Verificar se a sessão expirou (apenas se usuário estiver logado)
if (isset($_SESSION['usuario_logado']) && $_SESSION['usuario_logado'] === true) {
    // Verificar expiração apenas se last_activity existir
    if (isset($_SESSION['last_activity'])) {
        $tempo_inativo = time() - $_SESSION['last_activity'];
        
        // Se passou mais de 8 horas (28800 segundos)
        if ($tempo_inativo > 28800) {
            error_log("Sessão expirada - tempo inativo: " . $tempo_inativo . " segundos");
            
            // Limpar sessão
            $_SESSION = array();
            session_destroy();
            
            // Se não está na página de login, redirecionar
            if (basename($_SERVER['PHP_SELF']) !== 'login.php') {
                header('Location: /gestaointeli-jnr/public_html/caixa-seguro-7xy3q9kkle/login.php?expired=1');
                exit;
            }
        } else {
            // Atualizar timestamp da última atividade
            $_SESSION['last_activity'] = time();
            error_log("Atividade atualizada para usuário: " . ($_SESSION['usuario_nome'] ?? 'desconhecido'));
        }
    } else {
        // Se não tem last_activity, definir agora
        $_SESSION['last_activity'] = time();
        error_log("Definindo last_activity inicial para usuário: " . ($_SESSION['usuario_nome'] ?? 'desconhecido'));
    }
}
?>