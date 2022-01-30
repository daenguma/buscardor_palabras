/************************************************************************/
/*  ARCHIVO:         sp_paso_historico_maestro.sp                     	*/
/*  NOMBRE LOGICO:   sp_paso_historico_maestro.sp	               		*/
/*  PRODUCTO:        ATM                                        		*/
/************************************************************************/
/*                     PROPOSITO                                      	*/
/*	Migración ATM Server  												*/
/*                                                 						*/
/************************************************************************/
/*                     MODIFICACIONES                                 	*/
/*    FECHA         AUTOR               RAZON                         	*/
/*  23-Jun-2021   Adolfo Hernández  Emision inicial (Migración ATMSRV) 	*/
/************************************************************************/

USE cob_atm_his
go

SET ANSI_NULLS ON
go

ALTER proc sp_paso_historico_maestro
as

declare         @w_fecha1 varchar(10),
                @w_fecha2 varchar(10)

select @w_fecha1 = convert(varchar(10),dateadd(mm, -2, convert(varchar(10),getdate(),101)),101)
select @w_fecha2 = convert(varchar(10),dateadd(mm, -6, convert(varchar(10),getdate(),101)),101)

begin tran
                    insert into cob_atm_his..tm_atm_consorcio_his
                    select * from cob_atm_his..tm_atm_consorcio
                    where ac_fecha_tran < @w_fecha1

		    if @@error != 0
                       rollback tran
                    else
                    begin
			
		    	delete cob_atm_his..tm_atm_consorcio
                   	where ac_fecha_tran < @w_fecha1
                    	delete cob_atm_his..tm_atm_consorcio_his
                    	where ac_fecha_tran < @w_fecha2

                       	commit tran
                    end

begin tran
                    insert into cob_atm_his..tm_consumos_consorcio_his
                    select * from cob_atm_his..tm_consumos_consorcio
                    where co_fecha_tran < @w_fecha1

		    if @@error != 0
                       rollback tran
                    else
                    begin
                        delete cob_atm_his..tm_consumos_consorcio
        	        where co_fecha_tran < @w_fecha1

 	                delete cob_atm_his..tm_consumos_consorcio_his
         	        where co_fecha_tran < @w_fecha2

                        commit tran
                    end

return 0
go

SET ANSI_NULLS OFF
go
IF OBJECT_ID('dbo.sp_paso_historico_maestro') IS NOT NULL
    PRINT '<<< ALTER PROCEDURE dbo.sp_paso_historico_maestro >>>'
ELSE
    PRINT '<<< FAILED ALTER PROCEDURE dbo.sp_paso_historico_maestro >>>'
go
