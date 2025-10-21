<?php
// ✅ CORRIGIDO
require_once __DIR__ . '/../config/paths.php';
require_once PathConfig::config('database.php'); 

function formatarMoeda($valor) {
    return 'R$ ' . number_format($valor, 2, ',', '.');
}

function getCategorias() {
    $database = new Database();
    $db = $database->getConnection();
    
    $query = "SELECT * FROM categorias ORDER BY nome";
    $stmt = $db->prepare($query);
    $stmt->execute();
    
    return $stmt->fetchAll(PDO::FETCH_ASSOC);
}

function getProdutosPorCategoria($categoria_id) {
    $database = new Database();
    $db = $database->getConnection();
    
    $query = "SELECT * FROM produtos WHERE categoria_id = :categoria_id AND ativo = 1 ORDER BY nome";
    $stmt = $db->prepare($query);
    $stmt->bindParam(':categoria_id', $categoria_id);
    $stmt->execute();
    
    return $stmt->fetchAll(PDO::FETCH_ASSOC);
}
?>