CREATE Procedure  jusp_op_solicitudes  (    
  @s_user        varchar(30) = null,    
  @i_operacion   char(1),    
  @i_num_soli    int = 0,    
  @i_rif_cliente varchar(20) = null,    
  @i_estado      varchar(1) = 'P',    
  @i_gerente     int = 0,    
  @i_fecha_desde datetime = null,    
  @i_fecha_hasta datetime = null,    
  @i_comentario varchar(255) = " ",    
  @i_cedula varchar(20) = " "    
)    
As    
Declare    
  @w_sp_name     varchar(30),    
  @w_sqlsol      varchar(1000),    
  @w_sqlaut      varchar(500),    
  @w_sql         varchar(500),    
  @w_ente        int,    
  @w_num_soli    int    
    
-- Captura nombre de Stored Procedure    
select @w_sp_name = 'jusp_op_solicitudes'    
    
if @i_operacion = 'S'    
begin    
      
  if @i_num_soli = 0    
  begin    
    select @w_ente = en_ente    
    from cob_bvirtual..bv_ente    
    where en_ced_ruc = @i_rif_cliente    
  end    
  else    
  begin    
    select @w_ente = en_ente    
    from cob_bvirtual..bv_ente    
    where en_ente_mis = ( select js_ente_emp    
                          from webuser_jur..ju_solicitud    
                          where js_num_solicitud = @i_num_soli )    
  end    
      
  select @w_ente = isnull(@w_ente, 0)    
      
      
  select @w_sqlsol = 'select a.js_num_solicitud, a.js_fecha_creacion, b.jc_nombre_emp, b.jc_denom_comer_emp, b.jc_act_comer_emp, b.jc_rif_emp, b.jc_ente_emp, b.jc_ente_mis_emp '    
      
  select @w_sqlsol = @w_sqlsol + ', ' + convert(varchar, @w_ente) + ' as ente_bv '    
      
  select @w_sqlsol = @w_sqlsol + 'from webuser_jur..ju_solicitud a, webuser_jur..ju_cliente b where '    
      
  if @i_num_soli = 0    
  begin    
        
    select @w_ente = jc_ente_mis_emp    
      from webuser_jur..ju_cliente    
     where jc_rif_emp = @i_rif_cliente    
         
    if @@rowcount <= 0    
    begin    
      exec cobis..sp_cerror    
           @t_from = @w_sp_name,    
           @i_num = 1888252    
      return 1888252    
    end --@@rowcount <= 0    
        
    select @w_sqlsol = @w_sqlsol + 'a.js_ente_emp = ' + CONVERT(varchar(10), @w_ente)    
        
    select @w_num_soli = js_num_solicitud     
      from webuser_jur..ju_solicitud    
     where js_estado = 'P'    
       and js_ente_emp = @w_ente    
           
    if @@rowcount <= 0    
    begin    
      exec cobis..sp_cerror    
           @t_from = @w_sp_name,    
           @i_num = 1888252    
      return 1888252    
    end --@@rowcount <= 0    
        
  end    
  else    
  begin    
    select @w_sqlsol = @w_sqlsol + ' a.js_num_solicitud = ' + CONVERT(varchar(10), @i_num_soli)    
        
    select @w_num_soli = @i_num_soli    
  end    
      
  select @w_sqlsol = @w_sqlsol + ' and a.js_ente_emp = b.jc_ente_mis_emp '    
      
  if @i_gerente = 0    
  begin    
    select @w_sqlsol = @w_sqlsol + 'and js_estado = ' + char(39) + @i_estado + char(39)    
  end    
  else    
  begin    
    select @w_sqlsol = @w_sqlsol + 'and js_estado in (' + char(39) + 'R' + char(39) + ',' + char(39) + 'P' + char(39) + ')'    
  end    
      
  select @w_sqlaut = 'select a.ja_cedula, a.ja_p_nombre, a.ja_p_apellido, a.ja_email, b.pe_nombre, a.ja_perfil,  a.ja_cambio_perfil  from webuser_jur..ju_autorizados a, cob_bvirtual..bv_perfil b '    
  select @w_sqlaut = @w_sqlaut + 'where a.ja_num_solicitud = ' + CONVERT(varchar(10), @w_num_soli)    
  select @w_sqlaut = @w_sqlaut + ' and a.ja_perfil = b.pe_perfil'    
      
  exec(@w_sqlsol)    
      
  if @@rowcount <= 0    
  begin    
    exec cobis..sp_cerror    
         @t_from = @w_sp_name,    
         @i_num = 1888252    
    return 1888252    
  end --@@rowcount <= 0    
      
  exec(@w_sqlaut)    
      
  if @@rowcount <= 0    
  begin    
    exec cobis..sp_cerror    
         @t_from = @w_sp_name,    
         @i_num = 1888252    
    return 1888252    
  end --@@rowcount <= 0    
      
end -- fin @i_operacion = 'S'    
    
if @i_operacion = 'C'    
begin    
      
  select @w_sqlsol = 'select b.jc_ente_emp, b.jc_rif_emp, a.js_num_solicitud, a.js_fecha_creacion, b.jc_nombre_emp, '   
  select @w_sqlsol = @w_sqlsol + 'case a.js_estado when ' + char(39) + 'C' + char(39) + ' then ' + char(39) + 'RECHAZADA' + char(39) + ' when ' + char(39) + 'A' + char(39) + ' then ' + char(39) + 'APROBADA' + char(39) + ' when ' + char(39) + 'R' + char(3
9  
) + 'then ' + char(39) + 'REVIZADA' + char(39) +  'end as estado,'    
  select @w_sqlsol = @w_sqlsol + 'case a.js_estado when ' + char(39) + 'C' + char(39) + ' then a.js_usu_recha when ' + char(39) + 'A' + char(39) + ' then a.js_usu_aprob when ' + char(39) + 'R' + char(39) + 'then a.js_usu_rev end as usuario,'    
  select @w_sqlsol = @w_sqlsol + 'case a.js_estado when ' + char(39) + 'C' + char(39) + ' then a.js_fecha_recha when ' + char(39) + 'A' + char(39) + ' then a.js_fecha_aprob when ' + char(39) + 'R' + char(39) + 'then a.js_fecha_rev end as fecha '    
  select @w_sqlsol = @w_sqlsol + 'from webuser_jur..ju_solicitud a, webuser_jur..ju_cliente b where '    
  select @w_sqlsol = @w_sqlsol + 'a.js_ente_emp = b.jc_ente_mis_emp '    
  select @w_sqlsol = @w_sqlsol + 'and a.js_estado in (' + char(39) + 'C' + char(39) + ',' + char(39) + 'R' + char(39) + ',' + char(39) + 'A' + char(39) + ') '    
      
  if isnull(@s_user,'0') != '0'    
  begin    
    select @w_sqlsol = @w_sqlsol + ' and (a.js_usu_aprob = ' + char(39) + @s_user + char(39) + ' or a.js_usu_rev = ' + char(39) + @s_user + char(39) + ' or a.js_usu_recha = ' + char(39) + @s_user + char(39) + ')'    
  end    
      
  if isnull(@i_fecha_desde,'01/01/2000') != '01/01/2000'    
  begin    
    select @w_sqlsol = @w_sqlsol + ' and (a.js_fecha_aprob >= ' + char(39) + convert(varchar,@i_fecha_desde,101) + char(39) + ' or a.js_fecha_rev >= ' + char(39) + convert(varchar,@i_fecha_desde,101) + char(39) + ' or a.js_fecha_recha >= ' + char(39) + co
nvert(varchar,@i_fecha_desde,101) + char(39) + ')'    
  end    
      
  if isnull(@i_fecha_hasta,'01/01/2000') != '01/01/2000'    
  begin    
    select @w_sqlsol = @w_sqlsol + ' and (a.js_fecha_aprob <= ' + char(39) + convert(varchar,@i_fecha_hasta,101) + char(39) + ' or a.js_fecha_rev <= ' + char(39) + convert(varchar,@i_fecha_hasta,101) + char(39) + ' or a.js_fecha_recha <= ' + char(39) + co
nvert(varchar,@i_fecha_hasta,101) + char(39) + ')'    
  end    
      
  exec(@w_sqlsol)    
      
  if @@rowcount <= 0    
  begin    
    exec cobis..sp_cerror    
         @t_from = @w_sp_name,    
         @i_num = 1888265    
    return 1888265    
  end --@@rowcount <= 0    
      
end -- fin @i_operacion = 'C'    
    
if @i_operacion = 'U'    
begin    
      
  if @i_num_soli <> 0 and @i_estado <> 'P'    
  begin    
    select @w_sql = 'update webuser_jur..ju_solicitud set js_estado = ' + char(39) + @i_estado + char(39)    
        
    if @i_estado = 'A'    
    begin    
      select @w_sql = @w_sql + ' , js_usu_aprob = ' + char(39) + @s_user + char(39)    
      select @w_sql = @w_sql + ' , js_fecha_aprob = ' + char(39) + CONVERT(varchar(30), getdate()) + char(39)    
    end    
    else    
    begin    
      if @i_estado = 'R'    
      begin    
        select @w_sql = @w_sql + ' , js_usu_rev = ' + char(39) + @s_user + char(39)    
        select @w_sql = @w_sql + ' , js_fecha_rev = ' + char(39) + CONVERT(varchar(30), getdate()) + char(39)    
      end    
      else    
      begin    
        if @i_estado = 'C'    
        begin    
          select @w_sql = @w_sql + ' , js_usu_recha = ' + char(39) + @s_user + char(39)    
          select @w_sql = @w_sql + ' , js_fecha_recha = ' + char(39) + CONVERT(varchar(30), getdate()) + char(39)    
          select @w_sql = @w_sql + ' , js_comen_cancel = ' + char(39) + @i_comentario + char(39)    
        end    
      end    
    end    
        
    select @w_sql = @w_sql + ' where js_num_solicitud = ' + CONVERT(varchar(10), @i_num_soli)    
        
    exec(@w_sql)    
        
    if @@error != 0    
    begin    
      exec cobis..sp_cerror    
      @t_from         = @w_sp_name,    
      @i_num          = 1888263    
      return 1888263    
    end    
    -- aqui debe cambiar el estatus de la ju_autorizado a 'E' porque la solicitud fue cancelada    
       if @i_estado = 'C'    
        begin    
   update webuser_jur..ju_autorizados    
    set ja_estado='E'    
   where ja_num_solicitud=@i_num_soli    
      if @@error != 0    
   begin    
    exec cobis..sp_cerror    
     @t_from         = @w_sp_name,    
     @i_num          = 1888263    
    return 1888263    
   end    
        end     
  end    
  else    
  begin    
    exec cobis..sp_cerror    
      @t_from         = @w_sp_name,    
      @i_num          = 1888264    
      return 1888264    
  end    
end -- fin @i_operacion = 'U'    
    
if @i_operacion = 'A'    
begin    
      
  select jr_cuenta from webuser_jur..ju_rel_aut_cuenta where jr_cedula = @i_cedula and jr_rif_emp = @i_rif_cliente     
      
  if @@rowcount <= 0    
  begin    
    exec cobis..sp_cerror    
         @t_from = @w_sp_name,    
         @i_num = 1888252    
    return 1888252    
  end --@@rowcount <= 0    
      
end -- fin @i_operacion = 'A'    
    
return 0     