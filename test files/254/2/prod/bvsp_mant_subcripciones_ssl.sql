USE webuser_bit
go
REVOKE EXECUTE ON dbo.bvsp_mant_subcripciones_ssl FROM [roleBancaMovil ]
go
IF OBJECT_ID('dbo.bvsp_mant_subcripciones_ssl') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.bvsp_mant_subcripciones_ssl
    IF OBJECT_ID('dbo.bvsp_mant_subcripciones_ssl') IS NOT NULL
        PRINT '<<< FAILED DROPPING PROCEDURE dbo.bvsp_mant_subcripciones_ssl >>>'
    ELSE
        PRINT '<<< DROPPED PROCEDURE dbo.bvsp_mant_subcripciones_ssl >>>'
END
go
SET ANSI_NULLS ON
go
SET QUOTED_IDENTIFIER ON
go
create procedure bvsp_mant_subcripciones_ssl(
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
                        @i_codSucrip          int,  
                        @i_cod_estado         int = null

) as

  declare   @w_sp_name           varchar (30),
            @w_estado            tinyint,  
            @w_paso              tinyint,
            @w_cod_funcionario    int   
          
  select @w_sp_name = 'bvsp_mant_subcripciones_ssl'

 /************************************************************/
  /* LA TRANSACCION CORRESPONDE A UN MANTENIMIENTO subcripciones     */
  /************************************************************/
if  @t_trn not in (18254, 18255) 
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

   select @w_estado =  Estado,
          @w_paso   =  Paso
   from SUSCRIPCION where  IdSuscripcion = @i_codSucrip

  if @@rowcount = 0 
  begin 
      --No existe Suscripcion
      exec cobis..sp_cerror
          @t_from  = @w_sp_name,
          @i_num   = 1888176
        return 1
  end 

 /*Se valida Si la Transccion viene por un ADMIN u otro*/

  if (@w_estado != 1 and @t_trn = 18255)
  begin 
      --Estado Invalido de Suscripcion
      exec cobis..sp_cerror
          @t_from  = @w_sp_name,
          @i_msg = "NO ESTA AUTORIZADO A ELIMINAR REGISTROS",
          @i_num   = 1888177
        return 1
  end 

  if (@w_paso = 5)
  begin 
      --La suscripcion pertenece a un Usuario del sistema 
      exec cobis..sp_cerror
          @t_from  = @w_sp_name,
          @i_msg = "NO PUEDE ELIMINAR UN REGISTRO CON PASO SUSCRITO",
          @i_num   = 1888178
        return 1
  end 

begin tran 
  /*Se Genera registro para Auditoria de Suscripcion  */
   insert into SUSCRIPCION_AUDITORIA
    select convert (varchar(10),getdate(),101),
           getdate(),
           a.IdSuscripcion,
           22, --Eliminacion de Suscripcion 
           NumeroTarjeta,  
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
     from SUSCRIPCION a 
    where IdSuscripcion = @i_codSucrip

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
     from SUSCRIPCION a 
   where IdSuscripcion = @i_codSucrip

   if @@error != 0
   begin
      --ERROR Eliminar Suscripcion 
      exec cobis..sp_cerror
           @t_from  = @w_sp_name,
           @i_num   = 1888166
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
IF OBJECT_ID('dbo.bvsp_mant_subcripciones_ssl') IS NOT NULL
    PRINT '<<< CREATED PROCEDURE dbo.bvsp_mant_subcripciones_ssl >>>'
ELSE
    PRINT '<<< FAILED CREATING PROCEDURE dbo.bvsp_mant_subcripciones_ssl >>>'
go
GRANT EXECUTE ON dbo.bvsp_mant_subcripciones_ssl TO [roleBancaMovil ]
go
