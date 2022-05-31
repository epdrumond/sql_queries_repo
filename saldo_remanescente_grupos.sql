select 
	case 
		when days_inactive between -1 and 90 then 'A. Ativos 90 dias'
		when days_inactive between 91 and 180 then 'B. 91-180 dias inativos'
		when days_inactive between 181 and 360 then 'C. 181-360 dias inativos'
		when days_inactive > 360 then 'D. 361+ dias inativos'
	end as categoria,
	count(fox_id) as total_usuarios,
	count(case when balance > 0 then fox_id end) as usuarios_com_saldo,
	sum(balance)::int as saldo_total,
	(sum(balance) / count(case when balance > 0 then fox_id end))::numeric(19,2) as saldo_medio
from dock_data.active_inactive_accounts_balance
where 
	balance_date = '2022-05-29'::date and
	max_transaction_created_at is not null 
group by 1
order by 1