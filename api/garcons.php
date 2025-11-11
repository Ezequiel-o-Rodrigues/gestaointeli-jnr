<?php
header('Content-Type: application/json; charset=utf-8');
require_once __DIR__ . '/../config/database.php';

$date = $_GET['date'] ?? date('Y-m-d');
$rate = isset($_GET['rate']) ? floatval($_GET['rate']) : 0.03; // comissão padrão 3%

$database = new Database();
$db = $database->getConnection();

try {
	// Total de comandas fechadas na data
	$stmt = $db->prepare("SELECT COUNT(*) as total FROM comandas WHERE status = 'fechada' AND DATE(data_venda) = ?");
	$stmt->execute([$date]);
	$row = $stmt->fetch(PDO::FETCH_ASSOC);
	$totalComandas = (int)($row['total'] ?? 0);

	// Garçons ativos
	$stmt = $db->prepare("SELECT id, nome, codigo, ativo FROM garcons WHERE ativo = 1 ORDER BY nome");
	$stmt->execute();
	$garcons = $stmt->fetchAll(PDO::FETCH_ASSOC);
	$activeCount = count($garcons);

	$average = $activeCount > 0 ? ($totalComandas / $activeCount) : 0;

	$resultGarcons = [];

	foreach ($garcons as $g) {
		$gid = (int)$g['id'];

		// Comandas atendidas pelo garçom na data
		$stmt = $db->prepare("SELECT COUNT(*) as cnt, COALESCE(SUM(valor_total),0) as vendas_total FROM comandas WHERE status = 'fechada' AND DATE(data_venda) = ? AND garcom_id = ?");
		$stmt->execute([$date, $gid]);
		$r = $stmt->fetch(PDO::FETCH_ASSOC);
		$cnt = (int)($r['cnt'] ?? 0);
		$vendas_total = floatval($r['vendas_total'] ?? 0);

		// Percentual em relação à média
		if ($average > 0) {
			$ratio = $cnt / $average;
			$percent_of_average = round($ratio * 100, 1);
			$percent_diff = round((($cnt / $average) - 1) * 100); // inteiro % acima/abaixo
		} else {
			$ratio = null;
			$percent_of_average = null;
			$percent_diff = 0;
		}

		// Classificação
		$classification = 'Sem Dados';
		$icon = 'gray';

		if ($ratio === null) {
			$classification = 'Sem Dados';
			$icon = 'secondary';
		} else {
			if ($ratio >= 1.33) {
				$classification = 'Excelente';
				$icon = 'success';
			} elseif ($ratio >= 1.12) {
				$classification = 'Bom';
				$icon = 'info';
			} elseif ($ratio >= 0.90) {
				$classification = 'Regular';
				$icon = 'primary';
			} elseif ($ratio >= 0.70) {
				$classification = 'Baixo';
				$icon = 'warning';
			} else {
				$classification = 'Muito Baixo';
				$icon = 'danger';
			}
		}

		$comissao = round($vendas_total * $rate, 2);

		$tooltip = $cnt . ' comandas';
		if ($percent_diff > 0) $tooltip .= ' (' . $percent_diff . '% acima da média)';
		elseif ($percent_diff < 0) $tooltip .= ' (' . abs($percent_diff) . '% abaixo da média)';
		else $tooltip .= ' (na média)';

		$resultGarcons[] = [
			'id' => $gid,
			'nome' => $g['nome'],
			'codigo' => $g['codigo'] ?? null,
			'ativo' => (int)$g['ativo'],
			'comandas' => $cnt,
			'vendas_total' => round($vendas_total, 2),
			'comissao' => $comissao,
			'percent_of_average' => $percent_of_average,
			'percent_diff' => $percent_diff,
			'classification' => $classification,
			'badge' => $icon,
			'tooltip' => $tooltip,
		];
	}

	$output = [
		'date' => $date,
		'total_comandas' => $totalComandas,
		'active_garcons' => $activeCount,
		'average' => round($average, 2),
		'commission_rate' => $rate,
		'garcons' => $resultGarcons,
	];

	echo json_encode($output, JSON_UNESCAPED_UNICODE | JSON_PRETTY_PRINT);

} catch (Exception $e) {
	http_response_code(500);
	echo json_encode(['error' => $e->getMessage()]);
}

?>

