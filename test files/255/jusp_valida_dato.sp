/******************************************************************/
/*    NOMBRE ARCHIVO: jusp_valida_dato.sp                         */
/*    PRODUCTO:        Autenticación Robusta Juridico             */
/******************************************************************/
/*                           PROPOSITO                            */
/******************************************************************/
/*                        MODIFICACIONES                          */
/*  FECHA              AUTOR              RAZON                   */
/*  13-ABR-2011        Edgar Castro       Emision Inicial         */
/*  26-JUL-2021        Adolfo Hernández	  Migración ATMSRV		  */
/******************************************************************/

use webuser_jur
go

ALTER procedure jusp_valida_dato (
  @i_operacion   char(1),
  @i_usuario     varchar(50) = null,
  @i_serial      varchar(30),
  @i_servidor    varchar(20) = null,
  @i_aplicacion  varchar(20) = null,
  @o_valiusu     varchar(1) = ' ' out,
  @o_valiser     varchar(1) = ' ' out,
  @o_ntv         varchar(30) = ' ' out,
  @o_ente        int         = null out
)
as
declare
  @w_sp_name varchar(50),
  @w_ntv varchar(30),
  @w_serial varchar(30),
  @w_estado char(1),
  @w_ente int
-- Captura nombre de Stored Procedure
select @w_sp_name = 'jusp_valida_dato'

--Valida que el usuario este registrado en bd y que no este suspendido y que no tengo sesion activa.
if @i_operacion = 'C'
begin
   select @o_valiser = 'N', @o_valiusu = 'N'
   
  if exists (select 1 
               from webuser_jur..ju_autorizados
              where ja_login = @i_usuario)
  begin
  
    select @w_ntv = ja_ntv, 
           @w_serial = ja_serial,
           @w_estado = ja_estado,
           @w_ente = ja_ente 
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
     
    if @w_estado = 'S'
    begin
      exec cobis..sp_cerror
         @t_from = @w_sp_name,
         @i_num = 1888258
      return 1888258
    end
    
    if @w_estado = 'A' or @w_estado = 'R' or @w_estado = 'P'
    begin
      exec cobis..sp_cerror
         @t_from = @w_sp_name,
         @i_num = 1888259--1888244
      return 1888259--1888244
    end
    
    if @i_serial = @w_serial
      select @o_valiser = 'S'
    
    select @o_valiusu = 'S', @o_ntv = @w_ntv, @o_ente = @w_ente
    
    return 0
  end
  else
  begin
    exec cobis..sp_cerror
         @t_from = @w_sp_name,
         @i_num = 1888270
    return 1888270
  end
  
end -- fin @i_operacion = 'C'

return 0
go

IF OBJECT_ID('dbo.jusp_valida_dato') IS NOT NULL
    PRINT '<<< ALTER PROCEDURE dbo.jusp_valida_dato >>>'
ELSE
    PRINT '<<< FAILED ALTERTING PROCEDURE dbo.jusp_valida_dato >>>'
go
