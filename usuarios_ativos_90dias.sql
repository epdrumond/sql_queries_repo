-- Criar tabela temporária com relação dos usuários ativos nos últimos 90 dias --------------------
drop table if exists usuarios_ativos_90dias;

create temporary table usuarios_ativos_90dias as 

select 
	user_id, 
	current_date as data_referencia, 
	count(id) as transacoes_ultimos_90dias
from reporting.transactions_ext
where
	created_at >= current_date - '90 days'::interval and
	status = 'Complete' and
	transaction_type in (
		'InStoreDeposit',
		'TransferDeposit',
		'CashDeposit',
		'BoletoDeposit',
		'PecDeposit',
		'PixIn',
		'BoletoPayment',
		'VirtualCardTransaction',
		'PhysicalCardTransaction',
		'MobileRecharge',
		'TransportationRecharge',
		'Marketplace',
		'QrPayment',
		'CdcInstallmentPayment',
		'PixOut',
		'BankWithdraw',
		'InStoreWithdraw',
		'Charge',
		'P2PTransfer',
		'offlineTransfer',
		'LoanDeposit')
group by 1;
		
-- Consultar usuários ativos nos últimos 90 dias (com CPF) ----------------------------------------
select 
	au.user_id,
	substring(us.cpf, 1, 11) as cpf,
	au.data_referencia,
	au.transacoes_ultimos_90dias
from 
	usuarios_ativos_90dias as au
	left join user_service.user as us on (
		au.user_id = us.fox_id and
		us.cpf != '_archived');