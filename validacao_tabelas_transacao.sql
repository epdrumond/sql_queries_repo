-- Automação Mensal -------------------------------------------------------------------------------------------------------------
select 
	count(user_id) as usarios_ativos,
	sum(count_transactions) as total_transacoes,
	sum(sum_amount) as valor_total
from reporting.transactions_user_monthly
where 
	yearmonth = 202204 and
	transaction_type = 'PhysicalCardTransaction';
	
-- Automação Diária -------------------------------------------------------------------------------------------------------------
select 
	count(distinct user_id) as usarios_ativos,
	sum(count_transactions) as total_transacoes,
	sum(sum_amount) as valor_total
from reporting.transactions_user_daily
where 
	date_trunc('month', created_at_date) = '2022-04-01'::date and
	transaction_type = 'PhysicalCardTransaction';
	
-- Automação Analítica ----------------------------------------------------------------------------------------------------------
select 
	count(user_id) as usarios_ativos,
	count(id) as total_transacoes,
	sum(amount) as valor_total
from reporting.transactions_ext
where 
	date_trunc('month', created_at) = '2022-04-01'::date and
	transaction_type = 'PhysicalCardTransaction';