-- Endereço mais atual dos usuários (tratativa necessária pois existem algumas duplicatas) ------------------------------------------------
create temporary table endereco_usuarios as 

select distinct on (user_id)
	user_id,
	created_at,
	zip_code as cep,
	city as cidade,
	state as estado
from user_service.address
order by 1,2 desc;

-- Telefone mais atual --------------------------------------------------------------------------------------------------------------------
create temporary table telefone_usuarios as

select distinct on (user_id)
	user_id,
	"number" as telefone,
	created_at
from user_service.phone
order by 1,2 desc;

-- Saldo transacional Pix (PixIn - PixOut) ------------------------------------------------------------------------------------------------
create temporary table transacoes_pix as

with total_pix as (
select 
	user_id,
	sum(case when transaction_type = 'PixIn' then amount else 0 end) as total_pix_in,
	sum(case when transaction_type = 'PixOut' then amount else 0 end) as total_pix_out
from reporting.transactions_ext
where
	status = 'Complete' and
	transaction_type in ('PixIn', 'PixOut')
group by 1)

select 
	user_id,
	total_pix_in - total_pix_out as saldo_pix
from total_pix;

-- Saldo transações com cartão pré-pago ---------------------------------------------------------------------------------------------------
create temporary table transacoes_cartao as 

select 
	user_id,
	sum(amount) as saldo_cartao
from reporting.transactions_ext
where 
	status = 'Complete' and
	transaction_type in ('PhysicalCardTransaction', 'VirtualCardTransaction')
group by 1;

-- Saldo em conta mais atual --------------------------------------------------------------------------------------------------------------
create temporary table saldo_atual as

select fox_id, balance as saldo
from dock_data.active_inactive_accounts_balance 
where balance_date = (select max(balance_date) from dock_data.active_inactive_accounts_balance);

-- Consulta principal ---------------------------------------------------------------------------------------------------------------------
select  
	us.cpf,
	case 
		when us.block_type = 'cancelled' then 'cancelada'
		when us.block_type = 'archived' then 'arquivada'
		when us.block_type in ('blocked', 'strict_block', 'fraudhub_blockage', 'rc_restrict_blockage') then 'bloqueada_fraude'
		when us.block_type in ('conductorError', 'conductor_error') then 'erro_conductor'
		when us.block_type = 'user_requested_block' then 'bloqueada_outros'
		else 'regular'
	end as status_conta,
	endr.cep,
	endr.cidade, 
	endr.estado,
	us.email,
	tel.telefone,
	coalesce(dock.saldo, 0) as saldo_conta,
	coalesce(pix.saldo_pix, 0) as saldo_pix,
	coalesce(cart.saldo_cartao, 0) as saldo_cartao
from 
	user_service.user as us
	inner join account_service."Account" as acc on (us.fox_id = acc."foxId")
	left join endereco_usuarios as endr on (us.id = endr.user_id)
	left join telefone_usuarios as tel on (us.id = tel.user_id)
	left join saldo_atual as dock on (us.fox_id = dock.fox_id)
	left join transacoes_pix as pix on (us.fox_id = pix.user_id)
	left join transacoes_cartao as cart on (us.fox_id = cart.user_id);