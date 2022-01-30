/* **********************************************************************/
/*  Archivo:		sp_atmsqr_concilia_s7b.sp                    	 	*/
/*  Stored procedure:	sp_atmsqr_concilia_s7b                   		*/
/*  Base de datos:	cob_atm_his                                  	 	*/
/*  Producto:		COBIS ATM Server - Aplicativo                	 	*/
/*  Disenado por:	C. Nu�ez                                     	 	*/
/*  Fecha de escritura:	Mayo 2005                                	 	*/
/* **********************************************************************/
/*                          PROPOSITO                            	 	*/
/*  Procesa la generacion del archivo de conciliacion de S7B     	 	*/
/* **********************************************************************/
/*                       MODIFICACIONES	                          		*/
/*  FECHA		        AUTOR                  RAZON			  		*/
/*  Mayo 2005           C. Nunez        Emision inicial           		*/
/*                                      CA-AT-01-05               		*/
/*  Agosto 2008		Ana Ramirez			Transmitir Todas las Trans		*/
/*                                      (EJ, EE, RV)              		*/
/*  09-sep-08		Marcelo Gaona		Para rev.enviar 1 solo reg	  	*/
/*  23-sep-08		Marcelo Gaona		Usar el op_code para armar	  	*/
/*										el tipo de transacci�n.   		*/
/*  22-oct-08		Marcelo Gaona		Cobro de recargo suiche7b 	  	*/
/*  19-may-18       V. Betancourt		Parametrizacion de codigo de    */
/*										moneda por la reconversion 		*/
/*										monetaria				  		*/
/*  25-feb-21	    V. Betancourt 		Separacion de trx de P2P-P2C-C2P*/
/************************************************************************/
USE cob_atm_his
go

ALTER PROCEDURE dbo.sp_atmsqr_concilia_s7b (
	@i_fecha_proc	datetime = NULL,
	@i_operacion	char(1) = NULL)
as
declare @w_servidor varchar(20),
        @w_id_red varchar(4),
        @w_id_banco varchar(4),
        @w_id_adquiriente varchar(11),
        @w_tabla int,
        @w_cantidad_reg int,
        @w_fecha_creacion datetime,
        @w_fecha_proceso datetime,		
		@w_moneda_iso     smallint

select @w_id_red = 'SU7B',
       @w_fecha_creacion = getdate()

select @w_id_banco = pa_char
  from cobis..cl_parametro
 where pa_producto = 'ATM'
   and pa_nemonico = 'ABA'

select @w_servidor = pa_char
  from cobis..cl_parametro
 where pa_producto = 'ATM'
   and pa_nemonico = 'SRVR'

select @w_id_adquiriente = se_codinst
  from cob_atm..tm_servers
 where se_nombre = 'SUICHE7B'

select @w_tabla = codigo
  from cobis..cl_tabla
 where tabla = 'tm_tipo_tran'

truncate table cob_atm_his..tm_concilia_s7b

select @w_moneda_iso = pa_smallint from cobis..cl_parametro
where pa_producto = 'ADM' and pa_nemonico = 'CODISO'

insert into cob_atm_his..tm_concilia_s7b
select tm_tarjeta_atm,
       @i_fecha_proc,
       tm_hora,
       tm_usuario,
       tm_srv_local,
       tm_srv_host,
       tm_ssn_local,
       tm_ssn_host,
       tm_control,
       tm_departamento,
       tm_tipo_tran,
       tm_cta_banco,
       (tm_valor + isnull(tm_val_recargo,0)),
       'ID de la Red' = @w_id_red,
       'ID del Banco' = @w_id_banco,
       'Numero de tarjeta' = ltrim(rtrim(tm_tarjeta_atm)) + replicate(' ', 19 - datalength(ltrim(rtrim(tm_tarjeta_atm)))), 
       'Accion sobre la transaccion' = case 
         when (tm_estado_ejecucion ='EJ') then 'ACC'
         when (tm_estado_ejecucion = 'RV' and tm_correccion = 'N' and tm_estado_correccion = 'R') then 'ACC'
         when (tm_estado_ejecucion = 'RV' and tm_correccion = 'S' and tm_estado_correccion = 'R') then 'REV'
         else 'REJ'
       end,
       'Indicador ACQ/ISS' = case tm_srv_local
         when 'ATMNTSRV' then 'A'
         when 'SUICHE7B' then 'I'
         else ' '
       end,
       'Monto de la transaccion' = replicate('0', 15 - datalength(convert(varchar, convert(bigint, (tm_valor + isnull(tm_val_recargo,0)) * 100)))) + convert(varchar, convert(bigint, (tm_valor + isnull(tm_val_recargo,0)) * 100)),
       'Tipo de transaccion' = valor,
       'Fecha de negocio' = substring(convert(varchar(10), @i_fecha_proc, 112), 3, 6),
       'Fecha de la transaccion' = substring(convert(varchar(10), tm_hora, 112), 3, 6),
       'Hora de la transaccion' = substring(replace(convert(varchar, tm_hora, 114), ':', ''), 1, 8),
       'Id. del emisor' = case tm_srv_host
         when 'SUICHE7B' then replicate('0', 11 - datalength(isnull(tm_login_aut, ''))) + isnull(tm_login_aut, '')
         when @w_servidor then @w_id_adquiriente
         else '00000000000'
       end,
       'Id. del adquiriente' = case tm_srv_local
         when 'ATMNTSRV' then @w_id_adquiriente
         when 'SUICHE7B' then replicate('0', 11 - datalength(isnull(tm_login_aut, ''))) + isnull(tm_login_aut, '')
         else '00000000000'
       end,
       'Identificador transaccion' = case tm_srv_host
       		  when 'SUICHE7B' then  replicate(0, 6 - datalength(convert(varchar(6),right(convert(varchar,tm_ssn_local),6)))) + convert(varchar(6),right(convert(varchar,tm_ssn_local),6))
		  when @w_servidor then replicate(0,6 - (datalength(((rtrim(convert(varchar, tm_tsn))))))) + (ltrim(rtrim(convert(varchar, tm_tsn))))  
        else
            '000000'
        end,

        'Identificacion del terminal' = case 
                  when tm_srv_local = 'ATMNTSRV' then replicate('0', 8 - datalength(ltrim(rtrim(tm_terminal)))) + ltrim(rtrim(tm_terminal))
                  when (tm_srv_local = 'SUICHE7B' and tm_estado_ejecucion = 'RV' and tm_correccion = 'S' and tm_estado_correccion = 'R') then ltrim(rtrim((select y.tm_terminal
													                                                     from cob_atm_his..re_tran_monet y												
                                                                                                                                                             where ((y.tm_oficina <= 777 and y.tm_srv_host = 'SUICHE7B')
                                                                                                                                                                or (y.tm_oficina = 888 and y.tm_srv_host = 'CARIBESRV' ))
                                                                                                                                                              and  y.tm_ssn_local = x.tm_ssn_local_correccion))) + replicate(' ', 8 - datalength(ltrim(rtrim((select y.tm_terminal
													                                                                                                                                                        from cob_atm_his..re_tran_monet y												
                                                                                                                                                                                                                                                                where ((y.tm_oficina <= 777 and y.tm_srv_host = 'SUICHE7B')
                                                                                                                                                                                                                                                                   or (y.tm_oficina = 888 and y.tm_srv_host = 'CARIBESRV' ))
                                                                                                                                                                                                                                                                  and  y.tm_ssn_local = x.tm_ssn_local_correccion)))))
                  when tm_srv_local = 'SUICHE7B' then ltrim(rtrim(tm_terminal)) + replicate(' ', 8 - datalength(ltrim(rtrim(tm_terminal))))
         else ' '
         end,
       'Numero de Referencia' = replicate('0', 12 - datalength(ltrim(rtrim(tm_departamento)))) + ltrim(rtrim(tm_departamento)),
       'Fecha del terminal' = substring(convert(varchar(10), tm_hora, 112), 3, 6),
       'Hora del terminal' = substring(replace(convert(varchar, tm_hora, 114), ':', ''), 1, 8),
       'Numero de Cuenta' = isnull(tm_cta_banco, '') + replicate(' ', 28 - datalength(isnull(tm_cta_banco, ''))),
       'Estatus de excepcion' = '   ',
       'Tipo de ajuste' = ' ',
       'Tipo de excepcion' = ' ',
       'Monto del ajuste' = replicate('0', 15),
       'ID. Moneda' = convert(varchar,@w_moneda_iso),
       'Ubicacion del terminal' =  case
           when (tm_estado_ejecucion = 'RV' and tm_correccion = 'S' and tm_estado_correccion = 'R') then isnull(ltrim(rtrim(isnull((select y.tm_campo5
													                              from cob_atm_his..re_tran_monet y												
                                                                                                                                     where ((y.tm_oficina <= 777 and y.tm_srv_host = 'SUICHE7B')
                                                                                                                                        or (y.tm_oficina = 888 and y.tm_srv_host = 'CARIBESRV' ))
                                                                                                                                       and  y.tm_ssn_local = x.tm_ssn_local_correccion), 'TEMPORAL'))) + replicate(' ',40 - datalength(ltrim(rtrim(isnull((select y.tm_campo5
													                                                                                                                                                          from cob_atm_his..re_tran_monet y												
                                                                                                                                                                                                                                 where ((y.tm_oficina <= 777 and y.tm_srv_host = 'SUICHE7B')
                                                                                                                                                                                                                                    or (y.tm_oficina = 888 and y.tm_srv_host = 'CARIBESRV' ))
                                                                                                                                                                                                                                   and  y.tm_ssn_local = x.tm_ssn_local_correccion), 'TEMPORAL'))))), replicate(' ', 40))
          else isnull(ltrim(rtrim(isnull(tm_campo5, 'TEMPORAL'))) + replicate(' ',40 - datalength(ltrim(rtrim(isnull(tm_campo5, 'TEMPORAL'))))), replicate(' ', 40))
       end,
       'Codigo de respuesta' = case
         when tm_estado_ejecucion = 'EJ' then '00'
         when tm_estado_ejecucion = 'RV' then '00'
         when tm_control is not null then isnull((select er_error_red
                                                    from cob_atm..tm_errores_red
                                                   where er_error_cobis = x.tm_control
                                                     and er_srv = 'SUICHE7B'), '05')
      
         else '05'
       end,
       'Numero de autorizacion' = case 
       		  when (tm_srv_host = 'CARIBESRV' and tm_estado_ejecucion = 'EJ')  then  replicate(0, 6 - datalength(convert(varchar(6),right(convert(varchar,tm_ssn_local),6)))) + convert(varchar(6),right(convert(varchar,tm_ssn_local),6))
		  when (tm_srv_host = 'SUICHE7B' and tm_estado_ejecucion = 'EJ' and tm_autorizada = 'R') then replicate(0,6 - (datalength(((rtrim(convert(varchar, tm_ssn_host))))))) + (ltrim(rtrim(convert(varchar, tm_ssn_host))))  
		  when (tm_srv_host = 'SUICHE7B' and tm_estado_ejecucion = 'EJ' and tm_autorizada in ('T', 'C') ) then  replicate(0, 6 - datalength(convert(varchar(6),right(convert(varchar,tm_ssn_local),6)))) + convert(varchar(6),right(convert(varchar,tm_ssn_local),6))
                  when (tm_srv_host = 'CARIBESRV' and tm_estado_ejecucion = 'RV' 
                    and tm_correccion = 'N' and tm_estado_correccion = 'R')  then  replicate(0, 6 - datalength(convert(varchar(6),right(convert(varchar,tm_ssn_local),6)))) + convert(varchar(6),right(convert(varchar,tm_ssn_local),6))
                  when (tm_srv_host = 'CARIBESRV' and tm_estado_ejecucion = 'RV' 
                    and tm_correccion = 'S' and tm_estado_correccion = 'R')  then  replicate(0, 6 - datalength(convert(varchar(6),right(convert(varchar,tm_ssn_local_correccion),6)))) + convert(varchar(6),right(convert(varchar,tm_ssn_local_correccion),6))
         else
            '000000'
        end

  from cob_atm_his..re_tran_monet x
       right outer join cobis..cl_catalogo
	   on codigo = isnull(ltrim(tm_proc_code),convert(varchar, tm_tipo_tran))
 where ((tm_oficina <= 777 and tm_srv_host = 'SUICHE7B')
    or  (tm_oficina = 888 and tm_srv_host = @w_servidor )) -- and tm_estado_ejecucion = 'EJ'
  -- and tm_autorizada = 'R'
  -- and tm_ssn_local_correccion is null
   and (not(tm_estado_ejecucion = 'RV' and tm_correccion = 'N' and tm_estado_correccion = 'R'))
   and tabla = @w_tabla
   and estado = 'V'

update cob_atm_his..tm_concilia_s7b
set cs_autoriza='      '
where right(convert(varchar(20),co_ssn_local),6)=right(convert(varchar(20),co_ssn_host),6)



update cob_atm_his..tm_concilia_s7b
   set cs_emisor = '00000000559'
  from cob_atm..tm_banco
 where ba_tipo_cnx = 'CNXS'
   and convert(int, cs_emisor) = convert(int, ba_codigo)

update cob_atm_his..tm_concilia_s7b
   set cs_adquiriente = '00000000559'
  from cob_atm..tm_banco
 where ba_tipo_cnx = 'CNXS'
   and convert(int, cs_adquiriente) = convert(int, ba_codigo)

return 0
go

SET ANSI_NULLS OFF
go
SET QUOTED_IDENTIFIER OFF
go
IF OBJECT_ID('dbo.sp_atmsqr_concilia_s7b') IS NOT NULL
    PRINT '<<< ALTER PROCEDURE dbo.sp_atmsqr_concilia_s7b >>>'
ELSE
    PRINT '<<< FAILED ALTER PROCEDURE dbo.sp_atmsqr_concilia_s7b >>>'
go
