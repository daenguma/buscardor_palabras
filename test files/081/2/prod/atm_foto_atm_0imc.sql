USE cob_imagen_atm
go
REVOKE EXECUTE ON dbo.atm_foto_atm_0imc FROM user_adminfoto
go
REVOKE EXECUTE ON dbo.atm_foto_atm_0imc FROM role_adminfoto
go
IF OBJECT_ID('dbo.atm_foto_atm_0imc') IS NOT NULL
BEGIN
    DROP PROCEDURE dbo.atm_foto_atm_0imc
    IF OBJECT_ID('dbo.atm_foto_atm_0imc') IS NOT NULL
        PRINT '<<< FAILED DROPPING PROCEDURE dbo.atm_foto_atm_0imc >>>'
    ELSE
        PRINT '<<< DROPPED PROCEDURE dbo.atm_foto_atm_0imc >>>'
END
go
SET ANSI_NULLS ON
go
SET QUOTED_IDENTIFIER ON
go
create proc atm_foto_atm_0imc
/************************************************************************/
/*      Archivo:                atm_foto_atm_0imc.sp                    */
/*      Stored procedure:       atm_foto_atm_0imc                       */
/*      Base de datos:          cob_atm                                 */
/*      Producto:               ATM                                     */
/*      Disenado por:           Juan Abreu (JAB)                        */
/*      Fecha de escritura:     22-Oct-2009                             */
/************************************************************************/
/*                             IMPORTANTE                               */
/*      Este programa es parte de los paquetes bancarios propiedad      */
/*      de Bancaribe.                                                   */
/************************************************************************/
/*                              PROPOSITO                               */
/*      Interpreta los regitros que se encuentran en la tabla           */
/*      tm_BCACP_OK y los almacena en la tabla tm_tran_consorcio.       */
/************************************************************************/
/*                           MODIFICACIONES                             */
/*      FECHA           AUTOR           RAZON                           */
/*      22/Oct/2009     Juan Abreu      Emision Inicial.                */
/*      25/Oct/2010     F.Del Castillo  Apuntar select de la tabla      */
/*                                      im_trn_foto_atm a la vista      */
/*                                      tf_trans_foto_atm para integrar */
/*                                      la información de las tablas:   */
/*                          - cob_imagen_atm..im_trn_foto_atm           */
/*                          - cob_imagen_atm_ant..im_trn_foto_atm_his   */
/*                          - cob_imagen_atm_ant2..im_trn_foto_atm_his2 */
/************************************************************************/
(
        @i_nombre_arch      varchar(50)  = null     ,
        @i_fecha_trn        datetime     = null     ,
        @i_operacion        char(1)                 ,
        @i_modo             char(1)                 ,
        @i_ssn_local        int          = null     ,
        @i_traceultTDD      varchar(20)  = null     ,
        @i_foto             image        = null     ,
        @i_cajero           int          = null     ,
        @i_des_error        varchar(255) = null     ,
        @i_usuario          varchar(20)  = 'TOMCAT6',
        @i_terminal_ip      varchar(20)  = null     ,
        @i_edo_recup        char(1)      = 'C'      ,
        @i_fcha_ini         datetime     = null     ,
        @i_fcha_fin         datetime     = null     ,
        @i_ssn_host         int          = null     ,
        @i_fecha_ing        datetime     = null     ,
        @i_tarjeta          varchar(32)  = null     ,
        @i_tipo_archivo     varchar(32)  = null     ,
        @i_cta_banco        char(24)     = null     ,
        @i_tipo_tran        int          = null     ,
        @i_secuencial       int          = null     ,
        @i_comando          varchar(10)  = null     
)
as

declare @w_sp_name          varchar(30) ,
        @w_tipo             char(1)     ,
        @w_cajero           int         ,
        @w_ssn_local        int         ,
        @w_ssn_host         int         ,
        @w_fecha_trn        datetime    ,
        @w_hora_trn         datetime    ,
        @w_id_foto          int         ,
        @w_filial           tinyint     ,
        @w_producto         tinyint     ,
        @w_cta_banco        char(24)    ,
        @w_id_cajero        int         ,
        @w_tipo_tran        int         ,
        @w_tarjeta          varchar(32) ,
        @w_ssn_seqnos       int         ,
        @w_return           int         
        
select @w_sp_name = 'atm_foto_atm_0imc'

-----------------------------------
------------ CONSULTAS ------------
----------------------------------------------------------------------------------------------------------------------------------
if @i_operacion = 'C'
begin -- Ini @i_operacion = 'C'

   -------------------------------------
   ----- CONSULTA DE TRANSACCIONES -----
   -------------------------------------
   if @i_modo = '2'
   begin -- Ini @i_modo = '2'
      select 'ATM'           = tf_cajero,
             'Fecha_Trn.'    = tf_fecha_trn,
             'Hora_Trn.'     = convert(varchar, tf_hora_trn, 103) + ' ' + convert(varchar, tf_hora_trn, 108),
             'Tipo_Trn.'     = (select tt_trn_nombre 
                                  from cob_atm..tm_ttransaccion
                                 where tt_trn_cobis = tf_tipo_trn),
             'Sec._Local'    = tf_ssn_local,
             'trace_ultTDD'  = tf_cod_img, -- substring(tf_nro_tarjeta, datalength(tf_nro_tarjeta) - 6 + 1,6) + convert(varchar, tf_trace),
             'fecha_img'     = tf_fecha_img,
             'Sec._Host'     = tf_ssn_host,
             'Nro._Tarjeta'  = tf_nro_tarjeta,
             'Cta._Cliente'  = tf_cta_cliente,
             'Estado'        = tf_estado
      --from cob_imagen_atm..im_trn_foto_atm
        from cob_imagen_atm..tf_trans_foto_atm
       where tf_fecha_trn   >= @i_fcha_ini
         and tf_fecha_trn   <= @i_fcha_fin
         and (tf_cajero      = @i_cajero    or @i_cajero    is null)
         and (tf_ssn_local   = @i_ssn_local or @i_ssn_local is null)
         and (tf_nro_tarjeta = @i_tarjeta   or @i_tarjeta   is null)
         and (tf_cta_cliente = @i_cta_banco or @i_cta_banco is null)
         and (tf_tipo_trn    = @i_tipo_tran or @i_tipo_tran is null)
    order by 1, 2, 3
    return 0
   end -- Fin @i_modo = '2'
   
   -------------------------------------------
   ----- CONSULTA DETALLE DE TRANSACCION -----
   -------------------------------------------
   if @i_modo = '3'
   begin -- Ini @i_modo = '3'  
      select 'ATM'           = tf_cajero,
             'Fecha_Trn.'    = tf_fecha_trn,
             'Hora_Trn.'     = convert(varchar, tf_hora_trn, 103) + ' ' + convert(varchar, tf_hora_trn, 108),
             'Tipo_Trn.'     = (select tt_trn_nombre 
                                  from cob_atm..tm_ttransaccion
                                 where tt_trn_cobis = tf_tipo_trn),
             'Sec._Local'    = tf_ssn_local,
             'Sec._Host'     = tf_ssn_host,
             'Srv._Destino'  = tf_srv_host, 
             --'Nro._Tarjeta'  = tf_nro_tarjeta,
             'Nro._Tarjeta'  = substring(tf_nro_tarjeta, 1, 6) + REPLICATE( '*', datalength(tf_nro_tarjeta) - 9) + substring(tf_nro_tarjeta, datalength(tf_nro_tarjeta) - 2, 3),
             --'Cta._Cliente'  = tf_cta_cliente,
             'Cta._Cliente'  = substring(tf_cta_cliente, 1, 10) + REPLICATE( '*', datalength(rtrim(tf_cta_cliente)) - 13) + substring(tf_cta_cliente, datalength(rtrim(tf_cta_cliente))- 2, 3),
             'Estado'        = tf_estado
      --from cob_imagen_atm..im_trn_foto_atm
        from cob_imagen_atm..tf_trans_foto_atm
       where tf_ssn_local    = @i_ssn_local
         and tf_fecha_trn    = @i_fecha_trn
         and tf_cajero       = @i_cajero
         
   end -- Fin @i_modo = '3'
   
end -- Fin @i_operacion = 'C'
go
SET ANSI_NULLS OFF
go
SET QUOTED_IDENTIFIER OFF
go
IF OBJECT_ID('dbo.atm_foto_atm_0imc') IS NOT NULL
    PRINT '<<< CREATED PROCEDURE dbo.atm_foto_atm_0imc >>>'
ELSE
    PRINT '<<< FAILED CREATING PROCEDURE dbo.atm_foto_atm_0imc >>>'
go
GRANT EXECUTE ON dbo.atm_foto_atm_0imc TO role_adminfoto
go
GRANT EXECUTE ON dbo.atm_foto_atm_0imc TO user_adminfoto
go
