<?php
class Database {
    private $host = "localhost";
    private $db_name = "sistema_restaurante";
    private $username = "root";
    private $password = "";
    public $conn;

    public function getConnection() {
        $this->conn = null;
        try {
            $this->conn = new PDO("mysql:host=" . $this->host . ";dbname=" . $this->db_name, $this->username, $this->password);
            $this->conn->exec("set names utf8");
            $this->conn->setAttribute(PDO::ATTR_ERRMODE, PDO::ERRMODE_EXCEPTION);
            error_log("Conexão com banco de dados estabelecida com sucesso");
        } catch(PDOException $exception) {
            error_log("Erro de conexão: " . $exception->getMessage());
            echo "Erro de conexão: " . $exception->getMessage();
        }
        return $this->conn;
    }
}
?>