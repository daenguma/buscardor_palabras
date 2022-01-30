use webuser_bit
go
IF OBJECT_ID('dbo.bv_session_activa_1mc') IS NOT NULL
BEGIN
    PRINT '<<< PROCEDURE dbo.bv_session_activa_1mc WILL BE MODIFY  >>>'
END
go

/************************************************************/ 
/*   ARCHIVO:         bv_session_activa_1mc.sp              */ 
/*   NOMBRE LOGICO:   bv_session_activa_1mc                 */ 
/*   PRODUCTO:        ADMINBV                               */ 
/************************************************************/ 
/*                     PROPOSITO                            */ 
/*   Verificar si la session del cliente se encuentra       */
/*   activa para Banca Móvil                                */
/************************************************************/ 
/*                     MODIFICACIONES                       */ 
/*   FECHA        AUTOR           RAZON                     */ 
/*   03/02/2012   D.Betancourt    Emision inicial           */
/*   31/10/2014   D.Betancourt    Validar sesion nueva CB   */
/*   30/12/2020   Jose V.Ruiz     F.Ultima sesion APP  		*/
/*   22/07/2021   David Morla     Migracion ATMSRV  		*/
/************************************************************/ 

ALTER Procedure bv_session_activa_1mc
( 
	@i_session_id 		varchar(70),
	@i_servidor 		varchar(50),
	@i_modo 		int,
	@o_login		varchar(20) = null out,
	@o_ente			int= null out,
	@o_ente_mis		int= null out,
	@o_nombre		varchar(100)= null out,
	@o_cedula		varchar(30)= null out,
	@o_tipo			varchar(10)= null out,
	@o_fecha_ult_logon	datetime = null out,
	@o_perfil 		int = null out,
	@o_estado_perfil	varchar(2) = null out

)

as

declare @w_login		varchar(20),
	@w_ente			int,
	@w_cod_usuario		int,
	@w_tiempo		int,
	@w_hora_p		datetime,
	@w_hora			datetime,
	@w_sp_name		varchar(30),
	@w_hora_login		datetime

select @w_sp_name = 'bv_session_activa_1mc'

if @i_modo = 1
begin

	-- CANAL ESTA ACTIVO --
	IF EXISTS(SELECT 1 FROM cob_bvirtual..bv_servicio 
		   WHERE se_servicio = 1 
		     AND se_habilitado = 'H'
		     AND se_estado = 'V')
	BEGIN

		SELECT @w_login = tarjeta 
		  FROM webuser_bit..active_session
		 WHERE session_id = @i_session_id

		-- SESSION ESTA REGISTRADA --
		IF (@@rowcount = 0) or (@w_login is null) or (@w_login = '')
		BEGIN
			return 1888279
		END

		SELECT @w_cod_usuario = Codigo
		  FROM webuser_bit..USUARIO with (nolock)
		 WHERE NumTarjetaVirtual = @w_login

		SELECT @o_fecha_ult_logon = max(Fecha)
		  FROM webuser_bit..AUDITORIA with (nolock)
		 WHERE CodUsuario = @w_cod_usuario
		   AND CodOperacion = 15 --Conexion de usuario
		   AND Secuencial < (SELECT top 1 max(Secuencial) FROM webuser_bit..AUDITORIA with (nolock) WHERE CodUsuario = @w_cod_usuario AND CodOperacion = 15)

		-- 'Se asume la ultima conexion fue hace mas de un año '
		IF @o_fecha_ult_logon IS null
			SELECT @o_fecha_ult_logon = dateadd(yy,-1, getdate())

		SELECT @o_login = lo_login,
			@w_ente = lo_ente
		  FROM cob_bvirtual..bv_login with (nolock)
		 WHERE lo_login = @w_login
		   AND lo_servicio in (0,1)

		SELECT @o_ente = en_ente,
			@o_ente_mis = en_ente_mis,
			@o_nombre = en_nombre,
			@o_cedula = en_ced_ruc,
			@o_tipo = en_tipo
		   FROM cob_bvirtual..bv_ente with (nolock)
		  WHERE en_ente = @w_ente

		SELECT @o_perfil = es_perfil
		  FROM cob_bvirtual..bv_ente_servicio_perfil with (nolock)
		 WHERE es_ente = @w_ente 
		   AND es_servicio in (0,1)

		SELECT @o_estado_perfil = pa_status_perfil
		  FROM cob_bvirtual..bv_ente_servicio_perfil_afiliacion with (nolock)
		 WHERE pa_ente = @w_ente
		   AND pa_servicio = 1

		UPDATE webuser_bit..active_session with (rowlock)
		   SET fecha = getdate(),
		       servidor = @i_servidor,
		       canal = 9
		 WHERE session_id = @i_session_id

	END
	ELSE
	BEGIN
		-- CANAL NO ACTIVO --
		SELECT @w_hora = getdate()

		DELETE webuser_bit..active_session
		 WHERE fecha < @w_hora
		   AND canal = 9

		DELETE cob_bvirtual..bv_in_login WHERE il_login COLLATE DATABASE_DEFAULT not in (select tarjeta COLLATE DATABASE_DEFAULT from webuser_bit..active_session where canal = 9)  

		exec cobis..sp_cerror  
			@t_from       = @w_sp_name,
			@i_msg        = 'SERVICIO NO DISPONIBLE POR EL MOMENTO',
			@i_num        = 1888403

		return 1888403
	END
END

if @i_modo = 2
begin

	-- CANAL ESTA ACTIVO --
	IF EXISTS(SELECT 1 FROM cob_bvirtual..bv_servicio 
		   WHERE se_servicio = 1 
		     AND se_habilitado = 'H'
		     AND se_estado = 'V')
	BEGIN

		-- SESSION ESTA ACTIVA --
		SELECT @w_tiempo = isnull(pa_int,3) from cobis..cl_parametro where pa_producto = 'BV' and pa_nemonico = 'BMSK'
		SELECT @w_hora_p = getdate()
		SELECT @w_hora = dateadd(mi, -1*@w_tiempo, @w_hora_p)

		IF EXISTS (SELECT 1 
			     FROM webuser_bit..active_session 
			    WHERE session_id = @i_session_id 
			      AND  canal = 9)
		BEGIN

			SELECT @w_hora_login = fecha
			  FROM webuser_bit..active_session
			 WHERE session_id = @i_session_id
			   AND  canal = 9

			IF @w_hora_login < @w_hora
			BEGIN
				DELETE webuser_bit..active_session
				 WHERE session_id = @i_session_id
				   AND  canal = 9

				return 1888262
			END
			ELSE
			BEGIN
				UPDATE webuser_bit..active_session with (rowlock)
				   SET fecha = getdate()
				 WHERE session_id = @i_session_id
				   AND canal = 9
			END
		END
		ELSE
		BEGIN
			return 1888248
		END
	END
	ELSE
	BEGIN

		-- CANAL NO ACTIVO --
		SELECT @w_hora = getdate()

		DELETE webuser_bit..active_session
		 WHERE fecha < @w_hora
		   AND canal = 9

		DELETE cob_bvirtual..bv_in_login WHERE il_login COLLATE DATABASE_DEFAULT not in (select tarjeta COLLATE DATABASE_DEFAULT from webuser_bit..active_session where canal = 9)

		exec cobis..sp_cerror  
			@t_from       = @w_sp_name,
			@i_msg        = 'SERVICIO NO DISPONIBLE POR EL MOMENTO',
			@i_num        = 1888403

		return 1888403

	END
end

if @i_modo = 3
begin
	IF EXISTS (SELECT 1 
		     FROM webuser_bit..active_session 
		    WHERE session_id = @i_session_id)
	BEGIN

		UPDATE webuser_bit..active_session with (rowlock)
		   SET fecha = getdate()
		 WHERE session_id = @i_session_id

		if @@error != 0
		begin
			exec cobis..sp_cerror  
				@t_from       = @w_sp_name,
				@i_msg        = 'ERROR ACTUALIZANDO LA SESION DEL CLIENTE',
				@i_num        = 1888403
		end
	END
	ELSE
	BEGIN
		return 18011
	END
end

if @i_modo = 4 -- Creado para para verificar sesion de conexion bancaribe digital JVRB
begin

	-- CANAL ESTA ACTIVO --
	IF EXISTS(SELECT 1 FROM cob_bvirtual..bv_servicio 
		   WHERE se_servicio = 1 
		     AND se_habilitado = 'H'
		     AND se_estado = 'V')
	BEGIN

		SELECT @w_login = tarjeta 
		  FROM webuser_bit..active_session
		 WHERE session_id = @i_session_id

		-- SESSION ESTA REGISTRADA --
		IF (@@rowcount = 0) or (@w_login is null) or (@w_login = '')
		BEGIN
			return 1888279
		END

		SELECT @w_cod_usuario = Codigo
		  FROM webuser_bit..USUARIO with (nolock)
		 WHERE NumTarjetaVirtual = @w_login

		SELECT @o_fecha_ult_logon = max(Fecha)
		  FROM webuser_bit..AUDITORIA with (nolock)
		 WHERE CodUsuario = @w_cod_usuario
		   AND CodOperacion = 36 --Conexion de usuario
		   AND Secuencial < (SELECT top 1 max(Secuencial) FROM webuser_bit..AUDITORIA with (nolock) WHERE CodUsuario = @w_cod_usuario AND CodOperacion = 36)

		-- 'Se asume la ultima conexion fue hace mas de un año '
		IF @o_fecha_ult_logon IS null
			SELECT @o_fecha_ult_logon = dateadd(yy,-1, getdate())

		SELECT @o_login = lo_login,
			@w_ente = lo_ente
		  FROM cob_bvirtual..bv_login with (nolock)
		 WHERE lo_login = @w_login
		   AND lo_servicio in (0,1)

		SELECT @o_ente = en_ente,
			@o_ente_mis = en_ente_mis,
			@o_nombre = en_nombre,
			@o_cedula = en_ced_ruc,
			@o_tipo = en_tipo
		   FROM cob_bvirtual..bv_ente with (nolock)
		  WHERE en_ente = @w_ente

		SELECT @o_perfil = es_perfil
		  FROM cob_bvirtual..bv_ente_servicio_perfil with (nolock)
		 WHERE es_ente = @w_ente 
		   AND es_servicio in (0,1)

		SELECT @o_estado_perfil = pa_status_perfil
		  FROM cob_bvirtual..bv_ente_servicio_perfil_afiliacion with (nolock)
		 WHERE pa_ente = @w_ente
		   AND pa_servicio = 1

		UPDATE webuser_bit..active_session with (rowlock)
		   SET fecha = getdate(),
		       servidor = @i_servidor,
		       canal = 9
		 WHERE session_id = @i_session_id

	END
	ELSE
	BEGIN
		-- CANAL NO ACTIVO --
		SELECT @w_hora = getdate()

		DELETE webuser_bit..active_session
		 WHERE fecha < @w_hora
		   AND canal = 9

		DELETE cob_bvirtual..bv_in_login WHERE il_login COLLATE DATABASE_DEFAULT not in (select tarjeta COLLATE DATABASE_DEFAULT from webuser_bit..active_session where canal = 9)  

		exec cobis..sp_cerror  
			@t_from       = @w_sp_name,
			@i_msg        = 'SERVICIO NO DISPONIBLE POR EL MOMENTO',
			@i_num        = 1888403

		return 1888403
	END
END


return 0
go

IF OBJECT_ID('dbo.bv_session_activa_1mc') IS NOT NULL
    PRINT '<<< MODIFIED PROCEDURE dbo.bv_session_activa_1mc >>>'
GO