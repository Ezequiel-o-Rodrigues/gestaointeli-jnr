#!/bin/bash
# =============================================================================
# 📋 GUIA DE EXECUÇÃO DO SCRIPT SQL
# =============================================================================
# Arquivo: EXECUCAO_SCRIPT_SQL.md
# Data: 2025-12-12
# Descrição: Instruções práticas para executar o script no banco de dados
# =============================================================================

# OPÇÃO 1: Executar via linha de comando (RECOMENDADO)
# =============================================================================

# Passo 1: Abra o terminal/PowerShell no diretório do projeto
# Passo 2: Execute o comando abaixo (substitua as credenciais)

mysql -h localhost -u root -p gestaointeli_db < database/12_implementar_modal_alertas_perdas.sql

# Se o banco tiver outro nome, use:
mysql -h localhost -u root -p seu_banco_name < database/12_implementar_modal_alertas_perdas.sql

# Sem senha (se não tiver):
mysql -h localhost -u root gestaointeli_db < database/12_implementar_modal_alertas_perdas.sql


# OPÇÃO 2: Executar via phpMyAdmin
# =============================================================================
# 1. Acesse http://localhost/phpmyadmin
# 2. Conecte ao banco de dados
# 3. Clique em "SQL" no topo
# 4. Cole o conteúdo do arquivo 12_implementar_modal_alertas_perdas.sql
# 5. Clique em "Executar" (botão azul)


# OPÇÃO 3: Executar via ferramenta DBeaver ou similar
# =============================================================================
# 1. Abra a ferramenta de gerenciamento de BD
# 2. Conecte ao banco de dados
# 3. Abra a aba "SQL Editor"
# 4. Abra o arquivo: database/12_implementar_modal_alertas_perdas.sql
# 5. Pressione Ctrl+Enter para executar


# VERIFICAÇÃO PÓS-EXECUÇÃO
# =============================================================================

# Verifique se tudo foi criado corretamente:

mysql -h localhost -u root -p gestaointeli_db -e "
-- Verificar if procedure foi criada
SHOW PROCEDURE STATUS WHERE Name = 'relatorio_analise_estoque_periodo_com_filtro_perdas';

-- Verificar se funções foram criadas
SHOW FUNCTION STATUS WHERE Name LIKE '%perdas%';

-- Verificar se views foram criadas
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'gestaointeli_db' AND TABLE_NAME LIKE '%perdas%';
"


# ROLLBACK (Se algo der errado)
# =============================================================================

# Caso precise desfazer, execute:
mysql -h localhost -u root -p gestaointeli_db << 'EOF'

-- Deletar procedimento
DROP PROCEDURE IF EXISTS relatorio_analise_estoque_periodo_com_filtro_perdas;

-- Deletar funções
DROP FUNCTION IF EXISTS fn_contar_perdas_nao_visualizadas;
DROP FUNCTION IF EXISTS fn_somar_valor_perdas_nao_visualizadas;

-- Deletar views
DROP VIEW IF EXISTS vw_alertas_perdas_nao_visualizadas;
DROP VIEW IF EXISTS vw_historico_todas_perdas;

-- Deletar triggers
DROP TRIGGER IF EXISTS tr_perdas_visualizada;

-- Deletar tabela de log
DROP TABLE IF EXISTS log_auditoria_perdas;

-- Remover colunas adicionadas
ALTER TABLE perdas_estoque DROP COLUMN IF EXISTS estoque_esperado;
ALTER TABLE perdas_estoque DROP COLUMN IF EXISTS estoque_real;
ALTER TABLE perdas_estoque DROP COLUMN IF EXISTS observacoes;

EOF


# SCRIPT WINDOWS (PowerShell)
# =============================================================================

# Se estiver usando Windows PowerShell:

$mysqlPath = "C:\xampp\mysql\bin\mysql.exe"  # Ajuste o caminho se necessário
$dbUser = "root"
$dbPass = ""  # Deixe vazio se não tiver senha
$dbName = "gestaointeli_db"
$scriptFile = "database\12_implementar_modal_alertas_perdas.sql"

# Execute:
& $mysqlPath -h localhost -u $dbUser -p$dbPass $dbName < $scriptFile

# Ou se tiver senha:
# & $mysqlPath -h localhost -u $dbUser -p"sua_senha" $dbName < $scriptFile


# VERIFICAÇÃO DE SUCESSO
# =============================================================================

echo "✅ Se você viu as tabelas de resultados acima, a execução foi bem-sucedida!"

echo ""
echo "Próximos passos:"
echo "1. Verifique se a API '/api/perdas_nao_visualizadas.php' existe"
echo "2. Verifique se a API '/api/marcar_perda_visualizada.php' foi atualizada"
echo "3. Teste o modal abrindo Relatórios no navegador"
echo "4. Clique no card 'Perdas Identificadas' para abrir o modal"

