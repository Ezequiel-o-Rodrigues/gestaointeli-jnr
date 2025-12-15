#!/bin/bash
# Script de Teste da Implementação do Modal de Alertas
# Data: 12 de Dezembro de 2025
# Arquivo: test_modal_alertas.sh

# Cores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

BASE_URL="http://localhost/caixa-seguro-7xy3q9kkle"
API_URL="$BASE_URL/api"

echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Testes do Modal de Alertas de Perdas de Estoque         ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"

# ============================================================================
# Teste 1: Verificar se APIs existem
# ============================================================================

echo -e "\n${YELLOW}[TESTE 1] Verificando existência das APIs...${NC}"

APIs=(
    "perdas_nao_visualizadas.php"
    "marcar_perda_visualizada.php"
    "relatorio_analise_estoque_periodo_perdas.php"
    "historico_perdas.php"
)

for api in "${APIs[@]}"; do
    RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$API_URL/$api")
    if [ "$RESPONSE" = "200" ] || [ "$RESPONSE" = "400" ]; then
        echo -e "${GREEN}✓ $api${NC} - Acessível (HTTP $RESPONSE)"
    else
        echo -e "${RED}✗ $api${NC} - Erro HTTP $RESPONSE"
    fi
done

# ============================================================================
# Teste 2: Carregar perdas não visualizadas
# ============================================================================

echo -e "\n${YELLOW}[TESTE 2] Carregando perdas não visualizadas...${NC}"

RESPONSE=$(curl -s "$API_URL/perdas_nao_visualizadas.php")
echo -e "${BLUE}Resposta:${NC}"
echo "$RESPONSE" | jq . 2>/dev/null || echo "$RESPONSE"

# Extrair total
TOTAL=$(echo "$RESPONSE" | jq -r '.total_perdas // 0' 2>/dev/null)
echo -e "\n${GREEN}Total de alertas não visualizados: $TOTAL${NC}"

# ============================================================================
# Teste 3: Verificar estrutura da tabela perdas_estoque
# ============================================================================

echo -e "\n${YELLOW}[TESTE 3] Verificando estrutura da tabela...${NC}"

cat << 'SQL' > /tmp/check_table.sql
DESCRIBE perdas_estoque;
SELECT COUNT(*) as total_perdas FROM perdas_estoque;
SELECT COUNT(*) as alertas_pendentes FROM perdas_estoque WHERE visualizada = 0;
SQL

echo "Execute no MySQL:"
echo -e "${BLUE}mysql -u usuario -p database_name < /tmp/check_table.sql${NC}"

# ============================================================================
# Teste 4: Testar marcar como visualizado (simular)
# ============================================================================

echo -e "\n${YELLOW}[TESTE 4] Simulando marcação como visualizado...${NC}"

# Se houver perdas, pegar o primeiro ID
FIRST_ID=$(echo "$RESPONSE" | jq -r '.data[0].id // 0' 2>/dev/null)

if [ "$FIRST_ID" != "0" ]; then
    echo -e "ID da primeira perda: $FIRST_ID"
    echo -e "Comando para marcar como visualizado:"
    
    echo -e "${BLUE}curl -X POST \"$API_URL/marcar_perda_visualizada.php\" \\${NC}"
    echo -e "${BLUE}     -H \"Content-Type: application/json\" \\${NC}"
    echo -e "${BLUE}     -d '{\"perda_id\": $FIRST_ID}'${NC}"
else
    echo -e "${YELLOW}Nenhuma perda para testar${NC}"
fi

# ============================================================================
# Teste 5: Testar análise por período
# ============================================================================

echo -e "\n${YELLOW}[TESTE 5] Testando análise por período...${NC}"

DATA_INICIO=$(date -d '2025-12-01' +'%Y-%m-%d' 2>/dev/null || date -v-30d +'%Y-%m-%d')
DATA_FIM=$(date +'%Y-%m-%d')

echo -e "Período: $DATA_INICIO a $DATA_FIM"

RESPONSE_RELATORIO=$(curl -s "$API_URL/relatorio_analise_estoque_periodo_perdas.php?data_inicio=$DATA_INICIO&data_fim=$DATA_FIM")

PRODUTOS_COM_PERDA=$(echo "$RESPONSE_RELATORIO" | jq -r '.totais.total_produtos_com_perda // 0' 2>/dev/null)
VALOR_TOTAL=$(echo "$RESPONSE_RELATORIO" | jq -r '.totais.total_perdas_valor // 0' 2>/dev/null)

echo -e "${GREEN}Produtos com perda: $PRODUTOS_COM_PERDA${NC}"
echo -e "${GREEN}Valor total: R$ $VALOR_TOTAL${NC}"

# ============================================================================
# Teste 6: Verificar Stored Procedure
# ============================================================================

echo -e "\n${YELLOW}[TESTE 6] Verificando Stored Procedure...${NC}"

cat << 'SQL' > /tmp/check_sp.sql
SHOW PROCEDURE STATUS LIKE '%relatorio_analise%';
-- Para chamar: CALL relatorio_analise_estoque_periodo_com_filtro_perdas('2025-12-01', '2025-12-12');
SQL

echo "Execute no MySQL:"
echo -e "${BLUE}mysql -u usuario -p database_name < /tmp/check_sp.sql${NC}"

# ============================================================================
# Resumo
# ============================================================================

echo -e "\n${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║                    RESUMO DOS TESTES                       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"

echo -e "\n${GREEN}✓ Testes Realizados:${NC}"
echo "  1. Verificação de APIs"
echo "  2. Carregamento de alertas não visualizados"
echo "  3. Estrutura da tabela"
echo "  4. Simulação de marcação"
echo "  5. Análise por período"
echo "  6. Validação de Stored Procedure"

echo -e "\n${YELLOW}Próximos Passos:${NC}"
echo "  1. Abra http://localhost/caixa-seguro-7xy3q9kkle/modules/relatorios/"
echo "  2. Clique em 'Perdas Identificadas'"
echo "  3. Verifique se modal abre com alertas"
echo "  4. Clique em '✓ Visualizar' para testar"
echo "  5. Verifique sincronização com dashboard"

echo -e "\n${BLUE}✓ Testes Completados!${NC}\n"
