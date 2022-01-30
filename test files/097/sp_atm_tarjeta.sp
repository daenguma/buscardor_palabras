/************************************************************************/
/*  ARCHIVO:         sp_atm_tarjeta.sp			                		*/
/*  NOMBRE LOGICO:   sp_atm_tarjeta.sp				           			*/
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

alter proc sp_atm_tarjeta (
        @s_ssn			int 		= null,
        @s_user			login 		= null,
        @s_term			varchar(30) 	= null,
        @s_date			datetime 	= null,
        @s_srv			varchar(30) 	= null,
        @s_lsrv			varchar(30) 	= null,
        @s_ofi			smallint 	= null,
        @s_org          	char(1) 	= null,
        @t_debug		char(1) 	= 'N',
        @t_file			varchar(10) 	= null,
        @t_from			varchar(32) 	= null,
        @t_trn          	int 		= null,
        @i_operacion		char(2) 	= null,
	@i_modo			tinyint		= null,
	@i_tipo			char(1)		= null,
	@i_banco		tinyint 	= null,
	@i_tarjeta		int 		= null,
	@i_cliente		int 		= null,
	@i_codigo		cuenta 		= null,
	@i_estado_tarjeta	char(1)		= '%',
	@i_estado_tarjeta2	char(1)		= '%',
	@i_solicitada		char(1)		= null,
	@i_oficina		smallint	= null,
	@i_formato_fecha	smallint	= 101,
	@i_parametro		char(1)		= 'S',
	@i_proceso_val		varchar(5)	= null,
	@i_tipo_sol		char(3)		= null,
	@o_pin			int		= null out
)
as
declare @w_sp_name		varchar(32),
	@w_return 		int,
	@w_hoy			datetime,
	@w_formato		tinyint,
	@w_p_apellido		varchar(64),
	@w_s_apellido		varchar(64),
	@w_nombre		varchar(64),
	@w_nom_cli		varchar(192),
	@w_tabla		int,
	@w_mensaje		varchar (50),
	@w_dato0		varchar(20),
	@w_dato1		int,
	@w_dato2		int,
	@w_dato3		int,
	@w_dato4		varchar(20),
	@w_dato5		varchar(20),
	@w_dato6		char(1),
	@w_dato7		int,
	@w_dato8		char(1),
	@w_dato9		catalogo,
	@w_dato10		int,
	@w_dato11		int,
	@w_dato12		int,
	@w_dato13		varchar(11),
	@w_dato14		varchar(11),
	@w_dato15		varchar(11),
	@w_dato16		varchar(11),
	@w_dato17		varchar(11),
	@w_dato18		varchar(11),
	@w_dato19		varchar(11),
	@w_dato20		varchar(11),
	@w_dato21		varchar(16),
	@w_dato22		char(3),	
	@w_dato23		tinyint,
	@w_dato24		tinyint,
	@w_dato25		tinyint,
	@w_dato26		varchar(35),
	@w_dato27		smallint,
	@w_dato28		smallint,
	@w_dato30		varchar(20),
	@w_dato31		varchar(25),
	@w_dato32		varchar(25),
	@w_dato33		varchar(25),
	@w_dato34		int,
	@w_dato35		int,
	@w_dato36		int,
	@w_dato37		varchar(20),
	@w_dato38		varchar(20),
	@w_dato39		smallint,
	@w_dato40		smallint,
	@w_dato41		smallint,
	@w_dato42		smallint,
	@w_dato43		char(1),
	@w_dato44		catalogo,
	@w_dato45		int,
	@w_dato46		varchar(30),
	@w_dato55		catalogo

select @w_sp_name = 'sp_atm_tarjeta',
       @w_hoy     = convert (varchar(10), @s_date,101)
       	

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
		i_operacion		   = @i_operacion,
		i_banco			   = @i_banco,		
		i_tarjeta		   = @i_tarjeta,	
		i_codigo		   = @i_codigo,
		i_cliente		   = @i_cliente,
		i_estado_tarjeta	   = @i_estado_tarjeta	,
		i_formato_fecha		   = @i_formato_fecha
	  exec cobis..sp_end_debug
	end

/***************************** QUERY *************************************/
/* Usado por el mapeo a PMMapeaListaV					 */
if @i_operacion = 'Q'
   begin
     if @t_trn != 16629
     begin
	exec cobis..sp_cerror
		@t_debug	= @t_debug,
		@t_file		= @t_file,
		@t_from		= @w_sp_name,
		@i_num		= 161500
	return 1
     end

    select	
	@w_dato30= ta_codigo,
	@w_dato31= substring(ta_nombre_tarjeta,1,25),
	@w_dato32= ta_saludo,
	@w_dato33= substring(tt_nombre_tipo,1,25),
	@w_dato34= ta_propietario,
	@w_dato35= ta_pin_offset,
	@w_dato36= ta_principal,
	@w_dato37= isnull(substring(e.of_nombre,1,20),'NINGUNA'),
	@w_dato38= isnull(substring(d.of_nombre,1,20),'NINGUNA'),
	@w_dato0 = isnull(substring(c.of_nombre,1,20),'NINGUNA'),
	@w_dato21= ta_lugar_ult_mov,
	@w_dato1 = ta_cupo_online,
	@w_dato2 = ta_cupo_offline,
	@w_dato3 = ta_cupo_transf,
	@w_dato44= ta_estado_tarjeta,
	@w_dato55= ta_motivo,
	@w_dato6 = ta_retencion,
	@w_dato7 = ta_num_retencion,
	@w_dato8 = ta_confirmado,
	@w_dato9 = ta_tipo_sol_org,
	@w_dato10= ta_solicitud,
	@w_dato11= ta_sol_act,
	@w_dato12= ta_sol_can,
	@w_dato13= convert(varchar(10),ta_fecha_mante,@i_formato_fecha),
	@w_dato14= convert(varchar(10),ta_fecha_expiracion,@i_formato_fecha),
	@w_dato15= convert(varchar(10),ta_fecha_ult_mov,@i_formato_fecha),
	@w_dato16= convert(varchar(10),ta_fecha_entregada,@i_formato_fecha),
	@w_dato17= convert(varchar(10),ta_fecha_elaboracion,@i_formato_fecha),
	@w_dato18= convert(varchar(10),ta_fecha_sol,@i_formato_fecha),
	@w_dato19= convert(varchar(10),ta_fecha_act,@i_formato_fecha),
	@w_dato20= convert(varchar(10),ta_fecha_can,@i_formato_fecha)

	
    from cob_atm_his..tm_tarjeta 
		LEFT OUTER JOIN cobis..cl_oficina c
			on ta_ofi_ent	    = c.of_oficina 
		LEFT OUTER JOIN cobis..cl_oficina d
			on ta_ofi_actual    = d.of_oficina
		LEFT OUTER JOIN cobis..cl_oficina e
			on ta_ofi_org	    = e.of_oficina,
		cob_atm..tm_tipo_tarjeta
    where ta_banco	    = @i_banco
      and ta_tarjeta	    = @i_tarjeta
      and ta_tipo_tarjeta   = tt_tipo_tarjeta
     
      if @@rowcount = 0
          begin
            exec cobis..sp_cerror
            @t_debug	= @t_debug,
            @t_file	= @t_file,
            @t_from	= @w_sp_name,
            @i_num	= 161101
            return 1
          end

      if @w_dato34 > 0
      	 select	@w_nom_cli = ltrim(rtrim(en_nombre))
           from cob_bvirtual..bv_ente
          where en_ente_mis = @w_dato34
      else
	select	@w_nom_cli = '*** NO EXISTE CLIENTE ***'

      select @w_dato4 = valor from cobis..cl_catalogo
      where   @w_dato44 = codigo
      and tabla	    = (select cobis..cl_tabla.codigo
			    from cobis..cl_tabla
		            where cobis..cl_tabla.tabla = 'tm_estado_tarjeta')

      select @w_dato5 = valor
        from cobis..cl_catalogo
       where   @w_dato55 = codigo
         and tabla	    = (select cobis..cl_tabla.codigo
			    from cobis..cl_tabla
			    where cobis..cl_tabla.tabla = 'tm_motivo')
	if @w_dato5 is null
        select @w_dato5 = 'NO EXISTE MOTIVO'

    select	'CODIGO'	= @w_dato30 ,
		'NOMBRE'	= @w_dato31 ,
		'SALUDO'	= @w_dato32 ,
		'NOM. PROP.'	= @w_nom_cli,
		'TIPO'		= @w_dato33 ,
		'PRINCIPAL'	= @w_dato36 ,
		'ESTADO'	= @w_dato4 ,
		'MOTIVO'	= @w_dato5 ,
		'CUPO ONLINE'	= @w_dato1 ,
		'CUPO POS'	= @w_dato2 ,
		'CUPO TRANS'	= @w_dato3  ,
		'OFI. ORIGEN'   = @w_dato37 ,
		'OFI. ACTUAL'	= @w_dato38 , 
		'CONFIRMADA ?'	= @w_dato8 ,
		'FECHA ELABORACION'=@w_dato17 ,
		'FECHA DE ENTREGA' =@w_dato16 ,
		'FECHA MANTENIMIENTO' =@w_dato13 ,
		'FECHA EXPIRACION' =@w_dato14 ,
		'FECHA ULT MOV'	   =@w_dato15 ,
		'LUGAR ULT MOV'	   =@w_dato21 , 
		'FECHA SOL.EMISION'=@w_dato18 ,
		'FECHA SOL. ACT.'  =@w_dato19 ,
		'FECHA SOL. CAN.'  =@w_dato20, 
		'TIPO SOL.'	= @w_dato9 ,
		'SOL. CREAC.'	= @w_dato10 ,
		'SOL. ACTUALIZ'	= @w_dato11 ,
		'SOL. CANCEL.'	= @w_dato12 ,
		'RETENER?'	= @w_dato6 ,
		'NUM. RETEN.'	= @w_dato7 ,
		'PROPIET.'	= @w_dato34
	select @o_pin = @w_dato35
     return 0			     
   end
go
IF OBJECT_ID('dbo.sp_atm_tarjeta') IS NOT NULL
    PRINT '<<< ALTERED PROCEDURE dbo.sp_atm_tarjeta >>>'
ELSE
    PRINT '<<< FAILED ALTERING PROCEDURE dbo.sp_atm_tarjeta >>>'
go
