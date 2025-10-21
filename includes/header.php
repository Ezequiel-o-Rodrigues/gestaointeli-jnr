<?php
require_once __DIR__ . '/../config/paths.php';
?>
<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Sistema Restaurante</title>
    
    <!-- ✅ Bootstrap via CDN (solução mais simples) -->
    <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.0/dist/css/bootstrap.min.css" rel="stylesheet">
    
    <!-- ✅ CSS personalizado - se existir na raiz -->
    <?php if (file_exists(__DIR__ . '/../css/style.css')): ?>
        <link rel="stylesheet" href="<?= PathConfig::url('css/style.css') ?>">
    <?php elseif (file_exists(__DIR__ . '/../style.css')): ?>
        <link rel="stylesheet" href="<?= PathConfig::url('style.css') ?>">
    <?php else: ?>
        <style>
            /* Estilos básicos de fallback */
            body { 
                font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
                margin: 0; 
                padding: 0;
                background-color: #f8f9fa;
            }
            .header { 
                background: #343a40; 
                padding: 1rem; 
                color: white; 
            }
            .header h1 { margin: 0; }
            .main-nav a { 
                color: white; 
                margin-right: 20px; 
                text-decoration: none;
                font-weight: 500;
            }
            .main-nav a:hover { text-decoration: underline; }
            .container { max-width: 1200px; margin: 0 auto; padding: 20px; }
            .footer { background: #343a40; color: white; padding: 1rem; text-align: center; margin-top: 2rem; }
        </style>
    <?php endif; ?>
    
    <script>
        const BASE_URL = '<?= PathConfig::url() ?>';
        const API_BASE = '<?= PathConfig::api() ?>';
    </script>
    
    <!-- ✅ Path Config JS - se existir -->
    <?php if (file_exists(__DIR__ . '/../js/path-config.js')): ?>
        <script src="<?= PathConfig::url('js/path-config.js') ?>"></script>
    <?php endif; ?>
</head>
<body>
    <header class="header">
        <div class="container">
            <h1>🍽️ Sistema Restaurante</h1>
            <nav class="main-nav">
                <a href="<?= PathConfig::url() ?>">🏠 Início</a>
                <a href="<?= PathConfig::modules('caixa/') ?>">💰 Caixa</a>
                <a href="<?= PathConfig::modules('estoque/') ?>">📦 Estoque</a>
                <a href="<?= PathConfig::modules('relatorios/') ?>">📊 Relatórios</a>
                <a href="<?= PathConfig::modules('admin/') ?>">⚙️ Admin</a>
            </nav>
        </div>
    </header>
    <main class="container">