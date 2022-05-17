-- Definição da tabela principal do estudo ------------------------------------------------------------------------------------------------
drop table if exists reativacao_emprestimo;

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
drop table if exists atividade_pre_churn;

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
	
-- Analisar reativação por empréstimo pessoal ---------------------------------------------------------------------------------------------

-- 1. Reativações mensais	
select 
	to_char(date_trunc('month', data_transacao), 'YYYY-MM') as mes_reativacao,
	count("userId") as usuarios_reativados
from reativacao_emprestimo
group by 1
order by 1;

-- 2. Atividade antes do churn
select 
	to_char(date_trunc('month', data_transacao), 'YYYY-MM') as mes_reativacao,
	count("userId") as usuarios_reativados,
	percentile_disc(0.5) within group (order by transacoes_anteriores) as mediana_transacoes,
	percentile_disc(0.5) within group (order by meses_ativo) as mediana_meses_ativo,
	100 * avg(flag_cdc)::decimal(19,3) as penetracao_cdc,
	100 * avg(flag_deposito_loja)::decimal(19,3) as penetracao_deposito_loja,
	100 * avg(flag_cartao)::decimal(19,3) as penetracao_cartao
from atividade_pre_churn 
group by 1
order by 1;

-- Usuários no mesmo perfil dos reativados via empréstimo pessoal -------------------------------------------------------------------------
select
	tx.user_id,
	current_date - max(tx.created_at)::date as dias_inativo,
	count(tx.id) as qtd_transacoes,
	count(distinct date_trunc('month', tx.created_at)) as meses_ativo,
	max(case when tx.transaction_type = 'CdcInstallmentPayment' then 1 else 0 end) as flag_cdc,
	max(case when tx.transaction_type = 'InStoreDeposit' then 1 else 0 end) as flag_deposito_loja
from 
	reporting.transactions_ext as tx
	inner join user_service.user as us on (
		tx.user_id = us.fox_id and
		(us.block_type is null or us.block_type not in ('blocked', 'strict_block', 'fraudhub_blockage', 'rc_restrict_blockage')))
where 
	tx.status = 'Complete' and
	tx.transaction_type not in (
		'AdminAdjustment',
		'Bonus',
		'Cashback',
		'Charge',
		'Fee',
		'PixInReversal',
		'PixOutReversal')
group by 1
having 
	current_date - max(tx.created_at)::date between 90 and 180 and
	count(distinct date_trunc('month', tx.created_at)) >= 2 and
	max(case when tx.transaction_type = 'CdcInstallmentPayment' then 1 else 0 end) = 1 and
	max(case when tx.transaction_type = 'InStoreDeposit' then 1 else 0 end) = 1;


