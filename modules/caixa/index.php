<?php
require_once '../../config/database.php';
require_once '../../includes/functions.php';
require_once '../../includes/header.php';

$categorias = getCategorias();
?>

<div class="caixa-container">
    <div class="caixa-header">
        <h2>💰 Sistema de Caixa</h2>
        <div class="comanda-info">
            <span id="numero-comanda">Comanda: --</span>
            <button class="btn btn-primary" onclick="novaComanda()">Nova Comanda</button>
        </div>
    </div>

    <div class="caixa-content">
        <div class="categorias-section">
            <h3>Categorias de Produtos</h3>
            <div class="categorias-grid" id="categorias-grid">
                <?php foreach($categorias as $categoria): ?>
                <div class="categoria-card" onclick="carregarProdutos(<?= $categoria['id'] ?>)">
                    <h4><?= htmlspecialchars($categoria['nome']) ?></h4>
                    <p><?= htmlspecialchars($categoria['descricao']) ?></p>
                </div>
                <?php endforeach; ?>
            </div>
        </div>

        <div class="produtos-section" id="produtos-section" style="display: none;">
            <h3>Produtos da Categoria</h3>
            <div class="produtos-grid" id="produtos-grid"></div>
            <button class="btn" onclick="voltarCategorias()">← Voltar</button>
        </div>

        <div class="comanda-section">
            <h3>Comanda Atual</h3>
            <div class="itens-comanda" id="itens-comanda">
                <p class="empty-message">Nenhum item adicionado</p>
            </div>
            <div class="total-section">
                <div class="totais">
                    <div>Subtotal: <span id="subtotal">R$ 0,00</span></div>
                    <div>Taxa: <span id="taxa">R$ 0,00</span></div>
                    <div><strong>Total: <span id="total">R$ 0,00</span></strong></div>
                </div>
                <button class="btn btn-success" onclick="finalizarComanda()" disabled id="btn-finalizar">
                    Finalizar Venda
                </button>
            </div>
        </div>
    </div>
</div>

<script src="caixa.js"></script>

<?php require_once '../../includes/footer.php'; ?>