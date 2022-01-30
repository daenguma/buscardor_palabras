/************************************************************************/
/*  ARCHIVO:         sp_filtro_mtr_atm.sp		                      	*/
/*  NOMBRE LOGICO:   sp_filtro_mtr_atm.sp      	                 		*/
/*  PRODUCTO:        ATM                                        		*/
/************************************************************************/
/*                     PROPOSITO                                      	*/
/*	Migración ATM Server  												*/
/*                                                 						*/
/************************************************************************/
/*                     MODIFICACIONES                                 	*/
/*    FECHA         AUTOR               RAZON                         	*/
/*  15-Jun-2021   Adolfo Hernández  Emisión inicial (Migración ATMSRV) 	*/
/************************************************************************/
use cob_atm_his
go

alter proc sp_filtro_mtr_atm (
        @i_fecha_proc     datetime = null
)
as

declare @w_sp_name      varchar(32),
        @w_fecha_ayer	datetime,
	@w_contador     int

select @w_sp_name = 'sp_filtro_mtr_atm',
       @w_fecha_ayer = dateadd(dd, -1, @i_fecha_proc)

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

If exists(select co_fecha_tran from cob_atm_his..tm_consumos_consorcio where co_fecha_tran = @w_fecha_ayer)  --Modificado 01/11/2007
 begin 
  exec cobis..sp_cerror
   @i_num    = 1903002,
   @t_from   = @w_sp_name
   return 1903002
 end
 
else

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
	 select 	th_fecha, th_tipo_tran, th_ssn_local, th_ssn_host,
		th_oficina, th_banco, th_producto, th_moneda, th_signo,
		th_causa, th_tarjeta_atm, convert(char(8),th_hora,108), th_monto5,
	        th_correccion, th_valor, 'N', th_estado_ejecucion,
		th_tasa4, th_cta_banco, convert(smallint, substring(th_campo4,datalength(th_campo4)- 2, 3)), th_monto9, --FES 220903
		th_control, th_tasa1, th_interes, th_terminal,
		th_ssn_local_correccion
          from cob_remesas_his..re_tran_monet_his with(index(re_tran_monet_his_fecha_Key))
	 where th_fecha   = @w_fecha_ayer
	   and th_oficina = 999
           and th_moneda  = 0
           and th_tipo_tran not in (130,140,150,540,550)
	   and th_tarjeta_atm not in ('6036449999999999998','6026929999999995')
                
       if @@error != 0
         begin
             exec cobis..sp_cerror
                 @i_num    = 150000,
	         @t_from   = @w_sp_name
             return 150000
         end

-- transacciones internacionales

     insert into cob_atm_his..tm_consumos_consorcio(
	         co_fecha_tran, co_tipo_tran, co_ssn_local, co_ssn_host,
		co_oficina, co_banco, co_prod_banc, co_moneda_bco, co_signo,
		co_causa, co_tarjeta, co_hora, co_consumo, co_reverso,
		co_consumo_me, co_estado_concilia, co_estado_transaccion,
		co_tasa_consorcio, co_cta_banco,co_moneda_mtr, co_consumo_dol,
		co_cod_error, co_tasa_bco, co_valor_comision_me, co_valor_uso_atm,
                co_cod_comercio, co_ssn_rev)
      select 	th_fecha, th_tipo_tran, th_ssn_local, th_ssn_host,
		th_oficina, th_banco, th_producto, th_moneda, th_signo,
		th_causa, th_tarjeta_atm, convert(char(8),th_hora,108), th_monto5,
	        th_correccion, th_valor, 'N', th_estado_ejecucion,
		th_tasa4, th_cta_banco, convert(smallint, substring(th_campo4,datalength(th_campo4)- 2, 3)), th_monto9, --FES 220903
		th_control, th_tasa1, th_interes, th_monto3,
	 	th_terminal, th_ssn_local_correccion	
       from cob_remesas_his..re_tran_monet_his with(index(re_tran_monet_his_fecha_Key))
      where th_fecha   = @w_fecha_ayer
	and th_oficina = 999
	and th_moneda >= 1
        and th_tipo_tran not in (130,140,150,540,550)
	and th_tarjeta_atm not in ('6036449999999999998','6026929999999995')
      
       if @@error != 0
         begin
             exec cobis..sp_cerror
                 @i_num    = 150000,
	         @t_from   = @w_sp_name
             return 150000
         end

/**** Actualizacion de los estatus de las transacciones ****/

update cob_atm_his..tm_consumos_consorcio
   set co_estado_transaccion = 'T'
 where co_fecha_tran = @w_fecha_ayer
   and co_estado_transaccion <> 'EE'
   and co_ssn_host is null
   and co_fecha_liq is null
   and co_estado_concilia = 'N'

if @@error != 0
 begin
     exec cobis..sp_cerror
         @i_num    = 150001,
         @t_from   = @w_sp_name
     return 150001
 end

update cob_atm_his..tm_consumos_consorcio
   set co_estado_transaccion = 'T'
 where co_fecha_tran = @w_fecha_ayer
   and co_estado_transaccion = 'EL'
   and co_ssn_host is not null
   and co_estado_concilia = 'N'
   and co_fecha_liq is null

if @@error != 0
 begin
     exec cobis..sp_cerror
         @i_num    = 150001,
         @t_from   = @w_sp_name
     return 150001
 end

update cob_atm_his..tm_consumos_consorcio
   set co_estado_transaccion = 'T'
 where co_fecha_tran = @w_fecha_ayer
   and co_estado_transaccion = 'EE'
   and co_ssn_host is not null
   and co_estado_concilia = 'N'
   and co_cod_error = 169020
   and co_fecha_liq is null

if @@error != 0
 begin
     exec cobis..sp_cerror
         @i_num    = 150001,
         @t_from   = @w_sp_name
     return 150001
 end

update cob_atm_his..tm_consumos_consorcio
   set co_estado_transaccion = 'D',
       co_rechazo = isnull((select substring(tt_trn_nombre,1,60) from cob_atm..tm_ttransaccion
				where tt_trn_cobis = convert (varchar(8),co_tipo_tran)),'TRANSACCION NO DEFINIDA')
 where co_fecha_tran = @w_fecha_ayer
   and co_estado_transaccion = 'EJ'
   and co_ssn_host is not null
   and co_estado_concilia = 'N'
   and co_fecha_liq is null

if @@error != 0
 begin
     exec cobis..sp_cerror
         @i_num    = 150001,
         @t_from   = @w_sp_name
     return 150001
 end

update cob_atm_his..tm_consumos_consorcio 
  set co_estado_transaccion = 'E', 
      co_fecha_liq = @w_fecha_ayer, 
      co_rechazo = isnull((select substring(ea_msg_1,1,60) 
                             from cob_atm..tm_errores_atm 
      			    where ea_numero = co_cod_error 
      			       and ea_srv_org = 'MAESTRO'),'MENSAJE DE ERROR NO DEFINIDO')
 where co_fecha_tran = @w_fecha_ayer
   and co_estado_transaccion = 'EE'
   and co_estado_concilia = 'N'
   and co_fecha_liq is null

if @@error != 0
 begin
     exec cobis..sp_cerror
         @i_num    = 150001,
         @t_from   = @w_sp_name
     return 150001
 end

update cob_atm_his..tm_consumos_consorcio
   set co_autoriza = convert(int,right('000000000000' + convert(varchar,co_ssn_local),6))
 where co_fecha_tran = @w_fecha_ayer
   and co_estado_concilia = 'N'
   and co_autoriza is null

if @@error != 0
 begin
     exec cobis..sp_cerror
         @i_num    = 150001,
         @t_from   = @w_sp_name
     return 150001
 end

update cob_atm_his..tm_consumos_consorcio
   set co_ssn_rev =  convert(int,right('000000000000' + convert(varchar,co_ssn_rev),6))
 where co_fecha_tran = @w_fecha_ayer
   and co_estado_concilia = 'N'
   and co_ssn_rev is not null

if @@error != 0
 begin
     exec cobis..sp_cerror
         @i_num    = 150001,
         @t_from   = @w_sp_name
     return 150001
 end

commit tran

return 0
go

IF OBJECT_ID('dbo.sp_filtro_mtr_atm') IS NOT NULL
    PRINT '<<< ALTER PROCEDURE dbo.sp_filtro_mtr_atm >>>'
ELSE
    PRINT '<<< FAILED ALTER PROCEDURE dbo.sp_filtro_mtr_atm >>>'
go

SET ANSI_NULLS OFF
go
SET QUOTED_IDENTIFIER OFF
go
