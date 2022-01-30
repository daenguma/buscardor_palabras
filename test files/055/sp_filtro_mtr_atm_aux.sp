/************************************************************************/
/*  ARCHIVO:         sp_filtro_mtr_atm_aux.sp	                      	*/
/*  NOMBRE LOGICO:   sp_filtro_mtr_atm_aux.sp  	                 		*/
/*  PRODUCTO:        ATM                                        		*/
/************************************************************************/
/*                     PROPOSITO                                      	*/
/*	Migración ATM Server  												*/
/*                                                 						*/
/************************************************************************/
/*                     MODIFICACIONES                                 	*/
/*    FECHA         AUTOR               RAZON                         	*/
/*  15-Jun-2021   Adolfo Hernández  Emision inicial (Migración ATMSRV) 	*/
/************************************************************************/
USE cob_atm_his
go

alter proc sp_filtro_mtr_atm_aux (
        @i_fecha_proc     datetime = null
)
as

declare @w_fecha_ayer	datetime,
	@w_contador 	int

select @w_fecha_ayer = dateadd(dd, -1, @i_fecha_proc)

/* Verificando que no sea dia feriado o no laborable */
select @w_contador = 1
while @w_contador = 1
   begin
      if exists (select df_fecha
                   from cobis..cl_dias_feriados
                  where df_ciudad = 1
                    and df_fecha = @w_fecha_ayer)
         select @w_fecha_ayer = dateadd(dd,-1,@w_fecha_ayer)
      else
         select @w_contador = 2
   end

/**** Filtro de los datos desde el log diario del ATM SERVER ****/


begin tran

-- transacciones nacionales

	insert into cob_atm_his..tm_consumos_consorcio(
		co_fecha_tran, co_tipo_tran, co_ssn_local, co_ssn_host,
		co_oficina, co_banco, co_prod_banc, co_moneda_bco, co_signo,
		co_causa, co_tarjeta, co_hora, co_consumo, co_reverso,
		co_consumo_me, co_estado_concilia, co_estado_transaccion,
		co_tasa_consorcio, co_cta_banco,co_moneda_mtr, co_consumo_dol,
		co_cod_error, co_tasa_bco, co_valor_comision, co_cod_comercio,
		co_ssn_rev)
	select 	tm_fecha, tm_tipo_tran, tm_ssn_local, tm_ssn_host,
		tm_oficina, tm_banco, tm_producto, tm_moneda, tm_signo,
		tm_causa, tm_tarjeta_atm, convert(char(8),tm_hora,108), tm_monto5,
	        tm_correccion, tm_valor, 'N', tm_estado_ejecucion,
		tm_tasa4, tm_cta_banco, convert(smallint, substring(tm_campo4,datalength(tm_campo4)- 2, 3)), tm_monto9, --FES 220903
		tm_control, tm_tasa1, tm_interes, tm_terminal,
		tm_ssn_local_correccion
	from cob_remesas..re_tran_monet with(index(re_tran_monet_fecha_Key))
	where tm_fecha = @w_fecha_ayer
	  and tm_oficina = 999
          and tm_moneda = 0
          and tm_tipo_tran not in (130,140,150,540,550)
	  and tm_tarjeta_atm <> '6036449999999999998'

-- transacciones internacionales

	insert into cob_atm_his..tm_consumos_consorcio(
		co_fecha_tran, co_tipo_tran, co_ssn_local, co_ssn_host,
		co_oficina, co_banco, co_prod_banc, co_moneda_bco, co_signo,
		co_causa, co_tarjeta, co_hora, co_consumo, co_reverso,
		co_consumo_me, co_estado_concilia, co_estado_transaccion,
		co_tasa_consorcio, co_cta_banco,co_moneda_mtr, co_consumo_dol,
		co_cod_error, co_tasa_bco, co_valor_comision_me, co_valor_uso_atm,
                co_cod_comercio, co_ssn_rev)
	select 	tm_fecha, tm_tipo_tran, tm_ssn_local, tm_ssn_host,
		tm_oficina, tm_banco, tm_producto, tm_moneda, tm_signo,
		tm_causa, tm_tarjeta_atm, convert(char(8),tm_hora,108), tm_monto5,
	        tm_correccion, tm_valor, 'N', tm_estado_ejecucion,
		tm_tasa4, tm_cta_banco, convert(smallint, substring(tm_campo4,datalength(tm_campo4)- 2, 3)), tm_monto9, --FES 220903
		tm_control, tm_tasa1, tm_interes, tm_monto3,
	 	tm_terminal, tm_ssn_local_correccion
	from cob_remesas..re_tran_monet with(index(re_tran_monet_fecha_Key))
	where tm_fecha = @w_fecha_ayer
	  and tm_oficina = 999
	  and tm_moneda >= 1
          and tm_tipo_tran not in (130,140,150,540,550)
	  and tm_tarjeta_atm <> '6036449999999999998'

/**** Actualizacion de los estatus de las transacciones ****/

update cob_atm_his..tm_consumos_consorcio
   set co_estado_transaccion = 'T'
 where co_fecha_tran = @w_fecha_ayer
   and co_estado_transaccion <> 'EE'
   and co_ssn_host is null
   and co_fecha_liq is null
   and co_estado_concilia = 'N'

update cob_atm_his..tm_consumos_consorcio
   set co_estado_transaccion = 'T'
 where co_fecha_tran = @w_fecha_ayer
   and co_estado_transaccion = 'EL'
   and co_ssn_host is not null
   and co_estado_concilia = 'N'
   and co_fecha_liq is null

update cob_atm_his..tm_consumos_consorcio
   set co_estado_transaccion = 'D',
       co_rechazo = isnull((select tt_trn_nombre from cob_atm..tm_ttransaccion
				where tt_trn_cobis = convert (varchar(8),co_tipo_tran)),'TRANSACCION NO DEFINIDA')
 where co_fecha_tran = @w_fecha_ayer
   and co_estado_transaccion = 'EJ'
   and co_ssn_host is not null
   and co_estado_concilia = 'N'
   and co_fecha_liq is null

update cob_atm_his..tm_consumos_consorcio
   set co_estado_transaccion = 'E',
       co_fecha_liq = @w_fecha_ayer,
       co_rechazo = isnull((select ea_msg_1 from cob_atm..tm_errores_atm
		      where ea_numero = co_cod_error),'MENSAJE DE ERROR NO DEFINIDO')
 where co_fecha_tran = @w_fecha_ayer
   and co_estado_transaccion = 'EE'
   and co_estado_concilia = 'N'
   and co_fecha_liq is null

update cob_atm_his..tm_consumos_consorcio
   set co_autoriza = convert(int,right(replicate('0',(6 - datalength(convert(varchar,co_ssn_local)))) + convert(varchar,co_ssn_local),6))
 where co_fecha_tran = @w_fecha_ayer
   and co_estado_concilia = 'N'
   and co_autoriza is null

update cob_atm_his..tm_consumos_consorcio
   set co_ssn_rev =  convert(int,right(replicate('0',(6 - datalength(convert(varchar,co_ssn_rev)))) + convert(varchar,co_ssn_rev),6))
 where co_fecha_tran = @w_fecha_ayer
   and co_estado_concilia = 'N'
   and co_ssn_rev is not null

commit tran

return 0
go

IF OBJECT_ID('dbo.sp_filtro_mtr_atm_aux') IS NOT NULL
    PRINT '<<< ALTER PROCEDURE dbo.sp_filtro_mtr_atm_aux >>>'
ELSE
    PRINT '<<< FAILED ALTER PROCEDURE dbo.sp_filtro_mtr_atm_aux >>>'
go
