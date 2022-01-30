USE cob_atm_his
go

/************************************************************************/
/*  ARCHIVO:         sp_filtro_atm.sp			                      	*/
/*  NOMBRE LOGICO:   sp_filtro_atm.sp				               		*/
/*  PRODUCTO:        ATM                                        		*/
/************************************************************************/
/*                     PROPOSITO                                      	*/
/*	Migración ATM Server  												*/
/*                                                 						*/
/************************************************************************/
/*                     MODIFICACIONES                                 	*/
/*    FECHA         AUTOR               RAZON                         	*/
/*  16-Jun-2021   Adolfo Hernández  Emisión inicial (Migración ATMSRV) 	*/
/************************************************************************/

alter proc sp_filtro_atm (
        @i_fecha_proc     datetime = null
)
as


declare @w_fecha_ayer	datetime,
	@w_contador	int

/* FES Calculando fecha para ejecucion */
select @w_fecha_ayer = DATEADD(day, -1, @i_fecha_proc)

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
	insert into cob_atm_his..tm_consumos_atms(
		co_fecha_tran, co_tipo_tran, co_ssn_local, co_ssn_host, co_ssn_reverso,
		co_oficina, co_banco, co_prod_banc, co_moneda_bco, co_signo,
		co_causa, co_tarjeta, co_hora, co_consumo, co_reverso,
		co_estado_concilia, co_estado_transaccion, co_tipo_ejecucion,
		co_cta_banco, co_cod_error, co_valor_comision,	co_ssn_rev,
		co_autoriza, co_cajero)

	select 	th_fecha, th_tipo_tran, th_ssn_local, th_ssn_host, th_ssn_local_correccion,
		th_oficina, th_banco, th_producto, th_moneda, th_signo,
		th_causa, th_tarjeta_atm, convert(char(8),th_hora,108), th_valor, th_correccion,
	        'N', th_estado_ejecucion, th_tipo_ejecucion,
		th_cta_banco, th_control, th_monto3, th_ssn_local_correccion,
		th_departamento, th_usuario
--	from cob_atm_his..re_tran_monet_his (index = re_tran_monet_his_fecha_Key)
	from cob_remesas_his..re_tran_monet_his with(index(re_tran_monet_his_fecha_Key))
	where th_fecha = @w_fecha_ayer
	  and th_oficina <= 777
	  and th_srv_host = 'CARIBESRV'
	  and th_tipo_tran in (230,231,240,241,250,251)
          and th_moneda = 0
          and th_autorizada = 'R'

update cob_atm_his..tm_consumos_atms
set    co_fecha_liq = @i_fecha_proc,
       co_mensaje = isnull((select ea_msg_1 from cob_atm..tm_errores_atm
		      where ea_numero = co_cod_error),'MENSAJE DE ERROR NO DEFINIDO')
 where co_fecha_tran = @w_fecha_ayer
   and co_estado_concilia = 'N'
   and co_fecha_liq is null

commit tran

return 0
go

IF OBJECT_ID('dbo.sp_filtro_atm') IS NOT NULL
    PRINT '<<< ALTER PROCEDURE dbo.sp_filtro_atm >>>'
ELSE
    PRINT '<<< FAILED ALTER PROCEDURE dbo.sp_filtro_atm >>>'
go
