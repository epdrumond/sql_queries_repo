-- Definição da tabela principal do estudo --------------------------------------------------------------------
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
