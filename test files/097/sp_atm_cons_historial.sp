/************************************************************************/
/*  ARCHIVO:         sp_atm_cons_historial.sp			                */
/*  NOMBRE LOGICO:   sp_atm_cons_historial.sp				            */
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

alter proc sp_atm_cons_historial (
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
        @i_modo			tinyint 	= null,
        @i_categoria		char(1) 	= null,
	@i_solicitud		int		= null,
	@i_fecha		datetime	= null,
	@i_formato_fecha	smallint	= 101
)
as
declare @w_sp_name		varchar(32),
	@w_ofi_null		char(15)
 
select 	@w_sp_name  = 'sp_atm_cons_historial',
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
        	i_modo			   = @i_modo,
        	i_categoria	   = @i_categoria,
		i_solicitud	   	   = @i_solicitud,
		i_fecha			   = @i_fecha ,
		i_formato_fecha		   = @i_formato_fecha
    exec cobis..sp_end_debug
end

/***************** Consulta a historial de solicitud ***********************/

  if @t_trn != 16626
     begin
	exec cobis..sp_cerror
		@t_debug	= @t_debug,
		@t_file		= @t_file,
		@t_from		= @w_sp_name,
		@i_num		= 161500
	return 1
     end

     set rowcount 20
     if @i_modo = 0
	select	
	'ESTADO '		= substring(valor,1,20),
	'FECHA'			= convert(varchar(10),hi_fecha,@i_formato_fecha),
	'FUNC.'			= substring(hi_funcionario,1,15),
	'OFICINA'		= isnull(substring(of_nombre,1,15),@w_ofi_null),
	'COSTO'			= hi_costo,
	'OBSERVACIONES'		= substring(hi_observaciones,1,25)
	from cob_atm_his..tm_historial 
		LEFT OUTER JOIN cobis..cl_oficina 
		on hi_oficina	  = of_oficina,
		cobis..cl_catalogo
	where hi_categoria	  = @i_categoria
	  and hi_solicitud	  = @i_solicitud
	  and hi_estado_solicitud = codigo
	  and tabla		  = (select cobis..cl_tabla.codigo
				     from cobis..cl_tabla
				     where cobis..cl_tabla.tabla = 
				     'tm_estado_solicitud')
	order by hi_fecha

     if @i_modo = 1
	select	
	'ESTADO '		= substring(valor,1,20),
	/*'TIPO SOL.'		= ts_descripcion,*/
	'FECHA'			= convert(varchar(10),hi_fecha,@i_formato_fecha),
	'FUNC.'			= substring(hi_funcionario,1,15),
	'OFICINA'		= isnull(substring(of_nombre,1,15),@w_ofi_null),
	'COSTO'			= hi_costo,
	'OBSERVACIONES'		= substring(hi_observaciones,1,25)
	/*'EST SOL'		= hi_estado_solicitud,
	'OF'			= hi_oficina*/
	from cob_atm_his..tm_historial
		LEFT OUTER JOIN cobis..cl_oficina 
		on hi_oficina	  = of_oficina,
		cobis..cl_catalogo,
	     cob_atm..tm_tipo_solicitud
	where hi_categoria	  = @i_categoria
	  and hi_solicitud	  = @i_solicitud
	  and hi_tipo_solicitud   = ts_tipo_solicitud
	  and hi_fecha		  > @i_fecha
	  and hi_estado_solicitud = codigo
	  and tabla		  = (select cobis..cl_tabla.codigo
				     from cobis..cl_tabla
				     where cobis..cl_tabla.tabla = 
				     'tm_estado_solicitud')
	order by hi_fecha
    set rowcount 0
    return 0

go
IF OBJECT_ID('dbo.sp_atm_cons_historial') IS NOT NULL
    PRINT '<<< ALTERED PROCEDURE dbo.sp_atm_cons_historial >>>'
ELSE
    PRINT '<<< FAILED ALTERING PROCEDURE dbo.sp_atm_cons_historial >>>'
go
