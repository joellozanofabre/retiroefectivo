/*

select top 100 en_subtipo,ah_disponible,ah_cliente,ah_cta_banco,ah_moneda, ah_cuenta,ah_bloqueos,ah_suspensos
from cob_ahorros..ah_cuenta , cobis..cl_ente
where ah_cliente = en_ente and ah_disponible > 0
and ah_moneda = 1
--and ah_estado ='C'
and ah_bloqueos >0

en_subtipo ah_disponible              ah_cliente  ah_cta_banco     ah_moneda ah_cuenta   ah_bloqueos
---------- -------------------------- ----------- ---------------- --------- ----------- -----------
P          68,946.21                  82574638    000000970422001  0         1611248     
P          1,924.75                   79365947    000001273225001  0         1611296     
P          28.99                      80856245    000001330025001  0         1611302 
P          5,696.82                   81152322    000001854921004  0         1611390     
P          103,401.25                 79050962    000002379625001  0         1611486 
P          24,886.17                  78864400    000000750024001  1         1611202     
P          743.37                     81001596    000000836724001  1         1611233     
P          8,507.05                   80394730    000000898724002  1         1611241     
P          0.00                       79180157    000000982926004  1         1611249 
P          1.98                       79945064    000004113728004  1         1611757   C   
P          15.00                      80982771    000021584838001  1         1614138   C 
P          0.00                       79554880    000029611124002  1         1615297   C
P          1,285.78                   79091626    000001265824001  1         1611295     1           0            
P          3,538.80                   81857563    000001360723001  1         1611304     1           0  


select top 100 en_subtipo,cc_disponible,cc_cliente, cc_ctacte, cc_cta_banco,cc_moneda,cc_bloqueos,cc_suspensos,cc_estado
from cob_cuentas..cc_ctacte , cobis..cl_ente
where cc_cliente = en_ente 
and cc_moneda = 1
--and cc_estado ='C'
and cc_disponible > 0
and cc_bloqueos >0

en_subtipo cc_disponible              cc_cliente  cc_ctacte   cc_cta_banco     cc_moneda cc_bloqueos cc_suspensos cc_estado 
---------- -------------------------- ----------- ----------- ---------------- --------- ----------- ------------ --------- 
C          0.00                       81519269    554079      000000001812003  1         0           0            C         
C          0.00                       79137600    554082      000000002612004  1         0           0            C 
P          598.58                     82304622    555253      000050757412003  1         1           0            
P          504.11                     82216839    555320      000053429712002  1         1           0            
P          507.29                     79847950    555466      000062753912002  1         1           0            
P          15,678.02                  79038474    554242      000003063511001  0         1           0            
P          2,256.53                   81125228    554254      000003824015001  0         0           1            
P          25,948.37                  81454353    554257      000004064211001  0         0           0            
P          11,436.02                  81922101    554263      000004364611001  0         0           0            
C          0.00                       78526076    554084      000000003411003  0         0           0            C         
C          0.00                       78526122    561160      172301000003135  0         0           0            C         
P          15,162.86                  80365683    554149      000000416812002  1         1           0            A         
P          1,415.18                   81409919    554252      000003745737001  1         0           0            A         
P          1,221.55                   81742804    554253      000003748112001  1         0           0            A         
P          140.00                     81125228    554255      000003824016002  1         0           5            A         
P          10,000.02                  81888337    554256      000003829912001  1         0           0            A         




*/
	 
USE cob_bvirtual
GO 
DECLARE
      @i_cuentabanco_pignorar  cuenta
    , @i_monto                 money
    , @i_moneda                char(3)
    , @i_ctaid                 int
    , @i_cupon                 varchar(80)
    , @o_codigo_respuesta             int
    , @o_detalle_respuesta      varchar(255)
    , @return_code             int
    , @codigor                 varchar(20)
    , @returncode              varchar(20)
    , @detalle                 varchar(200)

-- Asignar valores de prueba
SET @i_cuentabanco_pignorar = '000050757412003'  
SET @i_monto                = 400.00        -- Monto a probar
set @i_ctaid                = 555253
SET @i_moneda               = 'USDNIO'             -- Moneda (ej. 1 = USD)
SET @i_cupon                = 'cupondeprueba0000000005'    

    
declare @w_saldo_para_girar money , @w_saldo_contable money



select w_valor_reserva_aho = isnull(sum(cr_valor),0)   from cob_ahorros..ah_cuenta_reservada
where cr_cuenta = @i_ctaid      and cr_estado = 'R'  


select  w_valor_reserva_cte = isnull(sum(cr_valor),0)    from cob_cuentas..cc_cuenta_reservada    
where cr_ctacte = @i_ctaid      and cr_estado = 'R' 

print '***************antes***********'

select top 100 ah_disponible,ah_moneda,* from cob_ahorros..ah_cuenta
where ah_cta_banco = @i_cuentabanco_pignorar

-- print ahorros--
select top 100 * from cob_ahorros..ah_cuenta_reservada
where cr_cuenta =  @i_ctaid

select top 10 * from  cob_bvirtual..re_retiro_efectivo 
WHERE re_cta_banco  = @i_cuentabanco_pignorar
-- print corrientes--
select top 100 cc_disponible,cc_moneda,* from cob_cuentas..cc_ctacte
where cc_cta_banco = @i_cuentabanco_pignorar

select top 100 * from cob_cuentas..cc_cuenta_reservada
where cr_ctacte =  @i_ctaid


print   'ejecuta..'
-- Ejecutar SP con control de errores

 
     EXEC @return_code = dbo.sp_OSB_re_despignorar
          @i_DEBIT_ACCOUNT        = @i_cuentabanco_pignorar
        , @i_AMOUNT               = @i_monto
        , @i_CURRENCY             = @i_moneda
        , @i_CUPON                = @i_cupon
        , @o_num_error            = @o_codigo_respuesta OUTPUT
        , @o_desc_error           = @o_detalle_respuesta OUTPUT

    -- Mostrar resultados
    PRINT '--- Resultados del SP ---'
    set @returncode = CAST(@return_code AS VARCHAR(10))
    set @codigor = CAST(@o_codigo_respuesta AS VARCHAR(10))
    set @detalle = ISNULL(@o_detalle_respuesta, 'NULL')

    
    PRINT 'ResultadoCode: %1! , Detalle: %2!, Return: %3!',@codigor,@detalle,@returncode



    /*
 201063	ERROR EN TRANSFERENCIAS
 
select top 100 ah_disponible,ah_moneda,* from cob_cuentas..cc_ctacte
where cc_fecha_aper >= '01/01/2025'
and cc_estado = 'A' 
and cc_ctacte in (554104,
554210,
554298,
554501)
*/




print 'despues' 
print '*********AHORROS************'
select top 100 ah_disponible,ah_moneda,* from cob_ahorros..ah_cuenta
where ah_cta_banco = @i_cuentabanco_pignorar


select top 100 * from cob_ahorros..ah_cuenta_reservada
where cr_cuenta =  @i_ctaid


SELECT hr_num_reserva,hr_tipo,hr_estado,*    FROM cob_ahorros..ah_his_reserva
    WHERE hr_cuenta = @i_ctaid



select top 10 * from cob_bvirtual..re_retiro_efectivo 
WHERE re_cta_banco  =  @i_cuentabanco_pignorar


print '*********CORRIENTES************'
select top 100 cc_disponible,cc_moneda,* from cob_cuentas..cc_ctacte
where cc_cta_banco = @i_cuentabanco_pignorar

select top 100 * from cob_cuentas..cc_cuenta_reservada
where cr_ctacte =  @i_ctaid



select * from cob_ahorros..ah_tran_monet
where tm_cta_banco = @i_cuentabanco_pignorar
--where tm_fecha_ult_mov >= '08/21/2025'
 


