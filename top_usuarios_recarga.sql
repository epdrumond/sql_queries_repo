-- Criar tabela temporária com atividade mensal em Recarga de Celular -----------------------------------------------------------
with recarga_celular as (
  select userid as user_id,
         date_trunc('month', createdat)::date as mes_ativo,
         count(distinct id) as transacoes,
         sum(amount) as valor_total
    from reporting.transactions 
   where status = 'Complete'
     and transactiontype = 'MobileRecharge'
group by 1,2),

-- Criar tabelas temporárias para identificar retenção mês contra mês -----------------------------------------------------------
retencao_recarga as (
  select user_id,
         mes_ativo,
         transacoes,
         valor_total,
         lag(mes_ativo, 1) over (partition by user_id order by mes_ativo) as mes_ativo_anterior
    from recarga_celular),
 
retencao_recarga_enriquecida as (
  select *,
         case when mes_ativo - '1 month'::interval = mes_ativo_anterior then 1 else 0 end as flag_retido
    from retencao_recarga)

-- Consultar melhores usuários para Recarga de Celular --------------------------------------------------------------------------
  select user_id,
         to_char(max(mes_ativo), 'YYYY-MM') as ultimo_mes_ativo,
         count(distinct mes_ativo) as meses_ativo,
         sum(flag_retido) + 1 as meses_ativo_em_sequencia,
         sum(valor_total) as valor_total,
         (sum(valor_total)::float / sum(transacoes))::numeric(19,2) as valor_medio
    from retencao_recarga_enriquecida 
group by 1
order by 2,3,4 desc;

-- Consultar usuários recorrentes inativos atualmente ---------------------------------------------------------------------------
  select user_id,
         to_char(max(mes_ativo), 'YYYY-MM') as ultimo_mes_ativo,
         count(distinct mes_ativo) as meses_ativo,
         sum(flag_retido) + 1 as meses_ativo_em_sequencia,
         sum(valor_total) as valor_total,
         (sum(valor_total)::float / sum(transacoes))::numeric(19,2) as valor_medio
    from retencao_recarga_enriquecida 
group by 1
having 
	count(distinct mes_ativo) >= 3 and
	date_trunc('month', current_date)::date - max(mes_ativo) between 90 and 180
order by 2,3,4 desc;
 
   