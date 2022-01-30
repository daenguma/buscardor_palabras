/******************************************************************/
/*    NOMBRE ARCHIVO: jusp_op_inicio_sesion.sp                    */
/*    PRODUCTO:        Autenticación Robusta Juridico             */
/******************************************************************/
/*                           PROPOSITO                            */
/* sp utilizado para insertar la sesiones de los clientes que     */
/* posean allnet entre sus productos y a su vez utilizados por    */
/* WS diseñado para realizar el SSO en allnett                    */
/******************************************************************/
/*                        MODIFICACIONES                          */
/*  FECHA              AUTOR              RAZON                   */
/*  13-ABR-2011        Edgar Castro       Emision Inicial         */
/*  20/0172013         Romero Aurymar     Cambios BIP             */
/*  01/10/2019         Jose V Ruiz        Boton desconexion       */
/*  11/10/2019         Jose V Ruiz        Grabar IP               */
/*  07/05/2020         David Morla        Consulta NTV ente - BM  */
/*  24/06/2020         David Morla        Sesion activa - BM  	  */
/*  20/08/2020         Joseph Gutierrez   Ingreso alias canal 13  */
/*  02/02/2021         Henderson Villegas Se incluye @o_login 	  */
/*  									  operacion Q			  */
/*  26/07/2021         Adolfo Hernández   Migración ATMSRV  	  */
/******************************************************************/

USE webuser_jur
GO

ALTER procedure [dbo].[jusp_op_inicio_sesion](@i_operacion char(1),
                                              @i_usuario varchar(50) = null,
                                              @i_sesion_id varchar(80) = null,
                                              @i_servidor varchar(20) = null,
                                              @i_aplicacion varchar(20) = null,
                                              @i_cliente_tdc char(1) = null,
                                              @i_tipo char(1)= 'N',
                                              @i_ip varchar(15) = null,
                                              @i_descripcion varchar(50) = 'INICIO DE SESION EXITOSO PROXY JURIDICO',
                                              @o_ntv varchar(30) = '                              ' out,
                                              @o_ente int = null out,
                                              @o_estado varchar(2) = null out,
											  @o_login varchar(50) = null out,
											  @o_serial varchar(50) = null out)
as
declare
    @w_sp_name               varchar(50),
    @w_estado                char(1),
    @w_ntv                   varchar(30),
    @w_ente                  int,
    @w_alias                 varchar(50),
    @w_fecha_desde           datetime,
    @w_fecha_hasta           datetime,
    @w_hoy                   datetime,
    @w_operacion             int,
    @w_descripcion_operacion varchar(500),
    @w_return                int,
    @w_login                 varchar(50),
	@w_serial                varchar(50)

-- Captura nombre de Stored Procedure
select @w_sp_name = 'jusp_op_inicio_sesion',
       @w_hoy = getdate()

--Valida que el usuario este registrado en bd y que no este bloqueado.
    if @i_operacion = 'S'
        begin
            if exists(select 1
                      from webuser_jur..ju_autorizados
                      where ja_login = @i_usuario
                        and ja_estado <> 'E')
                begin
                    select @w_estado = ja_estado,
                           @w_ntv = ja_ntv,
                           @w_ente = ja_ente,
                           @w_fecha_desde = ja_fecha_desde,
                           @w_fecha_hasta = ja_fecha_hasta
                    from webuser_jur..ju_autorizados
                    where ja_login = @i_usuario

                    if exists(select 1
                              from webuser_jur..ju_sesion_activa
                              where jsa_userid = @w_ntv)
                        begin
                            exec cobis..sp_cerror
                                 @t_from = @w_sp_name,
                                 @i_num = 1888260
                            return 1888260
                        end

                    if @w_estado = 'B' --Usuario Bloqueado
                        begin
                            exec cobis..sp_cerror
                                 @t_from = @w_sp_name,
                                 @i_num = 1888255
                            return 1888255
                        end
                    else
                        begin
                            if @w_estado = 'S' --Usuario Suspendido
                                begin
                                    exec cobis..sp_cerror
                                         @t_from = @w_sp_name,
                                         @i_num = 1888258
                                    return 1888258
                                end
                            else
                                if @w_estado = 'P' or @w_estado = 'A' or @w_estado = 'R'--Usuario que no han realizado la suscripcion
                                    begin
                                        exec cobis..sp_cerror
                                             @t_from = @w_sp_name,
                                             @i_num = 1888259
                                        return 1888259
                                    end
                                else
                                    begin
                                        if @w_estado = 'D'
                                            begin
                                                -- evaluar si el rango de fecha hasta fue superado.
                                                if @w_fecha_hasta < @w_hoy -- quiere decir que debe entrar el usuario
                                                    begin
                                                        update webuser_jur..ju_autorizados
                                                        set ja_fecha_desde=null,
                                                            ja_fecha_hasta=null,
                                                            ja_estado     ='V'
                                                        WHERE ja_login = @i_usuario
                                                        ---- retornar
                                                        select @o_ntv = @w_ntv
                                                        select @o_ente = @w_ente
                                                        return 0
                                                    end
                                                exec cobis..sp_cerror
                                                     @t_from = @w_sp_name,
                                                     @i_num = 1888281
                                                return 1888281
                                            end
                                        else
                                            begin
                                                -- EVALUAR SI EL NO HA SIDO DESACTIVADO CUANDO ESTABA SUSPENDIDO O

                                                -- BLOQUEADO
                                                IF (@w_fecha_hasta IS NOT NULL)
                                                    BEGIN
                                                        if @w_fecha_hasta > @w_hoy -- quiere decir que debe entrar el usuario
                                                            BEGIN
                                                                update webuser_jur..ju_autorizados
                                                                set ja_estado ='D'
                                                                WHERE ja_login = @i_usuario
                                                                exec cobis..sp_cerror
                                                                     @t_from = @w_sp_name,
                                                                     @i_num = 1888281

                                                                return 1888281
                                                                -- USUARIO INACTIVO
                                                            END
                                                        -- SINO RETORNO ES PORQUE LA FECHA HASTA CULMINO
                                                        -- POR LO TANTO DEBE LIMPIARSE LA FECHA Y PROSEGUIR
                                                        update webuser_jur..ju_autorizados
                                                        set ja_fecha_desde=null,
                                                            ja_fecha_hasta=null
                                                        WHERE ja_login = @i_usuario
                                                    END
                                                -- es Vigente
                                                select @o_ntv = @w_ntv
                                                select @o_ente = @w_ente
                                                return 0
                                            end
                                    end
                        end
                end
            else
                begin
                    exec cobis..sp_cerror
                         @t_from = @w_sp_name,
                         @i_num = 1888259
                    return 1888259
                end

        end -- fin @i_operacion = 'S'

--Valida que el usuario este registrado en bd
    if @i_operacion = 'Q'
        begin
            select @w_alias = ja_alias
            from webuser_jur..ju_autorizados
            where ja_alias = @i_usuario
            if @w_alias is not null
                begin
                    if exists(select 1
                              from webuser_jur..ju_autorizados
                              where ja_alias = @i_usuario
                                and ja_estado <> 'E')
                        begin
                            select @w_estado = ja_estado,
                                   @w_ntv = ja_ntv,
                                   @w_ente = ja_ente,
                                   @w_login  = ja_login,
								   @w_serial = ja_serial
                            from webuser_jur..ju_autorizados
                            where ja_alias = @i_usuario


                            -- es Vigente
                            select @o_ntv = @w_ntv
                            select @o_ente = @w_ente
                            select @o_estado = @w_estado
							select @o_serial = @w_serial
							select @o_login = @w_login
                            return 0
                        end
                    else
                        begin
                            exec cobis..sp_cerror
                                 @t_from = @w_sp_name,
                                 @i_num = 1888259
                            return 1888259
                        end
                end
            else
                begin
                    if exists(select 1
                              from webuser_jur..ju_autorizados
                              where ja_login = @i_usuario
                                and ja_estado <> 'E')
                        begin
                            select @w_estado = ja_estado,
                                   @w_ntv = ja_ntv,
                                   @w_ente = ja_ente,
                                   @w_login  = ja_login,
								   @w_serial = ja_serial
                            from webuser_jur..ju_autorizados
                            where ja_login = @i_usuario


                            -- es Vigente
                            select @o_ntv = @w_ntv
                            select @o_ente = @w_ente
                            select @o_estado = @w_estado
							select @o_serial = @w_serial
							select @o_login = @w_login
                            return 0
                        end
                    else
                        begin
                            exec cobis..sp_cerror
                                 @t_from = @w_sp_name,
                                 @i_num = 1888259
                            return 1888259
                        end
                end
        end
    ----Final operacion Q


--Inserta la sesion del cliente para evitar doble sesion del mismo login
    if @i_operacion = 'I'
        begin
            select @w_ntv = @i_usuario

            select @w_ente = ja_ente
            from webuser_jur..ju_autorizados
            where ja_ntv = @i_usuario

            select @w_operacion = 36

            if @i_tipo = 'N'
                begin
                    if exists(select 1
                              from webuser_jur..ju_sesion_activa
                              where jsa_userid = @i_usuario)
                        begin
                            exec cobis..sp_cerror
                                 @t_from = @w_sp_name,
                                 @i_num = 1888260
                            return 1888260
                        end

                    insert into webuser_jur..ju_sesion_activa
                    values (@i_sesion_id, GETDATE(), @i_usuario, GETDATE(), @i_servidor, @i_aplicacion,
                            @i_cliente_tdc)

                    if @@error != 0
                        begin
                            if @i_ip IS NOT NULL
                                begin
                                    --grabar auditoria al iniciar sesion y falla
                                    select @w_descripcion_operacion = 'ERROR INICIANDO SESION PROXY JURIDICO'
                                    exec @w_return = webuser_jur..jusp_graba_auditoria_usuario
                                                     @i_ntv = @w_ntv,
                                                     @i_user_id = @w_ente,
                                                     @i_operacion = @w_operacion,
                                                     @i_descripcion_operacion = @w_descripcion_operacion,
                                                     @i_ip = @i_ip
                                end
                            --retornar error 'ERROR INICIANDO SESION PROXY JURIDICO'
                            exec cobis..sp_cerror
                                 @t_from = @w_sp_name,
                                 @i_num = 1888267
                            return 1888267
                        end
                    if @i_ip IS NOT NULL
                        begin
                            --grabar auditoria
                            select @w_descripcion_operacion = 'INICIO DE SESION EXITOSO PROXY JURIDICO'
                            exec @w_return = webuser_jur..jusp_graba_auditoria_usuario
                                             @i_ntv = @w_ntv,
                                             @i_user_id = @w_ente,
                                             @i_operacion = @w_operacion,
                                             @i_descripcion_operacion = @w_descripcion_operacion,
                                             @i_ip = @i_ip
                        end
                end
            else
                begin
                    --grabar auditoria
                    exec @w_return = webuser_jur..jusp_graba_auditoria_usuario
                                     @i_ntv = @w_ntv,
                                     @i_user_id = @w_ente,
                                     @i_operacion = @w_operacion,
                                     @i_descripcion_operacion = @i_descripcion,
                                     @i_ip = @i_ip
                end
        end
    -- fin @i_operacion = 'I'

--Eliminar una session de la tabla sesion activa
    if @i_operacion = 'D'
        begin

            delete webuser_jur..ju_sesion_activa where jsa_userid = @i_usuario

            if @@error != 0
                begin
                    exec cobis..sp_cerror
                         @t_from = @w_sp_name,
                         @i_num = 1888267
                    return 1888267
                end

        end
    -- fin @i_operacion = 'I'

--Busca ntv y ente del cliente
    if @i_operacion = 'B'
        begin
            if exists(select 1
                      from webuser_jur..ju_autorizados
                      where ja_login = @i_usuario)
                begin
                    select @w_ntv = ja_ntv,
                           @w_ente = ja_ente,
                           @w_estado = ja_estado
                    from webuser_jur..ju_autorizados
                    where ja_login = @i_usuario

                    select @o_ntv = @w_ntv
                    select @o_ente = @w_ente

                    if @w_estado = 'S'
                        begin
                            exec cobis..sp_cerror
                                 @t_from = @w_sp_name,
                                 @i_num = 1888258
                            return 1888258
                        end

                end
            else
                begin
                    exec cobis..sp_cerror
                         @t_from = @w_sp_name,
                         @i_num = 1888259
                    return 1888259
                end
        end
    -- fin @i_operacion = 'B'


--Eliminar una session de la tabla sesion activa y de la tabla de logines activos con el boton desconexion
    if @i_operacion = 'E'
        begin

            select @w_ntv = ja_ntv
            from webuser_jur..ju_autorizados
            where ja_login = @i_usuario

            delete webuser_jur..ju_sesion_activa where jsa_userid = @w_ntv

            if @@error != 0
                begin
                    exec cobis..sp_cerror
                         @t_from = @w_sp_name,
                         @i_num = 1888267
                    return 1888267
                end

            delete from cob_bvirtual..bv_in_login where il_login = @w_ntv

            if @@error != 0
                begin
                    exec cobis..sp_cerror
                         @t_from = @w_sp_name,
                         @i_num = 1888267
                    return 1888267
                end
        end
-- fin @i_operacion = 'E'

-- Actualizar estado de contraseÃ±a vencida
	if @i_operacion = 'H'
	begin
		update webuser_jur..ju_autorizados
		set ja_password_vencido = @i_tipo
		where ja_alias = @i_usuario
		return 0
	end
-- fin @i_operacion = 'H'
    return 0
GO
if object_id('jusp_op_inicio_sesion') is not null
	PRINT '<<< ALTER PROCEDURE jusp_op_inicio_sesion >>>'
else
	PRINT '<<< FAILED ALTERING jusp_op_inicio_sesion >>>'
go
