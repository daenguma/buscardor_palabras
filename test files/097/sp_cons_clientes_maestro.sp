/************************************************************************/ 
/*      Stored procedure:       sp_cons_clientes_maestro                */ 
/*      Base de datos:          cob_atm_his                             */ 
/*      Producto:               ATM Server Administracion y Control     */ 
/*      Disenado por:           Y. Lopez/F.Escudero                     */ 
/************************************************************************/ 
/*				IMPORTANTE												*/ 
/*	Este programa es parte de los paquetes bancarios propiedad de		*/ 
/*	"MACOSA", representantes exclusivos para el Ecuador de la 			*/ 
/*	"NCR CORPORATION".													*/	
/*	Su uso no autorizado queda expresamente prohibido asi como			*/ 
/*	cualquier alteracion o agregado hecho por alguno de sus				*/ 
/*	usuarios sin el debido consentimiento por escrito de la 			*/ 
/*	Presidencia Ejecutiva de MACOSA o su representante.					*/ 
/************************************************************************/ 
/*				MODIFICACIONES											*/ 
/*	FECHA		AUTOR		RAZON										*/ 
/*	Enero 2003      F. Escudero	Versión Producción						*/ 
/*      Octubre 2003	J. Gutierrez	Compensaci¢n Electrónica		*/
/*      16/Jun/2006     F. Uzcategui    Optimizacion                    */
/*      08/Jul/2021     D. Morla  	Emision inicial (Migración ATMSRV) 	*/
/************************************************************************/ 
use cob_atm_his                                                                
go                                                                         
                                                                           
alter proc dbo.sp_cons_clientes_maestro (
        @s_ssn            int = null,
        @s_srv            varchar(30) = null,
        @s_lsrv           varchar(30) = null,
        @s_user           varchar(30) = null,
        @s_sesn           int = null,
        @s_term           varchar(10) = null,
        @s_date           datetime = null,
        @s_ofi            smallint = null,  /* Localidad origen transaccion */
        @s_rol            smallint = 1,
        @s_org_err        char(1)  = null,  /* Origen de error: [A], [S] */
        @s_error          int      = null,
        @s_sev            tinyint  = null,
        @s_msg            varchar(255)  = null,
        @s_org            char(1) = null,
        @t_debug          char(1) = 'N',
        @t_file           varchar(14) = null,
        @t_from           varchar(32) = null,
        @t_rty            char(1) = 'N',
        @t_trn            smallint,
        @i_cta            cuenta = null, --JGU 151003
	@i_ejecucion	  varchar(20) = '- Cod. Tarjeta',
        @i_fecha_ini      datetime = null,
        @i_fecha_fin      datetime = null,
        @i_fecha_tran      datetime = null,
        @i_tarjeta        varchar(30)=null,
	@i_tarjeta_sig    varchar(30)=null,
	@i_autoriza	  int = 0,
	@i_estado	  char(1) = 'T',
	@i_historico	  char(1) = 'N',
        @i_siguiente      int = 0,
	@i_operacion	  char(1) = null
)
as
declare @w_return             int,
        @w_sp_name            varchar(30),
	@w_correccion	      varchar(3),
	@w_cuenta	      varchar(30)

select @w_sp_name = 'sp_cons_clientes_maestro'

/* Validacion de la transaccion */
if @t_trn != 16876
begin
    /* Error en Codigo de Transaccion */
    exec cobis..sp_cerror
	@t_debug = @t_debug,
	@t_file  = @t_file,
	@t_from  = @w_sp_name,
	@i_num   = 201048
    return 1
end

select @i_siguiente = isnull(@i_siguiente,0),
	@i_tarjeta_sig = isnull(@i_tarjeta_sig,'0'),
	@i_fecha_tran  = isnull(@i_fecha_tran,@i_fecha_ini)

if @i_operacion = 'A'
begin
if @i_historico = 'N'
begin

set rowcount 15

if @i_ejecucion = '- Cod. Tarjeta'
begin 
 /* FU 16/Junio/2006 Optimizacion */
 /* Eleminacion de los Between    */
 /* co_fecha_tran between @i_fecha_ini and @i_fecha_fin */
 /* Eleminacion de los or */
 /*   and	(co_estado_concilia = @i_estado or (@i_estado = 'T' and co_estado_concilia in ('C','N'))) */
 /* se crea una condicion @i_estado = 'T' */
if @i_estado = 'T'
begin 
 select	'Autoriza ' = co_autoriza,
	'Fecha' = convert(char(10),co_fecha_tran,101),
	'Hora'  = convert(char(8),co_hora,14),
	'Tarjeta'= co_tarjeta,
	'Cuenta              ' = isnull(co_cta_banco, '-'),
	'Trn' = co_tipo_tran,
	'Conc' = co_estado_concilia,
	'Est' = co_estado_transaccion,
	'Monto       ' = isnull(co_consumo,0),
	'Mon' = co_moneda_bco,
	'Rev' = co_reverso,
	'Terminal' = co_cod_comercio,
	'Mensaje de Error              ' = substring(isnull(co_rechazo, ' '),1,35)
 from	cob_atm_his..tm_consumos_consorcio
  where co_fecha_tran >= @i_fecha_ini
    and co_fecha_tran <= @i_fecha_fin  
    and	((co_fecha_tran = @i_fecha_tran and co_autoriza > @i_siguiente) or
	(co_fecha_tran > @i_fecha_tran))
    and	co_tarjeta = @i_tarjeta
    and	co_estado_concilia in ('C','N')
 order by co_fecha_tran, co_autoriza 
end 
else
begin 
 select	'Autoriza ' = co_autoriza,
	'Fecha' = convert(char(10),co_fecha_tran,101),
	'Hora'  = convert(char(8),co_hora,14),
	'Tarjeta'= co_tarjeta,
	'Cuenta              ' = isnull(co_cta_banco, '-'),
	'Trn' = co_tipo_tran,
	'Conc' = co_estado_concilia,
	'Est' = co_estado_transaccion,
	'Monto       ' = isnull(co_consumo,0),
	'Mon' = co_moneda_bco,
	'Rev' = co_reverso,
	'Terminal' = co_cod_comercio,
	'Mensaje de Error              ' = substring(isnull(co_rechazo, ' '),1,35)
 from	cob_atm_his..tm_consumos_consorcio
  where co_fecha_tran >= @i_fecha_ini
    and co_fecha_tran <= @i_fecha_fin  
    and	((co_fecha_tran = @i_fecha_tran and co_autoriza > @i_siguiente) or
	(co_fecha_tran > @i_fecha_tran))
    and	co_tarjeta = @i_tarjeta
    and	co_estado_concilia = @i_estado
 order by co_fecha_tran, co_autoriza 
end 
end 

if @i_ejecucion = '- Nro. Cuenta'
begin
/* FU 16/Junio/2006 Optimizacion */
/* Eleminacion de los Between    */
/* co_fecha_tran between @i_fecha_ini and @i_fecha_fin */
/* Eleminacion de los or */
/*   and	(co_estado_concilia = @i_estado or (@i_estado = 'T' and co_estado_concilia in ('C','N'))) */
/* se crea una condicion @i_estado = 'T' */
/* Eliminar el like de la cuenta formar la cuenta correctamente */
/*--FES 161203 - Inicio */
/* select @w_cuenta = '%' + substring(@i_tarjeta,14,10) + '%' */
/*--FES 161203 - Fin */

select @w_cuenta = substring(@i_tarjeta,1,4) + substring(@i_tarjeta,6,4) + substring(@i_tarjeta,11,2) + substring(@i_tarjeta,14,10)

if @i_estado = 'T'
begin 
 select	'Autoriza ' = co_autoriza,
	'Fecha' = convert(char(10),co_fecha_tran,101),
	'Hora'  = convert(char(8),co_hora,14),
	'Tarjeta'= co_tarjeta,
	'Cuenta              ' = isnull(co_cta_banco, '-'),
	'Trn' = co_tipo_tran,
	'Conc' = co_estado_concilia,
	'Est' = co_estado_transaccion,
	'Monto       ' = isnull(co_consumo,0),
	'Mon' = co_moneda_bco,
	'Rev' = co_reverso,
	'Terminal' = co_cod_comercio,
	'Mensaje de Error              ' = substring(isnull(co_rechazo, ' '),1,35)
  from	cob_atm_his..tm_consumos_consorcio with (index=i_criteriocta_mtr)
 where	co_fecha_tran >= @i_fecha_ini 
   and  co_fecha_tran <= @i_fecha_fin
   and	((co_fecha_tran = @i_fecha_tran and co_autoriza > @i_siguiente) or
	(co_fecha_tran > @i_fecha_tran))
   and	co_cta_banco = @w_cuenta
   and	co_estado_concilia in ('C','N')
 order by co_fecha_tran, co_autoriza 
end 
else
begin
 select	'Autoriza ' = co_autoriza,
	'Fecha' = convert(char(10),co_fecha_tran,101),
	'Hora'  = convert(char(8),co_hora,14),
	'Tarjeta'= co_tarjeta,
	'Cuenta              ' = isnull(co_cta_banco, '-'),
	'Trn' = co_tipo_tran,
	'Conc' = co_estado_concilia,
	'Est' = co_estado_transaccion,
	'Monto       ' = isnull(co_consumo,0),
	'Mon' = co_moneda_bco,
	'Rev' = co_reverso,
	'Terminal' = co_cod_comercio,
	'Mensaje de Error              ' = substring(isnull(co_rechazo, ' '),1,35)
  from	cob_atm_his..tm_consumos_consorcio with (index=i_criteriocta_mtr)
 where	co_fecha_tran >= @i_fecha_ini 
   and  co_fecha_tran <= @i_fecha_fin
   and	((co_fecha_tran = @i_fecha_tran and co_autoriza > @i_siguiente) or
	(co_fecha_tran > @i_fecha_tran))
   and	co_cta_banco = @w_cuenta
   and	co_estado_concilia = @i_estado
 order by co_fecha_tran, co_autoriza 
end
end



if @i_ejecucion = '- Autorizacion'
begin
/* FU 16/Junio/2006 Optimizacion */
/* Eleminacion de los Between    */
/* co_fecha_tran between @i_fecha_ini and @i_fecha_fin */
/* Eleminacion de los or */
/*   and	(co_estado_concilia = @i_estado or (@i_estado = 'T' and co_estado_concilia in ('C','N'))) */
/* se crea una condicion @i_estado = 'T' */
if @i_estado = 'T'
begin 
select	'Autoriza ' = co_autoriza,
	'Fecha' = convert(char(10),co_fecha_tran,101),
	'Hora'  = convert(char(8),co_hora,14),
	'Tarjeta'= co_tarjeta,
	'Cuenta              ' = isnull(co_cta_banco, '-'),
	'Trn' = co_tipo_tran,
	'Conc' = co_estado_concilia,
	'Est' = co_estado_transaccion,
	'Monto       ' = isnull(co_consumo,0),
	'Mon' = co_moneda_bco,
	'Rev' = co_reverso,
	'Terminal' = co_cod_comercio,
	'Mensaje de Error              ' = substring(isnull(co_rechazo, ' '),1,35)
from	cob_atm_his..tm_consumos_consorcio with (index=i_criterioaut_mtr)
 where	co_fecha_tran >= @i_fecha_ini 
   and  co_fecha_tran <= @i_fecha_fin
  and	((co_fecha_tran = @i_fecha_tran and co_tarjeta > @i_tarjeta_sig) or
	(co_fecha_tran > @i_fecha_tran))
  and	co_autoriza = @i_autoriza
  and	co_estado_concilia in ('C','N')
order by co_fecha_tran, co_tarjeta 
end
else
begin
select	'Autoriza ' = co_autoriza,
	'Fecha' = convert(char(10),co_fecha_tran,101),
	'Hora'  = convert(char(8),co_hora,14),
	'Tarjeta'= co_tarjeta,
	'Cuenta              ' = isnull(co_cta_banco, '-'),
	'Trn' = co_tipo_tran,
	'Conc' = co_estado_concilia,
	'Est' = co_estado_transaccion,
	'Monto       ' = isnull(co_consumo,0),
	'Mon' = co_moneda_bco,
	'Rev' = co_reverso,
	'Terminal' = co_cod_comercio,
	'Mensaje de Error              ' = substring(isnull(co_rechazo, ' '),1,35)
from	cob_atm_his..tm_consumos_consorcio with (index=i_criterioaut_mtr)
 where	co_fecha_tran >= @i_fecha_ini 
   and  co_fecha_tran <= @i_fecha_fin
  and	((co_fecha_tran = @i_fecha_tran and co_tarjeta > @i_tarjeta_sig) or
	(co_fecha_tran > @i_fecha_tran))
  and	co_autoriza = @i_autoriza
  and	co_estado_concilia = @i_estado 
order by co_fecha_tran, co_tarjeta 
end 
end 

set rowcount 0
end


if @i_historico = 'S'
begin

set rowcount 15

if @i_ejecucion = '- Cod. Tarjeta'
begin
/* FU 16/Junio/2006 Optimizacion */
/* Eleminacion de los Between    */
/* co_fecha_tran between @i_fecha_ini and @i_fecha_fin */
/* Eleminacion de los or */
/*   and	(co_estado_concilia = @i_estado or (@i_estado = 'T' and co_estado_concilia in ('C','N'))) */
/* se crea una condicion @i_estado = 'T' */
if @i_estado = 'T'
begin 
select	'Autoriza ' = co_autoriza,
	'Fecha' = convert(char(10),co_fecha_tran,101),
	'Hora'  = convert(char(8),co_hora,14),
	'Tarjeta'= co_tarjeta,
	'Cuenta              ' = isnull(co_cta_banco, '-'),
	'Trn' = co_tipo_tran,
	'Conc' = co_estado_concilia,
	'Est' = co_estado_transaccion,
	'Monto       ' = isnull(co_consumo,0),
	'Mon' = co_moneda_bco,
	'Rev' = co_reverso,
	'Terminal' = co_cod_comercio,
	'Mensaje de Error              ' = substring(isnull(co_rechazo, ' '),1,35)
from	cob_atm_his..tm_consumos_consorcio_his
where	co_fecha_tran >= @i_fecha_ini 
  and   co_fecha_tran <= @i_fecha_fin
  and	((co_fecha_tran = @i_fecha_tran and co_autoriza > @i_siguiente) or
	(co_fecha_tran > @i_fecha_tran))
  and	co_tarjeta = @i_tarjeta
  and	co_estado_concilia in ('C','N')
order by co_fecha_tran, co_autoriza 
end 
else 
begin 
select	'Autoriza ' = co_autoriza,
	'Fecha' = convert(char(10),co_fecha_tran,101),
	'Hora'  = convert(char(8),co_hora,14),
	'Tarjeta'= co_tarjeta,
	'Cuenta              ' = isnull(co_cta_banco, '-'),
	'Trn' = co_tipo_tran,
	'Conc' = co_estado_concilia,
	'Est' = co_estado_transaccion,
	'Monto       ' = isnull(co_consumo,0),
	'Mon' = co_moneda_bco,
	'Rev' = co_reverso,
	'Terminal' = co_cod_comercio,
	'Mensaje de Error              ' = substring(isnull(co_rechazo, ' '),1,35)
from	cob_atm_his..tm_consumos_consorcio_his
where	co_fecha_tran >= @i_fecha_ini 
  and   co_fecha_tran <= @i_fecha_fin
  and	((co_fecha_tran = @i_fecha_tran and co_autoriza > @i_siguiente) or
	(co_fecha_tran > @i_fecha_tran))
  and	co_tarjeta = @i_tarjeta
  and	co_estado_concilia = @i_estado
order by co_fecha_tran, co_autoriza 
end 
end


if @i_ejecucion = '- Nro. Cuenta'
begin
/* FU 16/Junio/2006 Optimizacion */
/* Eleminacion de los Between    */
/* co_fecha_tran between @i_fecha_ini and @i_fecha_fin */
/* Eleminacion de los or */
/*   and	(co_estado_concilia = @i_estado or (@i_estado = 'T' and co_estado_concilia in ('C','N'))) */
/* se crea una condicion @i_estado = 'T' */
/* Eliminar el like de la cuenta formar la cuenta correctamente */
/*--FES 161203 - Inicio */
/* select @w_cuenta = '%' + substring(@i_tarjeta,14,10) + '%' */
/*--FES 161203 - Fin */

select @w_cuenta = substring(@i_tarjeta,1,4) + substring(@i_tarjeta,6,4) + substring(@i_tarjeta,11,2) + substring(@i_tarjeta,14,10)

if @i_estado = 'T'
begin 
select	'Autoriza ' = co_autoriza,
	'Fecha' = convert(char(10),co_fecha_tran,101),
	'Hora'  = convert(char(8),co_hora,14),
	'Tarjeta'= co_tarjeta,
	'Cuenta              ' = isnull(co_cta_banco, '-'),
	'Trn' = co_tipo_tran,
	'Conc' = co_estado_concilia,
	'Est' = co_estado_transaccion,
	'Monto       ' = isnull(co_consumo,0),
	'Mon' = co_moneda_bco,
	'Rev' = co_reverso,
	'Terminal' = co_cod_comercio,
	'Mensaje de Error              ' = substring(isnull(co_rechazo, ' '),1,35)
from	cob_atm_his..tm_consumos_consorcio_his  with (index=i_criteriocta_mtr)
where	co_fecha_tran >= @i_fecha_ini 
  and   co_fecha_tran <= @i_fecha_fin
  and	((co_fecha_tran = @i_fecha_tran and co_autoriza > @i_siguiente) or
	(co_fecha_tran > @i_fecha_tran))
  and	co_cta_banco = @w_cuenta
  and	co_estado_concilia in ('C','N')
order by co_fecha_tran, co_autoriza 
end 
else 
begin
select	'Autoriza ' = co_autoriza,
	'Fecha' = convert(char(10),co_fecha_tran,101),
	'Hora'  = convert(char(8),co_hora,14),
	'Tarjeta'= co_tarjeta,
	'Cuenta              ' = isnull(co_cta_banco, '-'),
	'Trn' = co_tipo_tran,
	'Conc' = co_estado_concilia,
	'Est' = co_estado_transaccion,
	'Monto       ' = isnull(co_consumo,0),
	'Mon' = co_moneda_bco,
	'Rev' = co_reverso,
	'Terminal' = co_cod_comercio,
	'Mensaje de Error              ' = substring(isnull(co_rechazo, ' '),1,35)
from	cob_atm_his..tm_consumos_consorcio_his  with (index=i_criteriocta_mtr)
where	co_fecha_tran >= @i_fecha_ini 
  and   co_fecha_tran <= @i_fecha_fin
  and	((co_fecha_tran = @i_fecha_tran and co_autoriza > @i_siguiente) or
	(co_fecha_tran > @i_fecha_tran))
  and	co_cta_banco = @w_cuenta
  and	co_estado_concilia = @i_estado 
order by co_fecha_tran, co_autoriza 
end 
end

if @i_ejecucion = '- Autorizacion'
begin
/* FU 16/Junio/2006 Optimizacion */
/* Eleminacion de los Between    */
/* co_fecha_tran between @i_fecha_ini and @i_fecha_fin */
/* Eleminacion de los or */
/*   and	(co_estado_concilia = @i_estado or (@i_estado = 'T' and co_estado_concilia in ('C','N'))) */
/* se crea una condicion @i_estado = 'T' */
if @i_estado = 'T'
begin
select	'Autoriza ' = co_autoriza,
	'Fecha' = convert(char(10),co_fecha_tran,101),
	'Hora'  = convert(char(8),co_hora,14),
	'Tarjeta'= co_tarjeta,
	'Cuenta              ' = isnull(co_cta_banco, '-'),
	'Trn' = co_tipo_tran,
	'Conc' = co_estado_concilia,
	'Est' = co_estado_transaccion,
	'Monto       ' = isnull(co_consumo,0),
	'Mon' = co_moneda_bco,
	'Rev' = co_reverso,
	'Terminal' = co_cod_comercio,
	'Mensaje de Error              ' = substring(isnull(co_rechazo, ' '),1,35)
from	cob_atm_his..tm_consumos_consorcio_his with (index=i_criterioaut_mtr)
where	co_fecha_tran >= @i_fecha_ini 
  and   co_fecha_tran <= @i_fecha_fin
  and	((co_fecha_tran = @i_fecha_tran and co_tarjeta > @i_tarjeta_sig) or
	(co_fecha_tran > @i_fecha_tran))
  and	co_autoriza = @i_autoriza
  and	co_estado_concilia in ('C','N')
order by co_fecha_tran, co_tarjeta 
end
else 
begin
select	'Autoriza ' = co_autoriza,
	'Fecha' = convert(char(10),co_fecha_tran,101),
	'Hora'  = convert(char(8),co_hora,14),
	'Tarjeta'= co_tarjeta,
	'Cuenta              ' = isnull(co_cta_banco, '-'),
	'Trn' = co_tipo_tran,
	'Conc' = co_estado_concilia,
	'Est' = co_estado_transaccion,
	'Monto       ' = isnull(co_consumo,0),
	'Mon' = co_moneda_bco,
	'Rev' = co_reverso,
	'Terminal' = co_cod_comercio,
	'Mensaje de Error              ' = substring(isnull(co_rechazo, ' '),1,35)
from	cob_atm_his..tm_consumos_consorcio_his with (index=i_criterioaut_mtr)
where	co_fecha_tran >= @i_fecha_ini 
  and   co_fecha_tran <= @i_fecha_fin
  and	((co_fecha_tran = @i_fecha_tran and co_tarjeta > @i_tarjeta_sig) or
	(co_fecha_tran > @i_fecha_tran))
  and	co_autoriza = @i_autoriza
  and	co_estado_concilia = @i_estado
order by co_fecha_tran, co_tarjeta 
end 

end 

set rowcount 0
end
end

if @i_operacion = 'B'
begin
set rowcount 0
if @i_historico = 'N'
select
'Tarjeta' = ac_tarjeta,
'Autoriza' = ac_autoriza,
'Monto' = ac_monto,
'Monto ME' = ac_monto_me,
'Moneda' = ac_moneda,
'Trace' = ac_trace,
'Transaccion' = ac_transaccion,
'Fecha Tran' = ac_fecha_tran,
'Fecha Pos' = ac_fecha_pos,
'Hora' = ac_hora,
'Referencia' = ac_referencia,
'Comercio' = ac_comercio,
'Cod. Comercio' = ac_cod_comercio,
'Cat. Comercio' = ac_cat_comercio,
'Tipo Tran' = ac_ttransaccion,
'Banco' = ac_banco,
'Sobrecargo' = ac_sobrecargo
from cob_atm_his..tm_atm_consorcio
where ac_tarjeta = @i_tarjeta
and ac_autoriza = @i_autoriza

if @i_historico = 'S'
select
'Tarjeta' = ac_tarjeta,
'Autoriza' = ac_autoriza,
'Monto' = ac_monto,
'Monto ME' = ac_monto_me,
'Moneda' = ac_moneda,
'Trace' = ac_trace,
'Transaccion' = ac_transaccion,
'Fecha Tran' = ac_fecha_tran,
'Fecha Pos' = ac_fecha_pos,
'Hora' = ac_hora,
'Referencia' = ac_referencia,
'Comercio' = ac_comercio,
'Cod. Comercio' = ac_cod_comercio,
'Cat. Comercio' = ac_cat_comercio,
'Tipo Tran' = ac_ttransaccion,
'Banco' = ac_banco,
'Sobrecargo' = ac_sobrecargo
from cob_atm_his..tm_atm_consorcio_his
where ac_tarjeta = @i_tarjeta
and ac_autoriza = @i_autoriza
end

if @i_operacion = 'C' 
begin
set rowcount 0

select
'Tarjeta' = ac_tarjeta,
'Autoriza' = ac_autoriza,
'Monto' = ac_monto,
'Monto ME' = ac_monto_me,
'Moneda' = ac_moneda,
'Trace' = ac_trace,
'Transaccion' = ac_transaccion,
'Fecha Tran' = ac_fecha_tran,
'Fecha Pos' = ac_fecha_pos,
'Hora' = ac_hora,
'Referencia' = ac_referencia,
'Comercio' = ac_comercio,
'Cod. Comercio' = ac_cod_comercio,
'Cat. Comercio' = ac_cat_comercio,
'Tipo Tran' = ac_ttransaccion,
'Banco' = ac_banco,
'Sobrecargo' = ac_sobrecargo
from cob_atm_his..tm_atm_consorcio
where ac_tarjeta = @i_tarjeta
and ac_autoriza = @i_autoriza

--FES 201003
if @@rowcount = 0
select
'Tarjeta' = ac_tarjeta,
'Autoriza' = ac_autoriza,
'Monto' = ac_monto,
'Monto ME' = ac_monto_me,
'Moneda' = ac_moneda,
'Trace' = ac_trace,
'Transaccion' = ac_transaccion,
'Fecha Tran' = ac_fecha_tran,
'Fecha Pos' = ac_fecha_pos,
'Hora' = ac_hora,
'Referencia' = ac_referencia,
'Comercio' = ac_comercio,
'Cod. Comercio' = ac_cod_comercio,
'Cat. Comercio' = ac_cat_comercio,
'Tipo Tran' = ac_ttransaccion,
'Banco' = ac_banco,
'Sobrecargo' = ac_sobrecargo
from cob_atm_his..tm_atm_consorcio_his
where ac_tarjeta = @i_tarjeta
and ac_autoriza = @i_autoriza
end


return 0
go
IF OBJECT_ID('dbo.sp_cons_clientes_maestro') IS NOT NULL
    PRINT '<<< ALTERED PROCEDURE dbo.sp_cons_clientes_maestro >>>'
ELSE
    PRINT '<<< FAILED ALTERING PROCEDURE dbo.sp_cons_clientes_maestro >>>'
go
SET ANSI_NULLS OFF
go
SET QUOTED_IDENTIFIER OFF
go
