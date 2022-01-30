/************************************************************************/
/*  ARCHIVO:         sp_atm_consulta_sol.sp	                			*/
/*  NOMBRE LOGICO:   sp_atm_consulta_sol.sp				            	*/
/*  PRODUCTO:        ATM                                        		*/
/************************************************************************/
/*                     PROPOSITO                                      	*/
/*	Migraci�n ATM Server  												*/
/*                                                 						*/
/************************************************************************/
/*                     MODIFICACIONES                                 	*/
/*    FECHA         AUTOR           RAZON                         		*/
/*  08-Jul-2021     David Morla  	Emision inicial (Migraci�n ATMSRV) 	*/
/************************************************************************/

USE cob_atm_his
go

alter proc sp_atm_consulta_sol (
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
        @i_oficial		login 		= '%',
        @i_estado		catalogo	= '%',
	@i_solicitud		int		= null,
	@i_categoria		char(1)		= null,
	@i_formato_fecha	smallint 	= 101
	
	
)
as
declare @w_sp_name		varchar(32),
	@w_ofi_null		char(15)
 
select 	@w_sp_name  = 'sp_atm_consulta_sol',
	@w_ofi_null = 'NINGUNA'

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
		i_solicitud		   = @i_solicitud,
		i_categoria	  	   = @i_categoria,
		i_formato_fecha	  	   = @i_formato_fecha
    exec cobis..sp_end_debug
end

/***************** Consulta de solicitudes **************************/

  if @t_trn != 16624
     begin
	exec cobis..sp_cerror
		@t_debug	= @t_debug,
		@t_file		= @t_file,
		@t_from		= @w_sp_name,
		@i_num		= 161500
	return 1
     end

	select
	'CLIENTE'		= so_cliente,
	'NOMBRE'		= ltrim(rtrim(substring(ltrim(p_p_apellido) +' '+
				  ltrim(p_s_apellido) + ' ' + ltrim(en_nombre),1,30))),
	'CEDULA'		= isnull(en_ced_ruc, p_pasaporte),	--acm 02Nov99 en_ced_ruc,
	'FECHA DE SOLICITUD'	= convert(varchar(10),so_fecha,@i_formato_fecha),
	'TIPO'			= substring(ts_descripcion,1,25),
	'ESTADO'		= substring(a.valor,1,20),
	'OFICINA ORIGEN' = isnull(substring(b.of_nombre,1,15),@w_ofi_null),
	'OFICINA ENTREGA' = isnull(substring(c.of_nombre,1,15),@w_ofi_null),
	'OFICINA ELABORACION' = isnull(substring(d.of_nombre,1,15),@w_ofi_null),
	'PERSONA RETIRA'	= so_persona_retira,
	'OFICIAL'		= fu_nombre,
	'COMENTARIO'		= substring(so_comentario,1,25),
	'EST SOL'		= so_estado,
	'TIP SOL'		= so_tipo_solicitud,
	'OF  ORG'		= so_ofi_org,
	'OF  ENT'		= so_ofi_ent,
	'OF  ELA'		= so_ofi_elab,
	'PER'			= so_periodo
	from cob_atm_his..tm_solicitud
		 LEFT OUTER JOIN cobis..cl_funcionario 
			on so_oficial	= fu_login
	     LEFT OUTER JOIN cobis..cl_oficina b
			on so_ofi_org   = b.of_oficina
		 LEFT OUTER JOIN cobis..cl_oficina c
			on so_ofi_ent   = c.of_oficina
		 LEFT OUTER JOIN cobis..cl_oficina d
			on so_ofi_elab  = d.of_oficina,
	     cob_atm..tm_tipo_solicitud , cobis..cl_ente,
		 cobis..cl_catalogo a
	where so_categoria	= @i_categoria
	  and so_numero		= @i_solicitud
	  and so_oficial_neg	like @i_oficial
	  and so_estado		like @i_estado
	  and so_tipo_solicitud = ts_tipo_solicitud
	  and en_ente		= so_cliente
	  and so_estado		= a.codigo
	  and a.tabla		= (select cobis..cl_tabla.codigo
				  from cobis..cl_tabla
				  where cobis..cl_tabla.tabla =
				  'tm_estado_solicitud')
	  
	   if @@rowcount = 0
	  begin
	    exec cobis..sp_cerror
		@t_debug	= @t_debug,
		@t_file		= @t_file,
		@t_from		= @w_sp_name,
		@i_num		= 161151
	    return 1
	  end

      return 0

go
IF OBJECT_ID('dbo.sp_atm_consulta_sol') IS NOT NULL
    PRINT '<<< ALTERED PROCEDURE dbo.sp_atm_consulta_sol >>>'
ELSE
    PRINT '<<< FAILED ALTERING PROCEDURE dbo.sp_atm_consulta_sol >>>'
go
