<?php
class PathConfig {
    // Configurações base
    const BASE_URL = '/gestaointeli-jnr';
    const BASE_DIR = __DIR__ . '/../';
    
    // URLs públicas (para navegador)
    public static function url($path = '') {
        return self::BASE_URL . '/' . ltrim($path, '/');
    }
    
    public static function api($endpoint = '') {
        return self::url('api/' . ltrim($endpoint, '/'));
    }
    
    public static function modules($module = '') {
        return self::url('modules/' . ltrim($module, '/'));
    }
    
    
    // Caminhos físicos no servidor - CORREÇÃO AQUI!
    public static function root($path = '') {
        return self::BASE_DIR . ltrim($path, '/');
    }
    
    // ✅ SEU database.php está em CONFIG/ - use este:
    public static function config($file = '') {
        return self::root('config/' . ltrim($file, '/'));
    }
    
    // ❌ REMOVA ou comente esta linha se não tem pasta includes/
    // public static function includes($file = '') {
    //     return self::root('includes/' . ltrim($file, '/'));
    // }
    
    public static function modules_dir($module = '') {
        return self::root('modules/' . ltrim($module, '/'));
    }
}

// ✅ TESTE: Verificar se está funcionando
// echo "Caminho do database: " . PathConfig::config('database.php');
?>