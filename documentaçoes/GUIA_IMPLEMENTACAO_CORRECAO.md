# 🚀 **GUIA DE IMPLEMENTAÇÃO - SISTEMA CORRIGIDO DE PERDAS**

## 📋 **PRÉ-REQUISITOS**

- [ ] Backup recente do banco de dados feito
- [ ] Acesso ao MySQL/MariaDB
- [ ] Acesso SFTP/FTP ao servidor web
- [ ] Permissões para criar/modificar tabelas e procedures
- [ ] PHP 7.4+ configurado

---

## 🔧 **ETAPA 1: EXECUÇÃO DO SCRIPT SQL**

### **Passo 1: Backup do Banco de Dados (OBRIGATÓRIO)**

```powershell
# Windows PowerShell
$datahora = Get-Date -Format "yyyyMMdd_HHmmss"
$arquivo = "backup_antes_correcao_$datahora.sql"

mysqldump -h localhost -u root -p gestaointeli_db > $arquivo

# Verificar se backup foi criado
if (Test-Path $arquivo) {
    Write-Host "✅ Backup criado: $arquivo" -ForegroundColor Green
} else {
    Write-Host "❌ Erro ao criar backup!" -ForegroundColor Red
}
```

### **Passo 2: Executar Script SQL (MÉTODO 1 - CLI)**

```powershell
# Usar MySQL CLI
mysql -h localhost -u root -p gestaointeli_db < "C:\xampp\htdocs\gestaointeli-jnr\database\13_migracao_correcao_logica_perdas.sql"

# Verificar se executou sem erros
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Script SQL executado com sucesso" -ForegroundColor Green
} else {
    Write-Host "❌ Erro ao executar script" -ForegroundColor Red
}
```

### **Passo 3: Validar Criação de Tabelas e Procedures**

```powershell
# Verificar tabela fechamento_diario_estoque
mysql -h localhost -u root -p gestaointeli_db -e "
  SHOW TABLES LIKE 'fechamento_diario_estoque';
" | Select-Object -Index 1

# Verificar procedures
mysql -h localhost -u root -p gestaointeli_db -e "
  SHOW PROCEDURE STATUS WHERE Name LIKE '%corrigido%' OR Name LIKE '%automatico%';
"
```

---

## 📁 **ETAPA 2: COPIAR ARQUIVOS PHP**

### **Passo 1: Copiar Novas APIs**

```powershell
# Caminho base
$basePath = "C:\xampp\htdocs\gestaointeli-jnr\public_html\caixa-seguro-7xy3q9kkle\api"

# Verificar se APIs existem (as antigas)
Write-Host "APIs existentes:" -ForegroundColor Cyan
Get-ChildItem "$basePath\*.php" | Select-Object Name | Format-Table

# Observação: As novas APIs serão:
# - relatorio_analise_estoque_corrigido.php (NOVA)
# - modal_historico_perdas.php (NOVA)
# - marcar_perda_visualizada_v2.php (NOVA)
```

### **Passo 2: Testar APIs**

```powershell
# Testar relatório corrigido
$url = "http://localhost/caixa-seguro-7xy3q9kkle/api/relatorio_analise_estoque_corrigido.php?data_inicio=2025-12-14&data_fim=2025-12-14"

$response = Invoke-WebRequest -Uri $url -UseBasicParsing
$content = $response.Content | ConvertFrom-Json

if ($content.success) {
    Write-Host "✅ API Relatório Corrigido: OK" -ForegroundColor Green
    Write-Host "  - Totais analisados: $($content.totais.total_produtos_analisados)" -ForegroundColor White
} else {
    Write-Host "❌ API Relatório: Erro" -ForegroundColor Red
    Write-Host "$($content.message)"
}

# Testar modal de histórico
$url2 = "http://localhost/caixa-seguro-7xy3q9kkle/api/modal_historico_perdas.php?data_inicio=2025-12-01&data_fim=2025-12-31"

$response2 = Invoke-WebRequest -Uri $url2 -UseBasicParsing
$content2 = $response2.Content | ConvertFrom-Json

if ($content2.success) {
    Write-Host "✅ API Modal Histórico: OK" -ForegroundColor Green
    Write-Host "  - Alertas: $($content2.resumo.total_alertas)" -ForegroundColor White
} else {
    Write-Host "❌ API Modal: Erro" -ForegroundColor Red
}
```

---

## 🧪 **ETAPA 3: TESTES INICIAIS**

### **Teste 1: Gerar Fechamento Diário**

```powershell
# Gerar fechamento para hoje
$dataHoje = (Get-Date).ToString("yyyy-MM-dd")

$query = "CALL gerar_fechamento_diario_automatico('$dataHoje');"

mysql -h localhost -u root -p gestaointeli_db -e $query

# Verificar se registros foram criados
Write-Host "Verificando fechamentos criados..." -ForegroundColor Cyan

$verificacao = mysql -h localhost -u root -p gestaointeli_db -e "
  SELECT COUNT(*) AS total FROM fechamento_diario_estoque 
  WHERE data_fechamento = '$dataHoje';
"

Write-Host $verificacao
```

### **Teste 2: Validar Cálculos**

```powershell
# Executar teste de cenário crítico
$dataAnterior = (Get-Date).AddDays(-1).ToString("yyyy-MM-dd")
$dataHoje = (Get-Date).ToString("yyyy-MM-dd")

# Query de validação
$query = @"
SELECT 
  produto_id,
  DATE_FORMAT(data_fechamento, '%d/%m/%Y') AS data,
  estoque_real,
  estoque_teorico,
  diferenca
FROM fechamento_diario_estoque
WHERE data_fechamento IN ('$dataAnterior', '$dataHoje')
ORDER BY produto_id, data_fechamento;
"@

mysql -h localhost -u root -p gestaointeli_db -e $query
```

### **Teste 3: Relatório de Período**

```powershell
# Chamar API de relatório corrigido
$dataInicio = "2025-12-10"
$dataFim = "2025-12-14"

$url = "http://localhost/caixa-seguro-7xy3q9kkle/api/relatorio_analise_estoque_corrigido.php?data_inicio=$dataInicio&data_fim=$dataFim"

Write-Host "Chamando: $url" -ForegroundColor Cyan

try {
    $response = Invoke-WebRequest -Uri $url -UseBasicParsing
    $data = $response.Content | ConvertFrom-Json
    
    Write-Host "✅ Sucesso!" -ForegroundColor Green
    Write-Host "  Período: $($data.periodo.data_inicio) a $($data.periodo.data_fim)" -ForegroundColor White
    Write-Host "  Produtos: $($data.totais.total_produtos_analisados)" -ForegroundColor White
    Write-Host "  Perdas: $($data.totais.total_perdas_quantidade) un / R$ $($data.totais.total_perdas_valor)" -ForegroundColor White
    
} catch {
    Write-Host "❌ Erro: $($_.Exception.Message)" -ForegroundColor Red
}
```

---

## 🔄 **ETAPA 4: INTEGRAÇÃO COM JAVASCRIPT**

### **Passo 1: Atualizar Chamadas de API**

Editar `modules/relatorios/relatorios.js`:

```javascript
// ANTIGO (comentar ou remover):
// url = '../../api/relatorio_analise_estoque.php';

// NOVO:
if (tipoRelatorio === 'analise_estoque') {
    url = '../../api/relatorio_analise_estoque_corrigido.php';  // API CORRIGIDA
}
```

### **Passo 2: Atualizar Modal**

```javascript
// ANTIGO:
// this.abrirHistoricoPerdas() // carregava dados antigos

// NOVO:
async abrirHistoricoPerdas(filtros = {}) {
    try {
        let url = '../../api/modal_historico_perdas.php';  // API NOVA
        
        const params = new URLSearchParams();
        if (filtros.data_inicio) params.append('data_inicio', filtros.data_inicio);
        if (filtros.data_fim) params.append('data_fim', filtros.data_fim);
        
        const response = await fetch(url + (params.toString() ? '?' + params.toString() : ''));
        const data = await response.json();
        
        if (data.success) {
            this.mostrarModalHistoricoPerdas(
                data.alertas.data,      // Alertas não visualizadas
                data.historico.data,    // Histórico completo
                data.periodo
            );
        }
    } catch (error) {
        console.error('Erro ao carregar modal:', error);
    }
}
```

### **Passo 3: Atualizar Marcação como Visualizada**

```javascript
// ANTIGO:
// url = '../../api/marcar_perda_visualizada.php';

// NOVO:
async marcarPerdaVisualizada(perdaId) {
    try {
        const response = await fetch('../../api/marcar_perda_visualizada_v2.php', {  // V2
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ perda_id: perdaId, usuario_id: 1 })
        });
        
        const result = await response.json();
        
        if (result.success) {
            // Remover visualmente
            let elemento = document.querySelector(`[data-alerta-id="${perdaId}"]`);
            if (elemento) {
                elemento.style.animation = 'fadeOut 0.3s ease';
                setTimeout(() => elemento.remove(), 300);
            }
            
            // Atualizar contador
            this.atualizarContadorPerdas();
            this.mostrarToast(`Perda marcada. Alertas restantes: ${result.alertas_restantes}`, 'success');
        }
    } catch (error) {
        console.error('Erro:', error);
        this.mostrarToast('Erro ao marcar perda', 'error');
    }
}
```

---

## ⚙️ **ETAPA 5: CONFIGURAÇÃO DE AUTOMAÇÃO (OPCIONAL)**

### **Configurar Fechamento Automático Diário**

**Windows Task Scheduler:**

```powershell
# Criar script PowerShell: C:\scripts\fechamento_diario.ps1
$query = "CALL gerar_fechamento_diario_automatico(CURDATE());"
mysql -h localhost -u root -p gestaointeli_db -e $query

# Agendar via Task Scheduler
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-File C:\scripts\fechamento_diario.ps1"
$trigger = New-ScheduledTaskTrigger -Daily -At 11:55PM
Register-ScheduledTask -TaskName "Fechamento_Estoque_Diario" -Action $action -Trigger $trigger
```

**Linux/CRON:**

```bash
# Adicionar ao crontab
crontab -e

# Executar diariamente às 23:55
55 23 * * * mysql -u root -p senha_aqui gestaointeli_db -e "CALL gerar_fechamento_diario_automatico(CURDATE());"
```

---

## 📊 **ETAPA 6: VALIDAÇÃO FINAL**

### **Checklist de Validação**

```powershell
Write-Host "====== VALIDAÇÃO FINAL DO SISTEMA ======" -ForegroundColor Cyan

# 1. Tabela criada?
$tabela = mysql -h localhost -u root -p gestaointeli_db -e "SHOW TABLES LIKE 'fechamento_diario_estoque';" 2>&1 | Measure-Object -Line
Write-Host "[ $(if ($tabela.Lines -gt 1) {'✅'} else {'❌'}) ] Tabela fechamento_diario_estoque" -ForegroundColor $(if ($tabela.Lines -gt 1) {'Green'} else {'Red'})

# 2. Procedure criada?
$proc = mysql -h localhost -u root -p gestaointeli_db -e "SHOW PROCEDURE STATUS LIKE '%corrigido%';" 2>&1 | Measure-Object -Line
Write-Host "[ $(if ($proc.Lines -gt 1) {'✅'} else {'❌'}) ] Procedure relatorio_corrigido" -ForegroundColor $(if ($proc.Lines -gt 1) {'Green'} else {'Red'})

# 3. APIs existem?
$api1 = Test-Path "C:\xampp\htdocs\gestaointeli-jnr\public_html\caixa-seguro-7xy3q9kkle\api\relatorio_analise_estoque_corrigido.php"
$api2 = Test-Path "C:\xampp\htdocs\gestaointeli-jnr\public_html\caixa-seguro-7xy3q9kkle\api\modal_historico_perdas.php"
$api3 = Test-Path "C:\xampp\htdocs\gestaointeli-jnr\public_html\caixa-seguro-7xy3q9kkle\api\marcar_perda_visualizada_v2.php"

Write-Host "[ $(if ($api1) {'✅'} else {'❌'}) ] API relatório_estoque_corrigido.php" -ForegroundColor $(if ($api1) {'Green'} else {'Red'})
Write-Host "[ $(if ($api2) {'✅'} else {'❌'}) ] API modal_historico_perdas.php" -ForegroundColor $(if ($api2) {'Green'} else {'Red'})
Write-Host "[ $(if ($api3) {'✅'} else {'❌'}) ] API marcar_perda_v2.php" -ForegroundColor $(if ($api3) {'Green'} else {'Red'})

Write-Host "`n====== FIM DA VALIDAÇÃO ======" -ForegroundColor Cyan
```

---

## 🆘 **TROUBLESHOOTING**

### **Erro 1: "Unknown procedure"**

```bash
# Verificar se procedure existe
mysql -u root -p gestaointeli_db -e "SHOW CREATE PROCEDURE relatorio_analise_estoque_periodo_corrigido\G"

# Se não existir, executar script novamente
mysql -u root -p gestaointeli_db < database/13_migracao_correcao_logica_perdas.sql
```

### **Erro 2: "Table doesn't exist"**

```bash
# Verificar tabela
mysql -u root -p gestaointeli_db -e "DESC fechamento_diario_estoque;"

# Se não existir, executar script SQL
```

### **Erro 3: API retorna erro 404**

```bash
# Verificar se arquivo existe
ls -la public_html/caixa-seguro-7xy3q9kkle/api/relatorio_analise_estoque_corrigido.php

# Verificar permissões
chmod 644 public_html/caixa-seguro-7xy3q9kkle/api/*.php
```

### **Erro 4: "Connection refused" no MySQL**

```bash
# Verificar MySQL está rodando
mysql -u root -p -e "SELECT 1;"

# Se falhar, reiniciar MySQL
# Windows:
net stop MySQL80
net start MySQL80

# Linux:
sudo systemctl restart mysql
```

---

## ✅ **RESULTADO ESPERADO**

Após completar todas as etapas:

✅ Tabela `fechamento_diario_estoque` criada  
✅ Procedures `*_corrigido` e `*_automatico` funcionando  
✅ 3 novas APIs disponíveis  
✅ Relatório não acumula dados (isolado por período)  
✅ Modal carrega alertas corretamente  
✅ Marcação como visualizada funciona  
✅ Cálculos são precisos (sem perdas fantasmas)  

---

**Data:** 14 de Dezembro de 2025  
**Versão:** 2.0 (Corrigida)  
**Status:** Pronto para Implementação
