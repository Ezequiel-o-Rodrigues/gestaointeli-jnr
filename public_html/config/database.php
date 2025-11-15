<?php
class Database {
    private $host = "localhost";
    private $db_name = "u903648047_sis_restaurant";
    private $username = "u903648047_junior";
    private $password = "Ezequiel_2014"; // COLOQUE SUA SENHA AQUI
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