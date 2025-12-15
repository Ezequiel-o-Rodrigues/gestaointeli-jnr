<?php
// Verificar se o usuário está logado para mostrar informações adicionais
$usuarioLogado = isset($_SESSION['usuario_logado']) && $_SESSION['usuario_logado'] === true;
$current_page = basename($_SERVER['PHP_SELF']);
?>
    </main>

    <footer class="footer mt-5">
        <div class="container">
            <p>&copy; <?= date('Y') ?> Sistema Restaurante - Espetinho do Júnior</p>
            <?php if ($usuarioLogado): ?>
            <small class="text-muted">
                Usuário: <?= htmlspecialchars($_SESSION['usuario_nome'] ?? '') ?> | 
                Último acesso: <?= date('d/m/Y H:i:s') ?>
            </small>
            <?php endif; ?>
        </div>
    </footer>

    <!-- Scripts por página -->
    <script>
        // Carregar relatorios.js apenas se estivermos em página de relatórios
        const currentPath = window.location.pathname;
        if (currentPath.includes('/relatorios/')) {
            // Verificar se a classe Relatorios já existe
            if (typeof Relatorios === 'undefined') {
                const script = document.createElement('script');
                script.src = './relatorios.js?v=<?= time() ?>';
                script.onerror = function() {
                    console.error('Erro ao carregar relatorios.js');
                };
                document.head.appendChild(script);
            }
        }
    </script>
</body>
</html>