<?php
// URL base FIXA - ajuste conforme sua instalação
$base_url = '/gestaointeli-jnr/';
?>

<!DOCTYPE html>
<html lang="pt-BR">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Sistema Restaurante</title>
    <link rel="stylesheet" href="<?php echo $base_url; ?>css/style.css">
    <script src="<?php echo $base_url; ?>js/main.js"></script>
</head>
<body>
    <header class="header">
        <div class="container">
            <h1>🍽️ Sistema Restaurante</h1>
            <nav class="main-nav">
                <a href="<?php echo $base_url; ?>index.php">🏠 Início</a>
                <a href="<?php echo $base_url; ?>modules/caixa/index.php">💰 Caixa</a>
                <a href="<?php echo $base_url; ?>modules/estoque/index.php">📦 Estoque</a>
                <a href="<?php echo $base_url; ?>modules/relatorios/index.php">📊 Relatórios</a>
                <a href="<?php echo $base_url; ?>modules/admin/index.php">⚙️ Admin</a>
            </nav>
        </div>
    </header>
    <main class="container">