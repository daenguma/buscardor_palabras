/************************************************************/
/*   ARCHIVO:         jusp_datos_cliente_valida_clave.sp	*/
/*   NOMBRE LOGICO:   jusp_datos_cliente_valida_clave		*/
/*   PRODUCTO:        webuser_jur                           */
/************************************************************/
/*                     IMPORTANTE                           */
/************************************************************/
/*                     PROPOSITO                            */
/*   Stored Procedure para verificacion del password segun  */
/*   la nueva ley de canales electronicos articulo 5        */ 
/************************************************************/
/*                        MODIFICACIONES                    */
/*  FECHA             AUTOR               RAZON             */
/*  24/01/2012        Ivan Perez          Emision Inicial   */
/*  26/07/2021        Adolfo Hern�ndez    Migraci�n ATMSRV  */
/************************************************************/

USE webuser_jur
GO


ALTER PROCEDURE jusp_datos_cliente_valida_clave
					@i_ntv varchar(100) = null				

AS

DECLARE
	@w_cedula varchar(15)
		
BEGIN
 
	if exists (select top 1 * from webuser_jur..ju_autorizados where ja_ntv = @i_ntv)
		begin 
				select 
					ja_ente as [ente]
					,ja_login as [login]
					,ja_cedula as [cedula]
					,ja_p_apellido + ' ' + ja_p_nombre as [nombre]
					,null as [fecha_nacimiento]--debe ir el campo creado para la fecha de nacimiento en la tabla ju_autorizados (proyecto usuario maestro)
					,me_num_dir as [telefono]
					--*
				from 
					webuser_jur..ju_autorizados
					LEFT OUTER JOIN cob_bvirtual.."bv_medio_envio" ON index ja_ntv = me_login
				where 
					ja_ntv = @i_ntv
					--and ja_ente = me_ente
					and me_tipo = 'TELF'
					and me_servicio = 1
		end
	else
		begin
				select '-80', 'No existe cliente'
		end             
          
END
GO


IF OBJECT_ID('dbo.jusp_datos_cliente_valida_clave') IS NOT NULL
BEGIN
    --grant execute on jusp_datos_cliente_valida_clave to webuser
    PRINT '<<< ALTER PROCEDURE dbo.jusp_datos_cliente_valida_clave >>>'
   
END
ELSE
    PRINT '<<< FAILED ALTERING PROCEDURE dbo.jusp_datos_cliente_valida_clave >>>'
    



