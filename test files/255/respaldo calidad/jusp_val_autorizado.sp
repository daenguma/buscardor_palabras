USE [webuser_jur]
GO

/****** Object:  StoredProcedure [dbo].[jusp_val_autorizado]    Script Date: 08/11/2021 9:00:25 a. m. ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO



/************************************************************/  
/*   ARCHIVO:         jusp_val_autorizado .sp               */  
/*   NOMBRE LOGICO:   jusp_val_autorizado                   */  
/************************************************************/  
/*                     MODIFICACIONES                       */  
/*  FECHA       AUTOR               RAZON                   */  
/*  23/04/2012  Aurymar Romero      Emision Inicial         */  
/************************************************************/  
  
CREATE Procedure [dbo].[jusp_val_autorizado](  
@s_ssn               int          = null,  
@s_user              varchar(20),  
@s_term              varchar(30),  
@s_date              datetime,  
@s_servicio          tinyint,  
@s_rol               smallint     = 1,  
@s_ofi               smallint,  
@s_srv               varchar(30)  = null,  
@s_lsrv              varchar(30)  = null,  
@i_cedula            varchar(30),  
@i_perfil            smallint = 0,  
@i_cliente           int = 0,  
@i_login             varchar(20) = " "   
)  
As  
declare    
         @w_ja_ntv    varchar(20) ,  
         @w_cedula    varchar(30),  
         @w_servicio    int,    
   @w_login     varchar(20) ,  
   @w_clave_temp        varchar(64),   
   @w_clave_def         varchar(64),     
   @w_fecha_reg         datetime,     
   @w_tipo_vigencia     varchar (10),      
   @w_dias_vigencia     int,   
   @w_parametro          varchar (10),    
   @w_renovable    char(1)   ,      
   @w_descripcion    varchar(64),     
         @w_autorizado    varchar(30),   --BBO 17-02-2000      
         @w_tipo_autorizacion varchar(10),   
         @w_tarj_maestro      varchar(32),    
         @w_estado_afilia     char(1),     
         @w_truepass_dn       varchar(100),      
         @w_edo_truepass_dn   char(1),   
         @w_intentos_fallidos smallint,  
         @w_sp_name     varchar(64),  
         @w_cliente     int   
  
select  @w_sp_name  = 'jusp_val_autorizado'  
-- buscar perfil de usuario maestro o grupo economico  
  
  
if exists( select  1 from webuser_jur..ju_autorizados  
             where  ja_cedula= @i_cedula  
                and ja_ntv is not null  
    and ja_ente= @i_cliente)  
 begin  
   
-- creo un cursor por si acaso existe mas de un login para el mismo   
-- usuario  
declare curLogin cursor for select ja_ntv,  
           ja_cedula   
                                from webuser_jur..ju_autorizados  
                                 where ja_cedula= @i_cedula  
                                   and ja_ntv not in (@i_login)  
           and ja_ente= @i_cliente  
  
open curLogin  
  fetch curLogin into  @w_ja_ntv,@w_cedula   
  
  if @@fetch_status <> 0  
  begin  
    close curLogin  
    deallocate curLogin  
    return 1  
  end  
while @@fetch_status = 0  
  begin   
     -- borra los datos de los logines existentes  
    delete bv_notif_login_prod     
    where nl_login = @i_login     
    if @@error != 0     
    begin     
      /* Error en la desasociacion de notificacion*/     
  
     return 1850159     
    end     
    delete bv_notif_login_envio     
     where ne_login = @i_login     
          
    if @@error != 0      
    begin           
      /*Error en la eliminacion de medio de envio*/                                                                                                                                                                                                            
                      
    
      return 1850169      
    end     
    /*Eliminar el perfil por ente y servicio */     
    delete bv_ente_servicio_producto     
    where ep_login = @i_login     
    if @@error != 0     
    begin     
      /* Error en la eliminacion de producto por ente y servicio */     
      
      return 1850090     
    end    
    /* Insertar en la transaccion de servicio*/        
    insert into ts_ente_servicio_perfil(        
    secuencial,        
    tipo_transaccion,        
    clase,        
    fecha,        
    usuario,        
    terminal,        
    oficina,        
    tabla,      
    lsrv,        
    srv,        
    ente,        
    servicio,        
    perfil,        
    login,        
    estado     
       
    )        
    values (        
      @s_ssn,18522,'D',@s_date, @s_user, @s_term,@s_ofi, 'bv_ente_servicio_producto', @s_lsrv, @s_srv,        
      @i_cliente, 1, @i_perfil, @i_login,'A'       
     )    --BBO 17-02-2000      
        
    if @@error != 0        
    begin             
      /*Error en la insercion en la tabla de servicio*/        
        
      return 1        
    end        
  
    delete cob_bvirtual..bv_doble_autorizacion    
    where da_servicio   = 1    
      and da_ente       = @i_cliente    
      and (da_login     = @i_login)    
    if @@error != 0    
    begin    
    -- Error en eliminacion de autorizacion de cliente    
           
    
       return 1850212    
    end     
      
   delete cob_bvirtual..bv_doble_autorizacion    
    where da_servicio   = 1    
      and da_ente       = @i_cliente  
      and da_login      = @i_login    
    if @@error != 0    
    begin    
    -- Error en eliminacion de autorizacion de cliente    
      
       return 1    
     end    
      
   -- borra en la servicio perfil  
    delete bv_ente_servicio_perfil        
    where es_ente     = @i_cliente        
      and es_servicio = 1        
      and es_perfil   = @i_perfil        
      and es_login    = @i_login        
        
    if @@error != 0        
    begin             
      /* Error en la eliminacion de perfil por ente y servicio */        
       
      return 1        
    end        
            
    /* Insertar en la transaccion de servicio*/        
    insert into ts_ente_servicio_perfil(        
    secuencial,        
    tipo_transaccion,        
    clase,        
    fecha,        
    usuario,        
    terminal,        
    oficina,        
    tabla,        
    lsrv,        
    srv,        
    ente,        
    servicio,        
    perfil,        
    login,        
    estado     
       
    )        
    values (        
      @s_ssn,18519,'D',@s_date, @s_user, @s_term,@s_ofi, 'bv_ente_servicio_perfil', @s_lsrv, @s_srv,        
      @i_cliente, 1, @i_perfil, @i_login,'A'       
     )    --BBO 17-02-2000      
        
    if @@error != 0        
    begin             
      /*Error en la insercion en la tabla de servicio*/        
             
      return 1850034     
    end        
       /*Eliminar el medio */     
    delete bv_medio_envio     
    where me_envio =  ( select me_envio from cob_bvirtual..bv_medio_envio    
   where me_ente = @i_cliente  
     and me_servicio = 1  
     and me_login = @i_login)  
     
    if @@error != 0     
    begin     
      /*Error en la eliminacion de la medio de envio*/     
        
      return  1850163    
    end     
   /* Insertar en la transaccion de servicio*/        
    insert into ts_ente_servicio_perfil(        
    secuencial,        
    tipo_transaccion,        
    clase,        
    fecha,        
    usuario,        
    terminal,        
    oficina,        
    tabla,        
    lsrv,        
    srv,        
    ente,        
    servicio,        
    perfil,        
    login,        
    estado     
       
    )        
    values (        
      @s_ssn,18580,'D',@s_date, @s_user, @s_term,@s_ofi, 'bv_medio_envio', @s_lsrv, @s_srv,        
      @i_cliente, 1, @i_perfil, @i_login,'A'       
     )    --BBO 17-02-2000      
        
    if @@error != 0        
    begin             
      /*Error en la insercion en la tabla de servicio*/        
          
      return 1850034        
    end       
   -- eliminar login  
    select      
      @w_cliente  = lo_ente,      
      @w_servicio = lo_servicio,      
      @w_login = lo_login,      
      @w_clave_temp = lo_clave_temp,      
      @w_clave_def = lo_clave_def,      
      @w_fecha_reg = lo_fecha_reg,      
      @w_tipo_vigencia=lo_tipo_vigencia,      
      @w_dias_vigencia=lo_dias_vigencia,      
      @w_parametro=lo_parametro,      
      @w_renovable ='N',      
      @w_descripcion = lo_descripcion,      
      @w_autorizado = lo_autorizado,   --BBO 17-02-2000      
      @w_tipo_autorizacion = lo_tipo_autorizacion,    
      @w_tarj_maestro      = lo_tarj_maestro, --HWO claves MAESTRO    
      @w_estado_afilia     = lo_estado_afiliacion,    
      @w_truepass_dn       = lo_truepass_dn,    
      @w_edo_truepass_dn   = lo_edo_truepass_dn,    
      @w_intentos_fallidos = lo_intentos_fallidos    
    from bv_login      
    where lo_ente = @i_cliente      
      and lo_servicio = 1      
      and lo_login = @i_login      
        
       
    /*Eliminar el login */      
    delete bv_login      
    where lo_ente = @i_cliente      
      and lo_servicio = 1      
      and lo_login = @i_login      
         
    if @@error != 0     
    begin      
      /* Error en la eliminacion del login */      
        
      return 1850068         
    end      
    /* Insertar en la transaccion de servicio*/      
    insert into ts_login(      
      secuencial,    
      cod_alterno,    
      tipo_transaccion,     
      clase,      
      fecha,      
      usuario,      
      terminal,      
      oficina,      
      tabla,      
      lsrv,      
      srv,      
      ente,      
      servicio,      
      login,      
      clave_temp,      
      clave_def,      
      fecha_reg,      
      fecha_mod,      
      tipo_vigencia,      
      dias_vigencia,      
      parametro,      
      renovable,      
      hora,      
      descripcion,      
      autorizado,    --BBO 17-02-2000      
      tipo_autorizacion,    
      tarj_maestro,    
      estado,    
      truepass_dn,    
      edo_truepass_dn,    
      intentos_fallidos    
      )      
      values (      
     @s_ssn,@s_ssn,18548,'D',@s_date, @s_user, @s_term,@s_ofi, 'bv_login', @s_lsrv, @s_srv,      
     @w_cliente, @w_servicio, @w_login, @w_clave_temp, @w_clave_def, @w_fecha_reg ,@s_date,@w_tipo_vigencia,@w_dias_vigencia,@w_parametro,@w_renovable, convert(varchar(8),getdate(),108), @w_descripcion,      
     @w_autorizado, @w_tipo_autorizacion, @w_tarj_maestro,    
     @w_estado_afilia,@w_truepass_dn, @w_edo_truepass_dn,@w_intentos_fallidos)    
         
      if @@error != 0      
      begin      
      /*Error en la insercion en la tabla de servicio*/    
       
      return 1850034     
      end   
     
      delete bv_login_tercero    
      where    
      lt_servicio = 1    
      and lt_login = @i_login    
        
    if @@error != 0    
    begin    
      /* Error en la eliminacion de terceros del login */    
       
      return 1850068  
    end    
        
    --Eliminar colectores del login    
    delete bv_login_colector_item    
     where    
     lc_servicio = 1    
     and lc_login = @i_login    
        
    if @@error != 0    
    begin    
      /* Error en la eliminacion de colectores del login */    
        
      return 1850068   
    end    
      fetch curLogin into  @w_ja_ntv,@w_cedula   
  end  
  close curLogin   
  deallocate curLogin   
   
 end  
  
return 0
GO

