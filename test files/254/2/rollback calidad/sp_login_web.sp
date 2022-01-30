SET ANSI_NULLS OFF
GO
SET QUOTED_IDENTIFIER OFF
GO

CREATE proc [dbo].[sp_login_web]
(
	@in_login            varchar(15),
	@in_password         varchar(100),
	@in_ip_address       varchar(15),
	@out_num_virtual     varchar(30) output,
	@out_last_logon      datetime output,
	@out_nombre          varchar(30) output,
	@out_status          varchar(1) output,
	@out_code            int output,
	@out_tipoEncrip      int = 0 output,
	@out_dias_x_vencer   int = 0 output
)
as

declare @w_nombre        varchar(40),
	@w_password          varchar(100),
	@w_num_virtual       varchar(40),
	@w_pwd               int,
	@w_contador          int,
	@w_fecha_ult_logon   datetime,
	@w_fecha_suma        datetime,
	@w_fecha_mod_pwd     datetime,
	@w_code              int,
	@w_status            varchar(1),
	@w_status_ant        varchar(1),
	@w_resultado         int,
	@w_cod_usuario       int, 
	@w_tipoEncrip        smallint,
	@w_dias_expira       int,
	@w_dias_usu_inactivo smallint,
	@w_intentos_password smallint 

/******************************/
/**** parametros Generales ****/
/******************************/

select @w_dias_usu_inactivo = Valor
  from SIST_PARAMETROS_GENERALES with (nolock) 
 where Etiqueta = 'NRO_DIAS_USUARIO_INACTIVO'

select @w_intentos_password = Valor
  from SIST_PARAMETROS_GENERALES with (nolock)
 where Etiqueta = 'NRO_INTENTOS_OLVIDO_CONTRASENA'

select @out_code = 0

/**************************************/
/***** "Buscar datos del Usuario" *****/
/**************************************/

select 	@w_num_virtual = NumTarjetaVirtual,
		@w_nombre = Nombre,
		@w_status = case CodEstadoUsuario
						when 0 then 'A' -- activo
						when 1 then 'S' -- Suspendido
						when 2 then 'B' -- Bloqueado 
					end,
		@w_cod_usuario = Codigo,
		@w_contador = ContadorConex,
		@w_fecha_ult_logon = FechaUltLogon
  from webuser_bit..USUARIO with (nolock)
 where Login = upper(@in_login)

--login o usuario no existe 
if @@rowcount = 0
begin 
	select @out_code = -1
	return @out_code
end 

/**************************************************************/        
/***** Se especifica codigo detalle de Login del usuario ******/
/**************************************************************/

select @out_code = case @w_status
						when  'A' then 0  --Activo
						when  'S' then -2 --suspendido 
						when  'B' then -3 --bloqueado 
						else  -10 -- Estatus de usuario Invalido
					end 

/*Retorna en caso de Error*/
if @out_code != 0
begin 
	if @out_code = -2 
		select  @w_code = 16
	else
	if @out_code = -3
		select  @w_code = 17
	else
		select  @w_code = 18

	insert into AUDITORIA values (getdate(),@w_cod_usuario, @w_code, @w_num_virtual, @in_ip_address,null, 'INTENTO FALLIDO DE CONEXION: ESTADO USUARIO ')

	if @@error != 0
		select  @out_code = -5
		return @out_code
	end 

/*************************************************/
/***** Se verificaron lo datos de la clave   *****/ 
/*************************************************/
       
	set rowcount 1

	select  @w_password = Clave,
			@w_fecha_mod_pwd = Fecha,
			@w_tipoEncrip = CodTipoEncriptacion,
			@w_dias_expira = CantidadDias
	  from webuser_bit..CLAVE with (nolock),
			webuser_bit..SIST_TIEMPO_EXPIRACION with (nolock)
	 where CodUsuario = @w_cod_usuario
	   and CodTiempoExpiracion = Codigo
	order by Fecha desc

/*****************************************/
/***** "Usuario sin clave definida " *****/
/*****************************************/

	if @@rowcount = 0
	begin
		select @out_code = -4

		insert into AUDITORIA values (getdate(),@w_cod_usuario, 18, @w_num_virtual, @in_ip_address,null , 'INTENTO FALLIDO DE CONEXION: CLAVE NO REGISTRADA' )

		if @@error != 0
			select  @out_code = -5
	end 

	set rowcount 0

	/*Retorna en caso de Error*/
	if @out_code != 0
		return @out_code

/****************************************/
/***** Busca fecha de ultimo Log-on *****/
/****************************************/
/*
	select @w_fecha_ult_logon 	= max (Fecha)
	  from webuser_bit..AUDITORIA with (nolock)
	 where CodUsuario = @w_cod_usuario
	   and CodOperacion = 15 --Conexion de usuario
*/
	-- "Se asume la ultima conexion fue hace mas de un año "
	if @w_fecha_ult_logon is null 
		select @w_fecha_ult_logon = dateadd(yy,-1, getdate())

	/*Se actualizan Variables de Salida*/    

	if isnull(@w_dias_expira,0) > 0
		select @w_fecha_suma = convert (varchar(10),dateadd(dd,@w_dias_expira,@w_fecha_mod_pwd),101)

	select	@out_num_virtual = @w_num_virtual,	
			@out_last_logon = @w_fecha_ult_logon,		
			@out_nombre	= @w_nombre,	
			@out_status	= @w_status,	
			@out_tipoEncrip =  @w_tipoEncrip,
			@out_dias_x_vencer = datediff (dd, @w_fecha_mod_pwd,@w_fecha_suma)      

	/*Retorna en caso de Error*/
	if @out_code != 0
		return @out_code

/*********************************/
/**** Validacion del password ****/
/*********************************/

	if @w_tipoEncrip = 0 -- Tipo Viejo siempre sera Vencido
	begin 
		select @out_code = -7 -- Password Vencido

		insert into AUDITORIA values (getdate(),@w_cod_usuario, 20, @w_num_virtual, @in_ip_address, null, 'INTENTO FALLIDO DE CONEXION: TIPO CLAVE VENCIDA')

		if @@error != 0
			select  @out_code = -5

		return @out_code
	end 

	if @w_tipoEncrip = 1
	begin 
		if @w_password = @in_password
			select @w_resultado = 1
		else 
			select @w_resultado = 0
	end 

	if @w_resultado = 1
		select @out_code = 0 --ok 
	else
	begin
		-- Password invalido
		select @out_code = -8

		/*Intento Fallido por password invalido*/
		begin tran

		insert into AUDITORIA values (getdate(),@w_cod_usuario, 19, @w_num_virtual, @in_ip_address, null,'INTENTO FALLIDO DE CONEXION POR CLAVE INCORRECTA')

		if @@error != 0
		begin 
			rollback tran 
			select  @out_code = -5
		end 

		update USUARIO
		   set ContadorConex = @w_contador + 1
		 where Codigo = @w_cod_usuario

		if @@error != 0
		begin 
			rollback tran 
			return @@error 
		end 

		commit tran 

		select @w_contador = @w_contador + 1

		if (@w_contador >= @w_intentos_password)
		begin
			/*Bloqueo del Usuario*/
			begin tran

			Update  USUARIO
			   set CodEstadoUsuario = 2
			 where Codigo = @w_cod_usuario

			if @@error != 0
				rollback tran
	
			insert into AUDITORIA values (getdate(),@w_cod_usuario, 3, @w_num_virtual, @in_ip_address, null, 'BLOQUEO DE USUARIO ')
	
			if @@error != 0
				rollback tran 

			commit tran 

			select @out_code = -3
		end 

		return @out_code
	end

	/*Vigencia de Clave */
	if isnull(@w_dias_expira,0) > 0
	begin 
		select @w_fecha_suma = convert (varchar(10),dateadd(dd,@w_dias_expira,@w_fecha_mod_pwd),101)

		if (@w_fecha_suma < getdate())
		begin
			select @out_code = -7 -- Password Vencido

			insert into AUDITORIA values (getdate(),@w_cod_usuario, 20, @w_num_virtual, @in_ip_address,null , 'INTENTO FALLIDO DE CONEXION: CLAVE VENCIDA')

			if @@error != 0
				select  @out_code = -5

			return @out_code
		end
	end 

/*************************************/         
/***** Por inactividad de usuario *****/
/*************************************/
/*
	select @w_fecha_suma = dateadd(dd,@w_dias_usu_inactivo,@w_fecha_ult_logon)
           
	if (@w_fecha_suma < getdate())
	begin 
		select @out_code = -6 -- Usuario inactivo

		/*Guarda Pista en Auditoria por bloqueo Automatico */
		begin tran

		update USUARIO
		   set CodEstadoUsuario = 2
		 where Codigo = @w_cod_usuario

		if @@error != 0
			rollback tran

		insert into AUDITORIA values (getdate(),@w_cod_usuario, 3, @w_num_virtual, @in_ip_address,null , 'BLOQUEO DE USUARIO --> Estado Previo: ' + @out_status )

		if @@error != 0
			rollback tran 

		commit tran 

		return @out_code
	end 
*/
/*******************************************************************/
/***** Se genera Registro en Auditoria para Evento de conexion *****/
/*******************************************************************/

	begin tran
	
	insert into AUDITORIA values (getdate(),@w_cod_usuario, 15, @w_num_virtual, @in_ip_address, null,'CONEXION EXITOSA DE USUARIO')

	if @@error != 0
	begin 
		rollback tran 
		select  @out_code = -5
		return @out_code
	end 

	update USUARIO
	   set ContadorConex = 0,
			ContadorOlvidoContrasena = 0,
			ContadorCambioContrasena = 0,
			FechaUltLogon = getdate()
	 where Codigo = @w_cod_usuario

	if @@error != 0
	begin 
		rollback tran 
		select  @out_code = -5
		return @out_code
	end 

	commit tran 

return 0

GO
