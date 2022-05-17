-- Definição da tabela principal do estudo ------------------------------------------------------------------------------------------------
create temporary table reativacao_emprestimo as

select *
from (
select 
	"userId",
	"createdAt" as data_transacao,
	"transactionType" as tipo_tx,
	lag("createdAt", 1) over (partition by "userId" order by "createdAt") as data_transacao_anterior,
	lead("transactionType", 1) over (partition by "userId" order by "createdAt") as tipo_proxima_tx
from transaction_list_service."Transactions" 
where
	status = 'Complete' and
	"transactionType" not in (
		'AdminAdjustment',
		'Bonus',
		'Cashback',
		'Charge',
		'Fee',
		'PixInReversal',
		'PixOutReversal')
) as reativacao
where 
	(data_transacao::date - data_transacao_anterior::date) >= 90 and
	tipo_tx = 'LoanDeposit';

-- Atividade Pré Reativação ---------------------------------------------------------------------------------------------------------------
create temporary table atividade_pre_churn as 

select 
	rtv."userId",
	rtv.data_transacao,
	count(tx.id) as transacoes_anteriores,
	count(distinct date_trunc('month', tx."createdAt")) as meses_ativo,
	max(case when tx."transactionType" = 'CdcInstallmentPayment' then 1 else 0 end) as flag_cdc,
	max(case when tx."transactionType" = 'InStoreDeposit' then 1 else 0 end) as flag_deposito_loja,
	max(case when tx."transactionType" in ('PhysicalCardTransaction', 'VirtualCardTransaction') then 1 else 0 end) as flag_cartao
from 
	reativacao_emprestimo as rtv
	inner join transaction_list_service."Transactions" as tx on (
		rtv."userId" = tx."userId" and
		tx."createdAt" < rtv.data_transacao)
where
	tx.status = 'Complete' and 
	tx."transactionType" not in (
		'AdminAdjustment',
		'Bonus',
		'Cashback',
		'Charge',
		'Fee',
		'PixInReversal',
		'PixOutReversal')
group by 1,2;

-- Atividade Pós Reativação ---------------------------------------------------------------------------------------------------------------
create temporary table retencao_reativados as

select 
	tx."userId",
	tx."createdAt" 
from 
	transaction_list_service."Transactions" as tx
	inner join reativacao_emprestimo as rtv on (
		tx."userId" = rtv."userId" and
		tx."createdAt" > rtv.data_transacao)
where 
	tx.status = 'Complete' and
	tx."transactionType" not in (
		'AdminAdjustment',
		'Bonus',
		'Cashback',
		'Charge',
		'Fee',
		'PixInReversal',
		'PixOutReversal');
	
-- Analisar reativação por empréstimo pessoal ---------------------------------------------------------------------------------------------

-- 1. Reativações mensais	
select 
	to_char(date_trunc('month', data_transacao), 'YYYY-MM') as mes_reativacao,
	count("userId") as usuarios_reativados
from reativacao_emprestimo
group by 1
order by 1;

-- 2. Tempo ativo antes do churn
select 
	to_char(date_trunc('month', data_transacao), 'YYYY-MM') as mes_reativacao,
	count("userId") as usuarios_reativados,
	percentile_disc(0.5) within group (order by transacoes_anteriores) as mediana_transacoes,
	percentile_disc(0.5) within group (order by meses_ativo) as mediana_meses_ativo,
	percentile_disc(0.5) within group (order by flag_cdc) as mediana_pagamentos_cdc,
	percentile_disc(0.5) within group (order by flag_deposito_loja) as mediana_deposito_loja,
	percentile_disc(0.5) within group (order by flag_cartao) as mediana_cartao
from atividade_pre_churn 
group by 1
order by 1

-- 2. Principais transações pós reativação
select 
	tipo_proxima_tx,
	count("userId") as transacoes
from reativacao_emprestimo
group by 1
order by 2 desc









