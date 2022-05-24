with funcionarios_via as (
select distinct on (via.cd_fun_cic)
	us.fox_id as user_id,
    via.cd_fun_cic as cpf,
    via.dt_fun_adm as data_admissao,
    case when via.dt_fun_res is null then true else false end as is_active
from
  scratch.vv_fa_employees as via
  inner join user_service.user as us on (us.cpf = via.cd_fun_cic)
where
  via.cd_fun_cic is not null and
  via.cd_fun_cic != '0'
order by 2,3 desc),

indicacao as (
select distinct
	ref.user_id,
    ref.advocate_fox_id as referrer_user_id,
    case when via.user_id is not null then 'Loja' else 'Outro Usuário' end as tipo_indicacao
from
  node_js.ums_referral_activated as ref
    left join funcionarios_via as via on (ref.advocate_fox_id = via.user_id)
where ref.advocate_fox_id is not null)

select 
	email.user_id,
	ind.tipo_indicacao,
	case
		when us.block_type in ('blocked', 'strict_block', 'fraudhub_blockage', 'rc_restrict_blockage') then 'bloqueio_fraude'
		when us.block_type in ('conductorError', 'blocked_pin_attempts', 'conductor_error', 'user_requested_block') then 'outros_bloqueios'
		when us.block_type in ('archived', 'cancelled') then 'arquivado/cancelado'
		else 'regular'
	end as status_conta,
	count(distinct email.id) as mudancas_email
from 
	node_js.ajudaqi_user_email_edit as email
	left join indicacao as ind on (email.user_id = ind.user_id)
	left join user_service.user as us on (email.user_id = us.fox_id)
where received_at >= current_date - '14 months'::interval
group by 1,2,3
having count(distinct email.id) >= 3
