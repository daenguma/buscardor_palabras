/************************************************************************/
/*  ARCHIVO:         sp_atm_consulta_transf.sp			                */
/*  NOMBRE LOGICO:   sp_atm_consulta_transf.sp				            */
/*  PRODUCTO:        ATM                                        		*/
/************************************************************************/
/*                     PROPOSITO                                      	*/
/*	Migración ATM Server  												*/
/*                                                 						*/
/************************************************************************/
/*                     MODIFICACIONES                                 	*/
/*    FECHA         AUTOR           RAZON                         		*/
/*  08-Jul-2021     David Morla  	Emision inicial (Migración ATMSRV) 	*/
/************************************************************************/
USE cob_atm_his
go

alter proc sp_atm_consulta_transf (
        @s_ssn			int 		= null,
        @s_user			login 		= null,
        @s_term			varchar(30) 	= null,
        @s_date			datetime 	= null,
        @s_srv			varchar(30) 	= null,
        @s_lsrv			varchar(30) 	= null,
        @s_ofi			smallint 	= null,
        @s_org			char(1) 	= null,
        @t_debug		char(1) 	= 'N',
        @t_file			varchar(10) 	= null,
        @t_from			varchar(32) 	= null,
        @t_trn			int 		= null,
	@i_operacion		char(1)		= null,
	@i_modo			smallint	= null,
	@i_banco		tinyint		= null,
	@i_tarjeta		int		= null,
	@i_formato_fecha	smallint 	= 101
	
)
as
declare @w_sp_name		varchar(32),
	@w_ofi_null		char(15),
	@w_fun_null		char(15)
 
select  @w_sp_name  = 'sp_atm_consulta_transf',
	@w_ofi_null = 'NINGUNA',
	@w_fun_null = 'NN'

if @t_debug = 'S'
begin
    exec cobis..sp_begin_debug @t_file = @t_file
	select '/** Store Procedure **/ '  = @w_sp_name,
                s_ssn                      = @s_ssn,
                s_user                     = @s_user,
                s_term                     = @s_term,
                s_date                     = @s_date,
                s_srv                      = @s_srv,
                s_lsrv                     = @s_lsrv,
                s_ofi                      = @s_ofi,
		t_file			   = @t_file,
		t_from			   = @t_from,
                t_trn                      = @t_trn,
		i_operacion		   = @i_operacion,
		i_modo			   = @i_modo,
		i_banco			   = @i_banco,
		i_tarjeta		   = @i_tarjeta,
		i_formato_fecha		   = @i_formato_fecha
    exec cobis..sp_end_debug
end

/***************** Consulta de solicitudes de transferencia *******************/

  if @t_trn != 16628
     begin
	exec cobis..sp_cerror
		@t_debug	= @t_debug,
		@t_file		= @t_file,
		@t_from		= @w_sp_name,
		@i_num		= 161500
	return 1
     end

 begin
   set rowcount 20
	select
	'TIPO'			= tr_tipo,
	'FECHA INGRESO'		= convert(varchar(10),tr_fecha,@i_formato_fecha),
	'FUNCIONARIO'		= substring(a.fu_nombre,1,25),
	'OFICINA ORIGEN'     =isnull(substring(c.of_nombre,1,15),@w_ofi_null),
	'FECHA CONFIRMACION'	= convert(varchar(10),tr_fecha_con,@i_formato_fecha),
	'FUNCIONARIO CONFIRM'=isnull(substring(b.fu_nombre,1,25),@w_fun_null),
	'OFICINA DESTINO'    =isnull(substring(d.of_nombre,1,15),@w_ofi_null),
	'CONFIRMADO'		= tr_procesado,
	'MOTIVO'		= substring(valor,1,20),
	'OBSERVACION'		= substring(tr_observacion,1,20)
	from cob_atm_his..tm_transferencia
		LEFT OUTER JOIN cobis..cl_funcionario a
			on tr_funcionario	= a.fu_login
		LEFT OUTER JOIN cobis..cl_funcionario b
			on tr_fun_conf		= b.fu_login
		LEFT OUTER JOIN cobis..cl_oficina c
			on tr_ofi_org       = c.of_oficina
		LEFT OUTER JOIN	cobis..cl_oficina d
			on tr_ofi_des	= d.of_oficina,
		cobis..cl_catalogo
	where tr_banco		= @i_banco
	  and tr_tipo		like  @i_operacion
	  and tr_tarjeta        = @i_tarjeta
	  and tr_motivo		= codigo
	  and tabla		= (select cobis..cl_tabla.codigo
				   from cobis..cl_tabla
				   where cobis..cl_tabla.tabla = 
				   'tm_motivo')
	order by tr_tarjeta, tr_fecha_con
    set rowcount 0
    return 0
 end

go
IF OBJECT_ID('dbo.sp_atm_consulta_transf') IS NOT NULL
    PRINT '<<< ALTERED PROCEDURE dbo.sp_atm_consulta_transf >>>'
ELSE
    PRINT '<<< FAILED ALTERING PROCEDURE dbo.sp_atm_consulta_transf >>>'
go
