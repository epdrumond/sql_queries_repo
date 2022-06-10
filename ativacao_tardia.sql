-- Criar tabela temporária com as ativações pós 60 dias da criação da conta --------------------------------------------
drop table if exists ativacao_tardia;

create temporary table ativacao_tardia as

select 
	reg.user_id,
	reg.data_nova_conta,
	atv.data_ativacao_conta,
	atv.metodo_ativacao,
	case when (atv.data_ativacao_conta::date - reg.data_nova_conta::date) >= 60 then 'pos_60' else 'ate_60' end as tipo
from 
	business_analytics.rps_novas_contas as reg
	inner join business_analytics.rps_ativacao_conta as atv on (reg.user_id = atv.user_id)
where atv.data_ativacao_conta >= '2021-01-01'::timestamp;

-- Criar tabela temporária com retenção mensal dos usuários -----------------------------------------------------------
drop table if exists atividade_mensal;

create temporary table atividade_mensal as

select distinct
	tx.user_id,
	date_trunc('month', tx.created_at)::date as mes
from 
	reporting.transactions_ext as tx
where 
	tx.status = 'Complete' and
	tx.transaction_type not in (
		'AdminAdjustment',
		'Bonus',
		'Cashback',
		'Charge',
		'Fee',
		'PixInReversal',
		'PixOutReversal');

-- Criar tabela temporária com as campanhas de cashback pontuais ------------------------------------------------------
drop table if exists campanhas_cashback;
	
create temporary table campanhas_cashback as 

with campanhas_marketing as (
select 
	user_id,
	received_at::date,
	reason,
	amount::numeric(19,2)
from node_js.ajuda_qi_balance_adjustment 
where reason like '%MKT'

union 

select 
	user_id,
	received_at::date,
	reason,
	amount::numeric(19,2)
from node_js.balance_adjustment
where reason like '%MKT')

select 
	user_id,
	reason as nome_campanha,
	case 
		when split_part(reason,'_',1) = '11022021' then to_date(split_part(reason,'_',1), 'DDMMYYYY') 
		else to_date(split_part(reason,'_',1), 'YYYYMMDD') 
	end as data_inicio_campanha,
	'cashback' as tipo_recompensa,
	max(received_at) as data_recompensa,
	sum(amount) as valor
from campanhas_marketing 
group by 1,2,3,4;

-- Criar tabela temporária com campanhas de voucher e sorteio ---------------------------------------------------------
drop table if exists campanhas_sem_cashback;

create temporary table campanhas_sem_cashback as 

select 
	user_id,
	campaign_name as nome_campanha,
	min(received_at) - '30 days'::interval as data_inicio_campanha,
	'sorteio' as tipo_recompensa,
	min(received_at) as data_recompensa,
	0 as valor
from node_js.reward_luckynumber_awarded 
group by 1,2,4,6

union all

select 
	user_id,
	campaign_name as nome_campanha,
	min(received_at) - '30 days'::interval as data_inicio_campanha,
	'voucher' as tipo_recompensa,
	min(received_at) as data_recompensa,
	0 as valor
from node_js.reward_giftcard_awarded 
group by 1,2,4,6;

-- Criar tabela temporária que identifica a primeira parcela de CDC paga pelos usuários -------------------------------
create temporary table primeiro_pagamento_cdc as 

select distinct on ("userId")
	"userId" as user_id,
	"createdAt" as created_at,
	("attributes" ->> 8)::json ->> 'key' as validar_campo,
	("attributes" ->> 8)::json ->> 'value' as numero_parcela
from transaction_list_service."Transactions" 
where 
	status = 'Complete' and
	"transactionType" = 'CdcInstallmentPayment'
order by 1,2;


-- Consultar perfil do usuário que ativa a conta tardiamente ----------------------------------------------------------
select 
	to_char(date_trunc('month', atv.data_ativacao_conta), 'YYYY-MM') as mes,
	tipo,
	count(atv.user_id) as usuarios_ativados,
	count(case when seg.flag_cdc = true then atv.user_id end) as ativados_cdc,
	count(case when seg.tipo_indicacao = 'Loja' then atv.user_id end) as ativados_loja,
	100 * count(case when seg.flag_cdc = true then atv.user_id end) / count(atv.user_id) as pct_cdc,
 	100 * count(case when seg.tipo_indicacao = 'Loja' then atv.user_id end) / count(atv.user_id) as pct_loja
from 
	ativacao_tardia as atv
	left join business_analytics.rps_segmentacao_usuarios as seg on (atv.user_id = seg.user_id)
group by 1,2
order by 2,1

-- Consultar ativações tardias mensais por método ---------------------------------------------------------------------
select 
	date_trunc('month', data_ativacao_conta)::date as mes,
	tipo,
	count(case when metodo_ativacao = 'PixIn' then user_id end) as pix_in,
	count(case when metodo_ativacao = 'InStoreDeposit' then user_id end) as deposito_loja,
	count(case when metodo_ativacao = 'BoletoDeposit' then user_id end) as deposito_boleto,
	count(case when metodo_ativacao = 'LoanDeposit' then user_id end) as emprestimo
from ativacao_tardia
group by 1,2
order by 2,1;

-- Consultar primeiro gasto das ativações tardias ---------------------------------------------------------------------
select 
	date_trunc('month', atv.data_ativacao_conta) as mes,
	atv.tipo,
	count(case when spend.metodo = 'CdcInstallmentPayment' then atv.user_id end) as cdc,
	count(case when spend.metodo = 'PixOut' then atv.user_id end) as pix_out,
	count(case when spend.metodo in ('VirtualCardTransaction', 'PhysicalCardTransaction') then atv.user_id end) as cartao,
	count(case when spend.metodo = 'BoletoPayment' then atv.user_id end) as boleto,
	count(case when spend.metodo in ('MobileRecharge', 'TransportationRecharge') then atv.user_id end) as recarga,
	count(case when spend.metodo = 'P2PTransfer' then atv.user_id end) as p2p,
	count(case when spend.metodo = 'QrPayment' then atv.user_id end) as qr,
	count(case when spend.metodo = 'Marketplace' then atv.user_id end) as gift_card,
	count(case when spend.metodo is null then atv.user_id end) as churn
from 
	ativacao_tardia as atv
	left join business_analytics.rps_primeiro_gasto as spend on (atv.user_id = spend.user_id)
group by 1,2
order by 2,1
	
	
select metodo, count(*) 
from business_analytics.rps_primeiro_gasto 
where data_primeiro_gasto >= '2021-01-01'::date
group by 1 order by 2 desc

-- Consultar retenção comparada pós reativação ------------------------------------------------------------------------
select 
	to_char(date_trunc('month', atv.data_ativacao_conta), 'YYYY-MM') as mes,
	atv.tipo,
	count(distinct atv.user_id) as usuarios_ativados,
	count(distinct case when age(ret.mes, date_trunc('month', atv.data_ativacao_conta)) >= '1 months'::interval then atv.user_id end) as retencao_m1,
	count(distinct case when age(ret.mes, date_trunc('month', atv.data_ativacao_conta)) >= '2 months'::interval then atv.user_id end) as retencao_m2,
	count(distinct case when age(ret.mes, date_trunc('month', atv.data_ativacao_conta)) >= '3 months'::interval then atv.user_id end) as retencao_m3,
	count(distinct case when age(ret.mes, date_trunc('month', atv.data_ativacao_conta)) >= '4 months'::interval then atv.user_id end) as retencao_m4,
	count(distinct case when age(ret.mes, date_trunc('month', atv.data_ativacao_conta)) >= '5 months'::interval then atv.user_id end) as retencao_m5
from 
	ativacao_tardia as atv 
	left join atividade_mensal as ret on (atv.user_id = ret.user_id)
group by 1,2
order by 2,1

-- Consultar impacto das campanhas na reativação tardia ---------------------------------------------------------------

