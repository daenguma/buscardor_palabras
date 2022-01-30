USE webuser_bit
go
REVOKE EXECUTE ON dbo.bvsp_mantenimiento_cliente_ssl FROM [roleBancaMovil ]
go
IF OBJECT_ID('dbo.bvsp_mantenimiento_cliente_ssl') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.bvsp_mantenimiento_cliente_ssl
    IF OBJECT_ID('dbo.bvsp_mantenimiento_cliente_ssl') IS NOT NULL
        PRINT '<<< FAILED DROPPING PROCEDURE dbo.bvsp_mantenimiento_cliente_ssl >>>'
    ELSE
        PRINT '<<< DROPPED PROCEDURE dbo.bvsp_mantenimiento_cliente_ssl >>>'
END
go
SET ANSI_NULLS ON
go
SET QUOTED_IDENTIFIER ON
go
create procedure bvsp_mantenimiento_cliente_ssl(
			@s_ssn                int, 
			@s_user               login, 
			@s_sesn               int = null, 
			@s_term               varchar(30), 
			@s_date               datetime, 
			@s_srv                varchar(30), 
			@s_lsrv               varchar(30), 
			@s_ofi                smallint, 
                        @t_trn                int,
                        @i_operacion          varchar(2),
                        @i_codUsuario         int,  
                        @i_cod_estado         int

) as

  declare   @w_sp_name           varchar (30),
            @w_estado            tinyint,  
            @w_NTV               login,
            @w_cod_funcionario    int   
          
  select @w_sp_name = 'bvsp_mantenimiento_cliente_ssl'

 /************************************************************/
  /* LA TRANSACCION CORRESPONDE A UN MANTENIMIENTO CLIENTE     */
  /************************************************************/
if  @t_trn not in (18251, 18252) 
begin
   --ERROR EN EL REGISTRO DE LA TRANSACCION
    exec cobis..sp_cerror
          @t_from  = @w_sp_name,
          @i_num   = 1888173
        return 1
end 

if @i_operacion = 'D'
begin 

/* Obtengo estado actual */

   select @w_estado =  CodEstadoUsuario,
          @w_NTV    =  NumTarjetaVirtual
   from USUARIO where  Codigo = @i_codUsuario

  if @@rowcount = 0 
  begin 
      --No existe Usuario
      exec cobis..sp_cerror
          @t_from  = @w_sp_name,
          @i_num   = 1888172
        return 1
  end 

  /*Se valida el estado del Usuario con repecto a la Trn ejecutora*/

  if (@w_estado != 1 and @t_trn = 18252)
  begin 
      --Estado Invalido para Eliminacion 
      exec cobis..sp_cerror
          @t_from  = @w_sp_name,
          @i_msg = "NO PUEDE ELIMINAR UN USUARIO CON ESE ESTADO",
          @i_num   = 1888171
        return 1
  end 

  begin tran 

  /*Se Geenera registro para Auditoria de Suscripcion  */

   insert into SUSCRIPCION_AUDITORIA
    select convert (varchar(10),getdate(),101),
           getdate(),
           a.IdSuscripcion,
           22, --Eliminacion de Suscripcion 
           @w_NTV,
           @s_term,
           @s_user,
           convert(varchar(5),a.IdSuscripcion)+'|'+ 
	   a.NumeroTarjeta+'|'+
	   convert(varchar(2),a.CodTipoDoc)+'|'+
           --convert(varchar(10),NumDocumento)+'|'+
           convert(varchar(2),a.Estado)+'|'+
           a.Login+'|'+ 
           convert(varchar(2),a.TiempoExpiracion)+'|'+
           a.CorreoElectronico+'|'+
           a.NumeroCelular+'|'+
           convert(varchar(10),a.FechaSuscripcion, 101)+'|'+
           convert(varchar(2),a.ContadorFallas)+'|'+
           convert(varchar(2),a.Paso)
     from SUSCRIPCION a, 
          USUARIO f  
    where f.Codigo = @i_codUsuario
      and a.NumDocumento = f.NumDocumento

   if @@error != 0
   begin
      --ERROR AL INSERTAR EN LA BITACORA DE Suscripcion
      exec cobis..sp_cerror
           @t_from  = @w_sp_name,
           @i_num   = 1888168
        rollback tran
   return 1
   end 

/*Se Elimina Suscripcion */

   delete SUSCRIPCION
     from SUSCRIPCION a, 
          USUARIO f  
    where f.Codigo = @i_codUsuario
      and a.NumDocumento = f.NumDocumento

   if @@error != 0
   begin
      --ERROR Eliminar Suscripcion 
      exec cobis..sp_cerror
           @t_from  = @w_sp_name,
           @i_num   = 1888166
        rollback tran
   return 1
   end 


   
   /* Se genera Registro Auditoria */

   insert into AUDITORIA 
   select getdate(), 
          @i_codUsuario,
          5, --eliminacion de Usuario
          @w_NTV,
          @s_term,
          @s_user,
          convert(varchar(5),a.Codigo)+'|'+convert(varchar(5),CodTipoDocumento)+'|'+ b.Descripcion +'|'+
          '|'+NumDocumento +'|'+ Nombre +'|'+ Login +'|'+ NumTarjetaVirtual+'|'+convert(varchar(2),CodEstadoUsuario)+'|'+
          '|'+c.Descripcion+'|'+convert(varchar(2),ContadorConex)+'|'+convert(varchar(2),ContadorDesbloqueo)+
          '|'+convert(varchar(2),ContadorOlvidoContrasena)+'|'+convert(varchar(2),ContadorCambioContrasena)+
          '|'+convert(varchar(2),ContadorOlvidoLogin)+
          '|CL:'+convert(varchar(10),Fecha,101)+'|'+convert(varchar(2),CodTiempoExpiracion)
     from USUARIO a, 
          SIST_TIPO_DOCUMENTO b, 
          SIST_ESTADO_USUARIO c,
          CLAVE d
    where a.Codigo = @i_codUsuario
      and b.Codigo = a.CodTipoDocumento
      and c.Codigo = a.CodEstadoUsuario
      and d.CodUsuario = a.Codigo
      and d.Fecha = (select TOP 1 Fecha from CLAVE where CodUsuario = @i_codUsuario order by Fecha desc)

   if @@error != 0
   begin
      --ERROR AL INSERTAR EN LA BITACORA DE USUARIOS
      exec cobis..sp_cerror
           @t_from  = @w_sp_name,
           @i_num   = 1888165
        rollback tran
   return 1
   end 

  /* Se Elimina la Clave del usuario */

    delete CLAVE
    where CodUsuario = @i_codUsuario

   if @@error != 0
   begin
      --ERROR AL ELIMINAR REGISTROS DE LA TABLA DE CLAVES
      exec cobis..sp_cerror
           @t_from  = @w_sp_name,
           @i_num   = 1888164
        rollback tran
   return 1
   end 

  /* Se elminina al Usuario */

   delete USUARIO
   where  Codigo = @i_codUsuario    

   if @@error != 0
   begin
      --ERROR AL ELIMINAR REGISTRO DE LA TABLA DE USUARIO
      exec cobis..sp_cerror
           @t_from  = @w_sp_name,
           @i_num   = 1888175
        rollback tran
   return 1
   end 

  commit tran

return 0

end  --operacion D
go
SET ANSI_NULLS OFF
go
SET QUOTED_IDENTIFIER OFF
go
IF OBJECT_ID('dbo.bvsp_mantenimiento_cliente_ssl') IS NOT NULL
    PRINT '<<< CREATED PROCEDURE dbo.bvsp_mantenimiento_cliente_ssl >>>'
ELSE
    PRINT '<<< FAILED CREATING PROCEDURE dbo.bvsp_mantenimiento_cliente_ssl >>>'
go
GRANT EXECUTE ON dbo.bvsp_mantenimiento_cliente_ssl TO [roleBancaMovil ]
go
