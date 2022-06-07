-- Verificar desinstalação do app -----------------------------------------------------------------
select 
	case 
		when saldo.days_inactive between 0 and 29 then 'a. 0-29 dias'
		when saldo.days_inactive < 90 then 'b. 30-89 dias'
		when saldo.days_inactive < 120 then 'c. 90-119 dias'
		when saldo.days_inactive < 180 then 'd. 120-179 dias'
		when saldo.days_inactive < 360 then 'e. 180-359 dias'
		when saldo.days_inactive >= 360 then 'f. 360+ dias'
	end as faixa_inatividade,
	count(distinct saldo.fox_id) as usuarios
from 
	dock_data.active_inactive_accounts_balance as saldo
	inner join marketing_crm.uninstall_event_users_30days_window as app on (app.fox_id = saldo.fox_id)
where
	saldo.max_transaction_created_at is not null and
	saldo.days_inactive >= 0 and
	saldo.balance_date = '2022-05-29'::date
group by 1
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
	
