/************************************************************************/
/*  ARCHIVO:         atm_emision_1cime.sp		                      	*/
/*  NOMBRE LOGICO:   atm_emision_1cime      	                 		*/
/*  PRODUCTO:        ATM                                        		*/
/************************************************************************/
/*                     PROPOSITO                                      	*/
/*	Migraci�n ATM Server  												*/
/*                                                 						*/
/************************************************************************/
/*                     MODIFICACIONES                                 	*/
/*    FECHA         AUTOR               RAZON                         	*/
/*  22-Oct-2021   Adolfo Hern�ndez  Emision inicial (Migraci�n ATMSRV) 	*/
/************************************************************************/

USE cob_atm
go

alter proc atm_emision_1cime (
        @s_ssn			int 		= null,
        @s_user			login 		= null,
        @s_term			varchar(30) 	= null,
        @s_date			datetime 	= null,
        @s_srv			varchar(30) 	= null,
        @s_lsrv			varchar(30) 	= null,
        @s_ofi			smallint 	= null,
        @t_from			varchar(32) 	= null,
        @t_trn          	int 		= null,
        @i_operacion		char(2),
        @i_banco        	tinyint 	= 1,
        @i_tarjeta      	int     	= null,
        @i_producto     	tinyint 	= null,
	@i_moneda		tinyint		= null,
        @i_cuenta       	cuenta 		= null,
        @i_tipo         	char(1) 	= null,
        @i_cupo_online  	money 		= null,
        @i_cupo_offline 	money 		= null,
        @i_periodo      	char(1) 	= null,
        @i_notificacion     char(1)     = 'N',
	@i_cupo_transferencia	money 		= null,
	@i_principal		char(1) 	= null,
	@i_modo			tinyint		= null,
	@i_orden		smallint	= null,
	@i_prod_cobis		tinyint		= null,
	@i_prod_bancario	tinyint		= null
)
as
declare @w_sp_name		varchar(32),
        @w_return       	int,
        @w_tipo         	char(1),
        @w_hoy           	datetime,
        @w_cupo_online  	money,
        @w_cupo_offline 	money,
        @w_periodo      	char(1),
	@w_cupo_transferencia	money,
	@w_principal		char(1),
        @v_tipo         	char(1),
        @v_fecha        	datetime,
        @v_cupo_online  	money,
        @v_cupo_offline 	money,
        @v_periodo      	char(1),
	@v_cupo_transferencia	money,
	@v_principal		char(1),
	@w_paso			smallint,-- FES Sep 2001
	@w_ta_codigo            cuenta,	 -- PBO 05/07/2003
	@w_ente                 int,	 -- PBO 05/07/2003
	@w_ente_mis             int,     -- PBO 05/07/2003
	@w_alias                varchar(32),     -- PBO 05/07/2003
	@w_tipo_tarjeta         char(3),  -- PBO 05/07/2003
	@w_canal_ATM            tinyint,  -- PBO 05/07/2003
	@w_prod_atm             tinyint,  -- PBO 05/07/2003
	@w_prod_banc            smallint, -- PBO 05/07/2003
	@w_orden                tinyint,  -- PBO 05/07/2003
	@w_ofi_org              smallint, --ATA  11/12/2002
        @w_mig                  char(1),  --ATA  11/12/2003             
        @w_estado_tarj          char(1)   --ata 05/04/2004 

select @w_sp_name = 'atm_emision_1cime',
       @w_hoy = convert (char(10), @s_date,1),
       @i_notificacion = isnull( @i_notificacion, 'N')


-- PBO 05/07/2003 Numero de la tarjeta
select @w_ta_codigo    = ta_codigo,
       @w_ente_mis     = ta_cliente,
       @w_tipo_tarjeta = ta_tipo_tarjeta,
       @w_ofi_org      = ta_ofi_org,
       @w_estado_tarj  = ta_estado_tarjeta
  from cob_atm..tm_tarjeta
 where ta_banco     = @i_banco
   and ta_tarjeta   = @i_tarjeta

--Valido informaci+Ýn de tarjeta migrada
select @w_mig     = om_estado_mig
  from cob_atm..tm_oficina_migrada
 where om_oficina = @w_ofi_org

if @w_mig = 'N'
begin
   exec cobis..cob_cerror_1ci
        @t_from	= @w_sp_name,
        @i_msg  = 'TARJETA NO HA SIDO MIGRADA, UTILICE EL ATMADMIN PARA VISUALIZAR LAS CUENTAS ASOCIADAS',
        @i_num	= 169999
   return 169999
end


-- PBO 05/07/2003  Codigo de ente en BV
select @w_ente     = en_ente,
       @w_alias    = substring(en_nombre, 0, 31)
  from cob_bvirtual..bv_ente
 where en_ente_mis = @w_ente_mis

/*****************************[ Insert  ]*************************************/

if @i_operacion = 'I'
begin
   if @t_trn != 16143
   begin
      exec cobis..cob_cerror_1ci
	   @t_from		= @w_sp_name,
	   @i_num		= 161500
      return 1
   end

   -- FES Sep 2001
   if exists (select *
                from cob_atm..tm_tarjeta
               where ta_banco   = @i_banco
                 and ta_tarjeta = @i_tarjeta
                 and ta_estado_tarjeta in ('A','D','E','G')) 
      select @w_paso = 1
   else
      select @w_paso = 0

   if @w_paso = 0
   begin
      exec cobis..cob_cerror_1ci
           @t_from       = @w_sp_name,
           @i_num        = 161101
           return 1
      end

   /** verifico que exista  en catalogo tipo emision **/
   -- VTO 03Sep2002 Verificar el catalogo
   if exists (select *
                from cobis..cl_catalogo
               where tabla = (select codigo
                                from cobis..cl_tabla
                               where tabla = 'tm_tipo_emision')
                                 and codigo = @i_tipo
                                 and estado = 'V')
   select @w_return = 0
   else
      select @w_return = 1

   if @w_return != 0
   begin
      exec cobis..cob_cerror_1ci
           @t_from       = @w_sp_name,
           @i_num        = 161111
      return 1
   end

   /** verifico que exista  en catalogo periodo **/
   if @i_periodo is not null
      begin
         -- VTO 03Sep2002 Verificar el catalogo
         if exists (select  *
           from    cobis..cl_catalogo
           where   tabla = (select  codigo
                    from    cobis..cl_tabla
                    where   tabla = 'tm_periodo')
           and     codigo = @i_periodo
           and  estado = 'V')
            select @w_return = 0
         else
            select @w_return = 1

         if @w_return != 0
         begin
             exec cobis..cob_cerror_1ci
                  @t_from       = @w_sp_name,
                  @i_num        = 161121
             return 1
           end
      end

      /** verifico que principal sea S o N **/
      if @i_principal not in ('S','N') /************* Revisar ***************/
      begin
	  exec cobis..cob_cerror_1ci
	       @t_from		= @w_sp_name,
	       @i_num		= 161143
	  return 1
      end
      /* tomamos datos de bv_ente_servicio_producto PBO  05/07/2003 */
      if exists (select *
		   from cob_bvirtual..bv_ente_servicio_producto
		  where ep_login	   = @w_ta_codigo
		    and ep_prod_atm = @i_producto
		    and ep_moneda   = @i_moneda
		    and ep_cuenta   = @i_cuenta )
       begin
         exec cobis..cob_cerror_1ci
              @t_from       = @w_sp_name,
              @i_num        = 161142
         return 1
       end

      /** verifico que no exista cta asignada como principal **/
      /* tomamos datos de bv_ente_servicio_producto PBO  05/07/2003 */
      if @i_principal = 'S' and
	exists (select *
		  from cob_bvirtual..bv_ente_servicio_producto
		 where ep_login	       = @w_ta_codigo
		   and ep_prod_atm     = @i_producto
		   and ep_moneda       = @i_moneda
		   and ep_cuenta_cobro = 'P')  
       begin
         exec cobis..cob_cerror_1ci
              @t_from       = @w_sp_name,
              @i_num        = 161143
         return 1
       end

begin tran
     /* Insertar nueva emision */
/**** inicio insercion de cuentas para los canales de ATM en bv_ente_servicio_producto  PBO 05/07/2003 */ 

declare cur_canalesATM cursor for 
-- se actualizan los canales de ATM y los correspondientes al tipo de tarjeta
 select distinct(se_servicio)
   from cob_bvirtual..bv_servicio, cob_atm..tm_canal_tarjeta
   where se_tipo         = 'ATM'
     and ct_tipo_tarjeta = @w_tipo_tarjeta
     and ct_canal        = se_servicio
    for read only
 
open cur_canalesATM 
fetch cur_canalesATM into @w_canal_ATM
 
if @@fetch_status <> 0 
begin 
  close cur_canalesATM 
  deallocate cur_canalesATM 
  return 1 
end 
 
while @@fetch_status = 0 
begin 
              exec @w_return = cob_bvirtual..bv_asocia_prod_0cim
                  @s_ssn            = @s_ssn,
                  @s_user           = @s_user,
                  @s_term           = @s_term,
                  @s_date           = @s_date,
                  @s_srv            = @s_srv,
                  @s_lsrv           = @s_lsrv,
                  @s_ofi            = @s_ofi,
                  @t_trn            = @t_trn,
                  @i_operacion      = 'I',                                  
		  @i_cliente        = @w_ente,            
		  @i_producto       = @i_prod_cobis,                                   
		  @i_cuenta         = @i_cuenta,                               
		  @i_alias          = @w_alias,                        
		  @i_moneda         = @i_moneda,                                  
		  @i_servicio       = @w_canal_ATM,
		  @i_estado         = 'V',                        
		  @i_login          = @w_ta_codigo,                               
		  @i_cuenta_cobro   = @i_principal,
		  @i_notificacion   = 'N' ,                        
		  @i_autorizado     = 'S',
		  @i_prod_atm	    = @i_producto,
		  @i_prod_banc	    = @i_prod_bancario,
		  @i_orden	    = @i_orden

	     if @w_return != 0
		begin
		  close cur_canalesATM 
		  deallocate cur_canalesATM 
		  exec cobis..cob_cerror_1ci
			@t_from		= @w_sp_name,
			@i_num		= 163141
		  return 1
		end
 
  fetch cur_canalesATM into @w_canal_ATM
 
end 
 
close cur_canalesATM 
deallocate cur_canalesATM 

commit tran
return 0
end

/******************************[ Update ]************************************/

if @i_operacion = 'U'
begin
     if @t_trn != 16145
     begin
	exec cobis..cob_cerror_1ci
	     @t_from		= @w_sp_name,
	     @i_num		= 161500
	return 1
     end

     /** verifico que exista  en catalogo tipo emision **/
     -- VTO 03Sep2002 Verificar el catalogo
     if exists (select  *
                  from    cobis..cl_catalogo
                 where   tabla = (select  codigo
                                    from    cobis..cl_tabla
                                   where   tabla = 'tm_tipo_emision')
                   and     codigo = @i_tipo
                   and  estado = 'V')
        select @w_return = 0
     else
        select @w_return = 1

     if @w_return != 0
     begin
           exec cobis..cob_cerror_1ci
                @t_from       = @w_sp_name,
                @i_num        = 161111
          return 1
     end

     /** verifico que exista  en catalogo periodo **/
     if @i_periodo is not null
     begin
         -- VTO 03Sep2002 Verificar el catalogo
         if exists (select  *
           from    cobis..cl_catalogo
           where   tabla = (select  codigo
                    from    cobis..cl_tabla
                    where   tabla = 'tm_periodo')
           and     codigo = @i_periodo
           and  estado = 'V')
            select @w_return = 0
         else
            select @w_return = 1

        if @w_return != 0
           begin
             exec cobis..cob_cerror_1ci
                  @t_from       = @w_sp_name,
                  @i_num        = 161121
             return 1
           end
      end

      /** verifico que principal sea S o N **/
      if  @i_principal not in ('S','N')
	  begin
	     exec cobis..cob_cerror_1ci
	          @t_from		= @w_sp_name,
	          @i_num		= 161143
	     return 1
	  end

     /* Seleccionar los nuevos datos */
     /* se utiliza bv_ente_servicio_producto  */
     select @w_hoy                = ep_fecha_mod,
            @w_principal	  = ep_cuenta_cobro,
            @w_prod_atm 	  = ep_prod_atm,
            @w_prod_banc	  = ep_prod_banc,
            @w_orden	          = ep_orden
     from cob_bvirtual..bv_ente_servicio_producto
     where ep_login  = @w_ta_codigo
       and ep_prod_atm = @i_producto 
       and ep_cuenta   = @i_cuenta
       and ep_moneda   = @i_moneda

     if @@rowcount = 0
        begin
          exec cobis..cob_cerror_1ci
          @t_from		= @w_sp_name,
          @i_num		= 161141
          return 1
        end

     select -- PBO 05/07/2003 @v_tipo               = @w_tipo,
         @v_fecha              = @w_hoy,
	 @v_principal	       = @w_principal

     if @w_principal = @i_principal
        select @w_principal = null, @v_principal = null
     else
        select @w_principal = @i_principal

     BEGIN TRAN
     if @i_principal = 'S'
     begin
        /**** inicio actualizacion de cuentas para los canales de ATM en bv_ente_servicio_producto PBO 04/07/2003 */ 
        -- se actualizan los canales de ATM y los correspondientes al tipo de tarjeta
        declare cur_canalesATM cursor for 
         select distinct(se_servicio)
           from cob_bvirtual..bv_servicio, cob_atm..tm_canal_tarjeta
          where se_tipo         = 'ATM'
            and ct_tipo_tarjeta = @w_tipo_tarjeta
            and ct_canal        = se_servicio
            for read only
 
        open cur_canalesATM 
        fetch cur_canalesATM into @w_canal_ATM
 
        if @@fetch_status <> 0 
        begin 
           close cur_canalesATM 
           deallocate cur_canalesATM 
           return 1 
        end 
 
        while @@fetch_status = 0 
        begin 
           exec @w_return = cob_bvirtual..bv_asocia_prod_0cim
                @s_ssn            = @s_ssn,
                @s_user           = @s_user,
                @s_term           = @s_term,
                @s_date           = @s_date,
                @s_srv            = @s_srv,
                @s_lsrv           = @s_lsrv,
                @s_ofi            = @s_ofi,
                @t_trn            = @t_trn,
		@i_operacion      = 'U',                                  
		@i_cliente        = @w_ente,                                       
		@i_producto       = @i_producto,                                   
		@i_cuenta         = @i_cuenta,                               
		@i_alias          = @w_alias,                        
		@i_moneda         = @i_moneda,                                  
		@i_servicio       = @w_canal_ATM,
		@i_estado         = 'V',                        
		@i_login          = @w_ta_codigo,                               
		@i_cuenta_cobro   = 'N',
		@i_notificacion   = 'N' ,                        
		@i_autorizado     = 'S',
		@i_prod_atm	  = @w_prod_atm,
		@i_prod_banc	  = @w_prod_banc,
		@i_orden	  = @w_orden

           if @w_return != 0
	   begin
	      close cur_canalesATM 
	      deallocate cur_canalesATM 
	      exec cobis..cob_cerror_1ci
		   @t_from		= @w_sp_name,
		   @i_num		= 165141
	      return 165141
	   end
 
           fetch cur_canalesATM into @w_canal_ATM
 
        end  --fetch
        close cur_canalesATM 
        deallocate cur_canalesATM 
     end  --i_principal
  COMMIT TRAN
  return 0
end

/*********************************[ Delete ]********************************/

if @i_operacion = 'D'
begin
   if @t_trn != 16147
   begin
      exec cobis..cob_cerror_1ci
  	   @t_from = @w_sp_name,
	   @i_num  = 161500
      return 1
   end

   BEGIN TRAN
      /**** inicio eliminacion de cuentas para los canales de ATM en bv_ente_servicio_producto  PBO 04/07/2003 */ 
      -- se actualizan los canales de ATM y los correspondientes al tipo de tarjeta
      declare cur_canalesATM cursor for 
       select distinct(se_servicio)
         from cob_bvirtual..bv_servicio, cob_atm..tm_canal_tarjeta
        where se_tipo         = 'ATM'
          and ct_tipo_tarjeta = @w_tipo_tarjeta
          and ct_canal        = se_servicio
          for read only
 
      open cur_canalesATM 
      fetch cur_canalesATM into @w_canal_ATM
 
      if @@fetch_status <> 0 
      begin 
         close cur_canalesATM 
         deallocate cur_canalesATM 
         return 1 
      end 
 
      while @@fetch_status = 0 
      begin 
         exec @w_return = cob_bvirtual..bv_asocia_prod_0cim
              @s_ssn            = @s_ssn,
              @s_user           = @s_user,
              @s_term           = @s_term,
              @s_date           = @s_date,
              @s_srv            = @s_srv,
              @s_lsrv           = @s_lsrv,
              @s_ofi            = @s_ofi,
              @t_trn            = @t_trn,
	      @i_operacion      = 'D',                                  
	      @i_cliente        = @w_ente,                                       
	      @i_producto       = @i_producto,          
	      @i_cuenta         = @i_cuenta,                               
	      @i_alias          = @w_alias,                        
	      @i_moneda         = @i_moneda,                                  
	      @i_servicio       = @w_canal_ATM,
	      @i_estado         = 'V',                        
	      @i_login          = @w_ta_codigo,                               
	      @i_cuenta_cobro   = @w_principal,
	      @i_notificacion   = @i_notificacion ,                        
	      @i_autorizado     = 'S',
	      @i_prod_atm	= @w_prod_atm,
	      @i_prod_banc	= @w_prod_banc,
	      @i_orden	        = @w_orden

         if @w_return != 0
         begin
            close cur_canalesATM 
	    deallocate cur_canalesATM 
	    exec cobis..cob_cerror_1ci
 		 @t_from	= @w_sp_name,
		 @i_num		= 167141
	    return 1
         end
         fetch cur_canalesATM into @w_canal_ATM
       end  --while
 
       close cur_canalesATM 
       deallocate cur_canalesATM 
  COMMIT TRAN
  return 0
end  --operacion D

/* Search  para solicitud de Actualizacion */
/* Se lo realiza solo para modo = 0, solo puede tener 20 cuentas */
/* FCUENSOA							 */
if @i_operacion = 'N'
begin
   if @t_trn != 16142
   begin
      /* Acceso no permitido */
      exec cobis..cob_cerror_1ci
 	   @t_from		= @w_sp_name,
	   @i_num		= 161500
      return 1
   end
   if @i_modo = 0
   begin
      set rowcount 20
      /* usamos bv_ente_servicio_producto PBO 05/07/2003 */
	select  'PRODUCTO'		= valor,
		'CUENTA'		= ep_cuenta,
		'MONEDA'		= ep_moneda,
		'PRINCIPAL'		= ep_cuenta_cobro,
		'LIM ATM'		= (select lx_monto from cob_atm..tm_limite_extraccion
						where lx_codigo = ta_cupo_online),
		'LIM POS'		= (select lx_monto from cob_atm..tm_limite_extraccion
						where lx_codigo = ta_cupo_offline),
		'LIM TRANSFER'		= (select lx_monto from cob_atm..tm_limite_extraccion
						where lx_codigo = ta_cupo_transf),
		'IDPR'			= ep_prod_atm,
		'IDPE'			= ta_cupo_periodo,
		'ACC'			= 'X',
		'ORD'			= ep_orden,
		'TARJ'			= ta_tarjeta,
		'P.COB.'		= ep_producto,
		'P.BAN.'		= ep_prod_banc,
		'NUEVA'			= 'N'
      from cob_bvirtual..bv_ente_servicio_producto,
	   cobis..cl_catalogo,
	   cob_bvirtual..bv_servicio,
           cob_atm..tm_tarjeta
      where ep_login	 = @w_ta_codigo
	and ep_prod_atm	 = convert(tinyint, codigo)
        and se_servicio = ep_servicio
        and se_tipo = 'ATM'
	and tabla = (select codigo from cobis..cl_tabla where tabla = 'tm_producto_atm')
        and ta_banco = @i_banco
        and ta_codigo = @w_ta_codigo
        group by valor, ep_cuenta, ep_moneda, ep_cuenta_cobro, ta_cupo_online, ta_cupo_transf, ta_cupo_offline, ep_prod_atm, ta_cupo_periodo, ep_orden, ta_tarjeta, ep_producto, ep_prod_banc
	order by ep_orden
   end
   else
   begin
      set rowcount 20
      /* usamos bv_ente_servicio_producto PBO 05/07/2003 */
       select  'PRODUCTO'		= substring(valor,1,20),
		'CUENTA'		= ep_cuenta,
		'MONEDA'		= ep_moneda,
		'PRINCIPAL'		= ep_cuenta_cobro,
		'IDPR'			= ep_prod_atm,
		'ACC'			= 'X',
		'ORD'			= ep_orden,
		'TARJ'			= ep_login,
		'P.COB.'		= ep_producto,
		'P.BAN.'		= ep_prod_banc,
		'NUEVA'			= 'N'
      from cob_bvirtual..bv_ente_servicio_producto,
	   cobis..cl_catalogo,
	   cobis..cl_producto
      where ep_login	 = @w_ta_codigo
	and ep_prod_atm	 = pd_producto
	and ep_orden	 > 0 		--em_cuenta    > '0'
	and tabla	 = (select cobis..cl_tabla.codigo
			    from cobis..cl_tabla
			    where cobis..cl_tabla.tabla = 'tm_periodo')
	order by ep_orden
   end
   return 0
end   --Operacion N

/* Search */
/* Se lo realiza solo para modo = 0, solo puede tener 20 cuentas */
/* CTARCLI, DCONSOLI, FCONSTAR					 */
if @i_operacion = 'S'
begin
   if @t_trn != 16142
   begin
      /* Acceso no permitido */
      exec cobis..cob_cerror_1ci
	   @t_from		= @w_sp_name,
	   @i_num		= 161500
      return 1
   end

   /* Se crea la tabla temporal		*/
   create table #cuentas (
   cuenta    varchar(24)	null,
   principal  char(1)		null,
   cta_estado char(1)		null,
   cod_prod   tinyint		null)

   insert into #cuentas	(cuenta, principal, cta_estado,	cod_prod)
   select distinct (ep_cuenta), ep_cuenta_cobro, cc_estado, ep_prod_atm
     from cob_bvirtual..bv_ente_servicio_producto with(index=bv_ente_servicio_producto_atm_Key)
          left outer join cob_cuentas..cc_ctacte on ep_cuenta = cc_cta_banco,
          cob_bvirtual..bv_servicio
    where ep_servicio    = se_servicio
      and ep_login	    = @w_ta_codigo
      and cc_filial	    =1 --23/01/2014 jn 
      and ep_prod_atm	    = 3		-- Ctas. Corrientes
      and se_tipo           = 'ATM'
    order by ep_cuenta

    insert into #cuentas	(cuenta, principal, cta_estado,	cod_prod)
    select distinct(ep_cuenta), ep_cuenta_cobro, ah_estado,	ep_prod_atm
     from cob_bvirtual..bv_ente_servicio_producto with(index=bv_ente_servicio_producto_atm_Key)
          left outer join cob_ahorros..ah_cuenta on ep_cuenta = ah_cta_banco,
          cob_bvirtual..bv_servicio
    where ep_servicio    = se_servicio
      and ep_login	 = @w_ta_codigo
      and ah_filial	 =1 --23/01/2014 jn 
      and ep_prod_atm	 in (4, 5)	-- Ctas. Ahorros y Fal
      and se_tipo        = 'ATM'
    order by ep_cuenta

    if not exists (select 1 from #cuentas) and @w_estado_tarj = 'B'
    begin
        insert into #cuentas	(cuenta, principal, cta_estado,	cod_prod)
          select distinct (em_cuenta), em_orden, cc_estado, em_prod_atm
            from cob_atm..tm_emision
			left outer join cob_cuentas..cc_ctacte on em_cuenta = cc_cta_banco
           where em_codigo          = @w_ta_codigo
             and em_prod_atm	    = 3		-- Ctas. Corrientes
           order by em_cuenta

          insert into #cuentas	(cuenta, principal, cta_estado,	cod_prod)
          select distinct(em_cuenta), em_orden, ah_estado,em_prod_atm
            from cob_atm..tm_emision
                 left outer join cob_ahorros..ah_cuenta on em_cuenta = ah_cta_banco
           where em_codigo      = @w_ta_codigo
	     and em_prod_atm    in (4, 5)	-- Ctas. Ahorros y Fal
	   order by em_cuenta

          set rowcount 20
	  select 'PRODUCTO'		= substring(a.valor,1,20), 
		 'CUENTA'		= cuenta,
		 'PRN'			= principal,
		 'ESTADO'		= cta_estado,
		 'IDPR'			= cod_prod
            from #cuentas
	        left outer join cobis..cl_catalogo a on cod_prod = convert(tinyint, a.codigo)
           where a.tabla 	= (select cobis..cl_tabla.codigo
	                             from cobis..cl_tabla
 			            where cobis..cl_tabla.tabla = 'tm_producto_atm')
           order by cod_prod, cuenta
    end

    set rowcount 20
    select 'PRODUCTO'		= substring(a.valor,1,20), 
	   'CUENTA'		= cuenta,
	   'PRN'		= principal,
	   'ESTADO'		= cta_estado,
	   'IDPR'		= cod_prod
      from #cuentas
	  left outer join cobis..cl_catalogo a on cod_prod = convert(tinyint, a.codigo)
     where a.tabla 	= (select cobis..cl_tabla.codigo
      from cobis..cl_tabla
     where cobis..cl_tabla.tabla = 'tm_producto_atm')
     order by cod_prod, cuenta

  end

return 0
go

IF OBJECT_ID('dbo.atm_emision_1cime') IS NOT NULL
    PRINT '<<< ALTERED PROCEDURE dbo.atm_emision_1cime >>>'
ELSE
    PRINT '<<< FAILED ALTERED dbo.atm_emision_1cime >>>'
go