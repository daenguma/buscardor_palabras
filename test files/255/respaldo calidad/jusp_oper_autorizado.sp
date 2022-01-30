USE [webuser_jur]
GO

/****** Object:  StoredProcedure [dbo].[jusp_oper_autorizado]    Script Date: 08/11/2021 8:57:18 a. m. ******/
SET ANSI_NULLS OFF
GO

SET QUOTED_IDENTIFIER OFF
GO


/************************************************************/
/*   ARCHIVO:         jusp_oper_autorizado.sp               */
/*   NOMBRE LOGICO:   jusp_oper_autorizado                  */
/************************************************************/
/*                     MODIFICACIONES                       */
/*  FECHA       AUTOR               RAZON                   */
/*  02/05/2011  Edgar Castro        Emision Inicial         */
/*                                                          */
/* 28-Feb-2012  Ivan Perez        Cambio operacion 'D'      */
/*                                envio parametro @i_gasa   */
/*                                sp_login_cliente_bv       */
/*                                                          */
/* 30-mar-2012  Ivan Perez        Cambio operacion 'C'      */
/*                                envio parametro @i_ssl    */
/*                                sp_clientes_bv            */
/* 23-abril-2012 Aurymar Romero  Cambio oper='I'            */
/* 07-abril-2014 Jose Ñañez      Cambio oper='I' elimina    */
/*                               Perfil anterior            */
/* 20-ago-2014  Daniel Betancourt GrupoEconomico            */
/* 19-09-2014   Ivan Perez		 Guardar moneda operacion I */
/************************************************************/

CREATE Procedure [dbo].[jusp_oper_autorizado](
  @s_ssn               int          = null,
  @s_user              varchar(20),
  @s_term              varchar(30),
  @s_date              datetime,
  @s_servicio          tinyint,
  @s_rol               smallint     = 1,
  @s_ofi               smallint,
  @s_srv               varchar(30)  = null,
  @s_lsrv              varchar(30)  = null,
  @i_solicitud         int = 0,
  @i_cedula            varchar(30),
  @i_operacion         char(1),
  @i_cliente           int = 0,
  @i_descripcion       varchar(64)  = " ",
  @i_login             varchar(20) = " ",
  @i_email             varchar (255)   = " ",
  @i_celular           varchar (11)   = " ",
  @i_perfil            smallint = 0,
  @i_tipo_vigencia     varchar(1) = 'I',
  @i_autorizado        char(1) = 'S',
  @i_modo_dblaut       int = 0,
  @i_tipo_autorizacion varchar (10) = 'A',
  @i_alias             varchar(32) = " ",
  @i_ente_mis          int = 0,
  @i_rif_emp           varchar(20) = null,
  @o_ente_bv           int = 0 out
)
As
declare
  @w_sp_name     varchar(64),
  @w_return      int,
  @w_tipo_cuenta int,
  @w_cuenta varchar(20),
  @w_menvio int,
  @w_perfil_um int,
  @w_perfil_ge int,
  @w_ntv   varchar(20),
  @w_orden int,
  @w_moneda_cuenta int

select  @w_sp_name  = 'jusp_oper_autorizado'

if @i_operacion = 'I'  
begin  
	--verificar 
		--si el autorizado viene por cambio de perfil  
	select @w_perfil_um = pa_int from cobis..cl_parametro where pa_nemonico = 'PAUM'  
	select @w_perfil_ge = pa_int from cobis..cl_parametro where pa_nemonico = 'PAGE'  
	set @w_ntv = ''  
  	
	--verificar si el autorizado existe con otro perfil diferente a usuario maestro  
	select @w_ntv = ja_ntv 
	from webuser_jur..ju_autorizados  
	where ja_cedula = @i_cedula  
		and ja_num_solicitud = @i_solicitud  
		and ja_cambio_perfil = 'S'  
  
	
	if (@w_ntv <> '') and (@w_ntv is not null)  
	begin  
		--solo debe hacer cambio de perfil
		begin tran     
			--SE ELIMINA LA SOLICITUD ANTERIOR
			update webuser_jur..ju_autorizados  
			set ja_estado = 'E'  
			where ja_ntv = @w_ntv   
				and ja_ente = @i_cliente  
				and (ja_perfil <> @i_perfil)  
  
			--SE ELIMINA REGISTROS ANTERIORES
			delete 
			from webuser_jur..ju_autorizados   
			where ja_ente = @i_cliente  
				and ja_cedula = @i_cedula  
        
			--SE ACTUALIZA EL PERFIL DEL AUTORIZADO
			update cob_bvirtual..bv_ente_servicio_perfil  
			set es_perfil = @w_perfil_um  
			where es_login = @w_ntv  
   
			--pasa a vigente  una vez aprobada la solicitud
			update webuser_jur..ju_autorizados       
			set ja_estado = 'V',  
				ja_ente   = @i_cliente,  
				ja_perfil = @w_perfil_um,  
				ja_imp_carta = 'S'          
			where ja_cedula = @i_cedula  
				and ja_num_solicitud = @i_solicitud  
  
		commit tran  
		
		return 0  
		
	end--if (@w_ntv <> '') and (@w_ntv is not null)    
  
	exec @w_return = cob_bvirtual..sp_login_cliente_bv  
	  @s_ssn               = @s_ssn,  
	  @s_user              = @s_user,  
	  @s_term              = @s_term,  
	  @s_date              = @s_date,  
	  @s_ofi               = @s_ofi,  
	  @t_trn               = 18548,  
	  @i_cliente           = @i_cliente,  
	  @i_servicio          = @s_servicio,  
	  @i_descripcion       = @i_descripcion,  
	  @i_tipo_vigencia     = @i_tipo_vigencia,  
	  @i_login             = @i_login,  
	  @i_operacion         = @i_operacion,  
	  @i_tipo_cliente      = 'C',  
	  @i_autorizado        = @i_autorizado,  
	  @i_modo_dblaut       = @i_modo_dblaut,  
	  @i_tipo_autorizacion = @i_tipo_autorizacion  
  
	if @w_return <> 0  
	begin  
	  exec cobis..sp_cerror  
		@t_from = @w_sp_name,  
		@i_num  = 1888254  
	  return 1888254  
	end  
  
	select @w_orden = 0  
  
	if @i_perfil = @w_perfil_ge  
		select @w_orden = 1   
	
	--declarar cursor de cuentas
	declare curCuentasI cursor for  
		select 
			jr_tipo_cuenta,  
			jr_cuenta,
			jr_moneda_cuenta  
		from webuser_jur..ju_rel_aut_cuenta  
		where 
			jr_cedula = @i_cedula  
			and jr_rif_emp = @i_rif_emp  
    
	open curCuentasI  
  
	--primer registro del cursor
	fetch curCuentasI into  
	  @w_tipo_cuenta,  
	  @w_cuenta, 
	  @w_moneda_cuenta
  
  
	if @@fetch_status <> 0  
	begin  
		close curCuentasI  
		deallocate curCuentasI  
		return 1  
	end  
  
	--recorrer cursor
	while @@fetch_status = 0  
	begin   
  
		exec @w_return = cob_bvirtual..sp_asocia_producto_bv  
		   @s_ssn                = @s_ssn,  
		   @s_user               = @s_user,  
		   @s_term               = @s_term,  
		   @s_date               = @s_date,  
		   @s_srv                = @s_srv,  
		   @s_lsrv               = @s_lsrv,  
		   @s_ofi                = @s_ofi,  
		   @t_trn                = 18522,  
		   @i_operacion          = @i_operacion,  
		   @i_cliente            = @i_cliente,  
		   @i_producto           = @w_tipo_cuenta,  
		   @i_cuenta             = @w_cuenta,  
		   @i_alias              = @i_alias,  
		   @i_moneda             = @w_moneda_cuenta,  
		   @i_servicio           = @s_servicio,  
		   @i_estado             = 'V',  
		   @i_login              = @i_login,  
		   @i_autorizado         = @i_autorizado,  
		   @i_modo_dblaut        = @i_modo_dblaut,  
		   @i_orden              = @w_orden,  
		   @i_cod_alterno        = @i_cliente  
  
		if @w_return <> 0  
		begin  
		   exec cobis..sp_cerror  
				@t_from = @w_sp_name,  
				@i_num  = @w_return  
		    
		   close curCuentasI  
		   deallocate curCuentasI  
		   return @w_return  
		end  
    
		--siguiente registro del cursor
		fetch curCuentasI into  
			@w_tipo_cuenta,  
			@w_cuenta,
			@w_moneda_cuenta  
			
	end--while @@fetch_status = 0    
  
	close curCuentasI  
	deallocate curCuentasI  
  
	--asociar items
	exec @w_return = cob_bvirtual..sp_asocia_perfil_bv  
		  @s_ssn         = @s_ssn,  
		  @s_user        = @s_user,  
		  @s_sesn        = @s_ssn,  
		  @s_term        = @s_term,  
		  @s_date        = @s_date,  
		  @s_srv         = @s_srv,  
		  @s_lsrv        = @s_lsrv,  
		  @s_ofi         = @s_ofi,  
		  @t_trn         = 18519,  
		  @i_operacion   = @i_operacion,  
		  @i_cliente     = @i_cliente,  
		  @i_perfil      = @i_perfil,  
		  @i_servicio    = @s_servicio,  
		  @i_login       = @i_login,  
		  @i_autorizado  = @i_autorizado,  
		  @i_modo_dblaut = @i_modo_dblaut  
	  
	if @w_return <> 0  
	begin  
	  exec cobis..sp_cerror  
		@t_from = @w_sp_name,  
		@i_num  = 1888254  
		
	  return 1888254  
	end  
  
	--email
	if isnull(@i_email,'') <> ''  
	begin  
		exec @w_return = cob_bvirtual..sp_ente_menvio_bv  
		   @s_ssn                = @s_ssn,  
		   @s_user               = @s_user,  
		   @s_term               = @s_term,  
		   @s_date               = @s_date,  
		   @s_srv                = @s_srv,  
		   @s_ofi                = @s_ofi,  
		   @t_trn                = 18580,  
		   @i_operacion          = @i_operacion,  
		   @i_ente               = @i_cliente,  
		   @i_servicio           = @s_servicio,  
		   @i_login              = @i_login,  
		   @i_tipo               = 'MAIL',  
		   @i_num_dir            = @i_email  
  
		if @w_return <> 0  
		begin  
		   exec cobis..sp_cerror  
			@t_from = @w_sp_name,  
			@i_num  = 1888254  
		   return 1888254  
		end  
		
	end--if isnull(@i_email,'') <> ''  
  
	--telefono
	select  @i_celular =ja_telefono   
	from webuser_jur..ju_autorizados  
	where 
		ja_cedula = @i_cedula  
		and ja_num_solicitud = @i_solicitud  
  
  
	if isnull(@i_celular,'') <> ''  
	begin  
  
		exec @w_return = cob_bvirtual..sp_ente_menvio_bv  
		   @s_ssn                = @s_ssn,  
		   @s_user               = @s_user,  
		   @s_term               = @s_term,  
		   @s_date               = @s_date,  
		   @s_srv                = @s_srv,  
		   @s_ofi                = @s_ofi,  
		   @t_trn                = 18999,  
		   @i_operacion          = @i_operacion,  
		   @i_ente               = @i_cliente,  
		   @i_servicio           = @s_servicio,  
		   @i_login              = @i_login,  
		   @i_tipo               = 'TELF',  
		   @i_num_dir            = @i_celular  
   
		if @w_return <> 0    
		begin  
		   exec cobis..sp_cerror  
				@t_from = @w_sp_name,  
				@i_num  = 1888254  
		   return 1888254  
		   
		end  
		
	end--if isnull(@i_celular,'') <> ''    
  
	--actualizar autorizado
	update webuser_jur..ju_autorizados  
    set 
		ja_estado = 'A',  
		ja_ente   = @i_cliente,  
		ja_ntv    = @i_login  
	where 
		ja_cedula = @i_cedula  
		and ja_num_solicitud = @i_solicitud  
  
  
	if @@error != 0   
	begin  
		exec cobis..sp_cerror  
		   @t_from = @w_sp_name,  
		   @i_num  = 1888254  
      
		return 1888254  
	end  
	
end --if @i_operacion = 'I' 


--Esta operación realizara el borrado de las tablas
if @i_operacion = 'D'
begin
	
	--declarar cursor de cuentas
	declare curCuentasD cursor for  
		select 
			jr_tipo_cuenta,  
			jr_cuenta,
			jr_moneda_cuenta  
		from webuser_jur..ju_rel_aut_cuenta  
		where 
			jr_cedula = @i_cedula  
			and jr_rif_emp = @i_rif_emp  
    
	open curCuentasD  
  
	--primer registro del cursor
	fetch curCuentasD into  
	  @w_tipo_cuenta,  
	  @w_cuenta, 
	  @w_moneda_cuenta
  
	if @@fetch_status <> 0
	begin
		close curCuentasD
		deallocate curCuentasD
		return 1
	end
  
	--recorrer cursor
	while @@fetch_status = 0 
	begin 

		exec @w_return = cob_bvirtual..sp_asocia_producto_bv
			 @s_ssn                = @s_ssn,
			 @s_user               = 'SYSTEM',
			 @s_term               = @s_term,
			 @s_date               = @s_date,
			 @s_srv                = @s_srv,
			 @s_lsrv               = @s_lsrv,
			 @s_ofi                = @s_ofi,
			 @t_trn                = 18522,
			 @i_operacion          = @i_operacion,
			 @i_cliente            = @i_cliente,
			 @i_producto           = @w_tipo_cuenta,
			 @i_cuenta             = @w_cuenta,
			 @i_alias              = @i_alias,
			 @i_moneda             = @w_moneda_cuenta,
			 @i_servicio           = @s_servicio,
			 @i_estado             = 'V',
			 @i_login              = @i_login,
			 @i_autorizado         = @i_autorizado,
			 @i_modo_dblaut        = @i_modo_dblaut
         
		if @w_return <> 0
		begin
			exec cobis..sp_cerror
				@t_from = @w_sp_name,
				@i_num  = 1888254
      
			close curCuentasD  
			deallocate curCuentasD
			return 1888254
		end
		
		--siguiente registro del cursor
		fetch curCuentasD into  
			@w_tipo_cuenta,  
			@w_cuenta,
			@w_moneda_cuenta  
			
	end--while @@fetch_status = 0 
	
	close curCuentasD 
	deallocate curCuentasD 
    
    --asociar items
	exec @w_return = cob_bvirtual..sp_asocia_perfil_bv
		   @s_ssn         = @s_ssn,
		   @s_user        = 'SYSTEM',
		   @s_sesn        = @s_ssn,
		   @s_term        = @s_term,
		   @s_date        = @s_date,
		   @s_srv         = @s_srv,
		   @s_lsrv        = @s_lsrv,
		   @s_ofi         = @s_ofi,
		   @t_trn         = 18519,
		   @i_operacion   = @i_operacion,
		   @i_cliente     = @i_cliente,
		   @i_perfil      = @i_perfil,
		   @i_servicio    = @s_servicio,
		   @i_login       = @i_login,
		   @i_autorizado  = @i_autorizado,
		   @i_modo_dblaut = @i_modo_dblaut
    
	if @w_return <> 0
	begin
		exec cobis..sp_cerror
		 @t_from = @w_sp_name,
		 @i_num  = 1888254

		return 1888254
	end
   
	--telefono
	select @w_menvio = me_envio 
	from cob_bvirtual..bv_medio_envio  
	where me_ente = @i_cliente
		and me_servicio = 1
		and me_login = @i_login
		and me_tipo='TELF'

	if  isnull( @w_menvio,0) <> 0
	begin
		exec @w_return = cob_bvirtual..sp_ente_menvio_bv
		   @s_ssn                = @s_ssn,
		   @s_user               = 'SYSTEM',
		   @s_term               = @s_term,
		   @s_date               = @s_date,
		   @s_srv                = @s_srv,
		   @s_ofi                = @s_ofi,
		   @t_trn                = 18999,
		   @i_operacion          = @i_operacion,
		   @i_ente               = @i_cliente,
		   @i_servicio           = @s_servicio,
		   @i_login              = @i_login,
		   @i_envio              = @w_menvio,
		   @i_tipo               = 'TELF',
		   @i_num_dir            = @i_email
  
	   if @w_return <> 0
	   begin
		  exec cobis..sp_cerror
			   @t_from = @w_sp_name,
			   @i_num  = 1888254
	      
		  return 1888254
	    end
	end--if  isnull( @w_menvio,0) <> 0
  
  
	--email
	select @w_menvio = me_envio 
	from cob_bvirtual..bv_medio_envio  
	where me_ente = @i_cliente
		and me_servicio = 1
		and me_login = @i_login
		and me_tipo='MAIL'

	if  isnull( @w_menvio,0) <> 0
	begin
		exec @w_return = cob_bvirtual..sp_ente_menvio_bv
		   @s_ssn                = @s_ssn,
		   @s_user               = 'SYSTEM',
		   @s_term               = @s_term,
		   @s_date               = @s_date,
		   @s_srv                = @s_srv,
		   @s_ofi                = @s_ofi,
		   @t_trn                = 18580,
		   @i_operacion          = @i_operacion,
		   @i_ente               = @i_cliente,
		   @i_servicio           = @s_servicio,
		   @i_login              = @i_login,
		   @i_envio              = @w_menvio,
		   @i_tipo               = 'MAIL',
		   @i_num_dir            = @i_email
	  
		if @w_return <> 0
		begin
		  exec cobis..sp_cerror
			   @t_from = @w_sp_name,
			   @i_num  = 1888254
	      
		  return 1888254
		end
	end--if  isnull( @w_menvio,0) <> 0
  
	--
	exec @w_return = cob_bvirtual..sp_login_cliente_bv
		   @s_ssn               = @s_ssn,
		   @s_user              = 'SYSTEM',
		   @s_term              = @s_term,
		   @s_date              = @s_date,
		   @s_ofi               = @s_ofi,
		   @t_trn               = 18548,
		   @i_cliente           = @i_cliente,
		   @i_servicio          = @s_servicio,
		   @i_descripcion       = @i_descripcion,
		   @i_tipo_vigencia     = @i_tipo_vigencia,
		   @i_login             = @i_login,
		   @i_operacion         = @i_operacion,
		   @i_tipo_cliente      = 'C',
		   @i_autorizado        = @i_autorizado,
		   @i_modo_dblaut       = @i_modo_dblaut,
		   @i_tipo_autorizacion = @i_tipo_autorizacion,
		   @i_gasa              = 'S'
	   
	if @w_return <> 0
	begin
		exec cobis..sp_cerror
		@t_from = @w_sp_name,
		@i_num  = 1888254
	    
		return 1888254
	end
  
	--actualizar autorizado
	update webuser_jur..ju_autorizados
	set 
		ja_estado = 'P',
		ja_ente   = 0,
		ja_ntv    = null
	where ja_cedula = @i_cedula
		and ja_num_solicitud = @i_solicitud
  
	if @@error != 0 
	begin
		exec cobis..sp_cerror
           @t_from = @w_sp_name,
           @i_num  = 1888254
      
		return 1888254
	end
  
end -- if @i_operacion = 'D'


--Esta operación realizara la creacion del cliente en BV
if @i_operacion = 'C'
begin
  exec @w_return = cob_bvirtual..sp_clientes_bv
       @s_ssn          = @s_ssn,
       @s_user         = @s_user,
       @s_sesn         = 0,
       @s_term         = @s_term,
       @s_date         = @s_date,
       @s_srv          = 'GASAB',
       @s_lsrv         = 'GASAB',
       @s_ofi          = 800,
       @t_trn          = 18501,
       @i_operacion    = 'I',
       @i_codigo_mis   = @i_ente_mis,
       @i_tipo         = 'C',
       @i_nombre       = @i_descripcion,
       @i_cedularuc    = @i_cedula,
       @i_fechanac     = @s_date,
       @i_categoria    = 'C',
       @i_sector       = 'COMERCIAL',
       @i_lenguaje     = 0,
       @i_oficina      = 800,
       @i_notificacion = 'S',
       /*@i_oficial            smallint      = null,*/
       @i_autorizado   = 'S',
       @i_origen_ente  = '     ',
       @i_segmento     = '     ',
       @i_subsegmento  = '     ',
       @i_ssl		   = 'S',
       @o_siguiente = @o_ente_bv out
       
       if @w_return = 0
       begin
         exec @w_return = cob_bvirtual..sp_asocia_servicio_bv
              @s_ssn                = @s_ssn,
              @s_user               = @s_user,
              @s_sesn               = 0,
              @s_term               = @s_term,
              @s_date               = @s_date,
              @s_srv                = 'GASAB',
              @s_lsrv               = 'GASAB',
              @s_ofi                = 800,
              @t_trn                = 18521,
              @i_operacion          = 'I',
              @i_cliente            = @o_ente_bv,
              @i_servicio           = 1
              
         if @w_return != 0
         begin
           exec cobis..sp_cerror
              @t_from  = @w_sp_name,
              @i_num   = 1888254
           return 1888254
         end
         
         update webuser_jur..ju_cliente set jc_ente_emp = @o_ente_bv where jc_ente_mis_emp = @i_ente_mis
         
       end
       else
       begin
         exec cobis..sp_cerror
              @t_from  = @w_sp_name,
              @i_num   = 1888254
         return 1888254
       end
end

return 0

GO


