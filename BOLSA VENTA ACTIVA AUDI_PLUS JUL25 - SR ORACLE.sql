
	--********************************************
	-- TABLAS INPUT O INTERMEDIAS
	--********************************************

	------------------------------------
	--- 0. GEN_VEHICULOS
	------------------------------------

	SELECT 
	* INTO #Sima_Gen_Vehiculos
	FROM Sima_Gen_Vehiculos WHERE Empresa IN ('EUROSHOP','EUROMOTORS')

	SELECT 
	* INTO #SIMA_Gen_Tercero_Creacion
	FROM SIMA_Gen_Tercero_Creacion WHERE Empresa IN ('EUROSHOP','EUROMOTORS')

	SELECT 
	* INTO #Sima_Gen_Vehiculos_Marcas
	FROM Sima_Gen_Vehiculos_Marcas WHERE Empresa IN ('EUROSHOP','EUROMOTORS')


	SELECT m.Descripcion Marca,v.Bastidor,
	CONVERT(DATE, v.FechaMatriculacion) FechaMatriculacion, 
	CONVERT(DATE,v.FechaVenta) FechaVenta,v.PropietarioTerceroId,
	v.Empresa, 
	t.TipoIdentificacionFiscal, 
	t.IdentificacionFiscal, 
	CASE WHEN ModelYearId IS NOT NULL THEN CAST(ModelYearId AS VARCHAR(4)) END ModelYearId
	INTO #Tabla_veh
	FROM #Sima_Gen_Vehiculos v 
    INNER JOIN #Sima_Gen_Vehiculos_Marcas m ON v.Empresa=m.Empresa AND v.IdMarca=m.IdMarca
	INNER JOIN #SIMA_Gen_Tercero_Creacion t ON v.Empresa=t.empresa AND v.PropietarioTerceroId=t.TerceroId

	SELECT *
	INTO #Sima_Gen_Vehiculos_essa
	FROM #Tabla_veh 
	WHERE Empresa IN ('EUROSHOP')
	AND MARCA IN ('Audi','PORSCHE','SEAT','CUPRA','DUCATI','VW Pasajeros','VW Comerciales','LAMBORGHINI')

	SELECT *
	INTO #Sima_Gen_Vehiculos_emsa
	FROM #Tabla_veh 
	WHERE Empresa IN ('EUROMOTORS')
	AND MARCA IN ('Audi','PORSCHE','SEAT','CUPRA','DUCATI','VW Pasajeros','VW Comerciales','LAMBORGHINI')
	AND Bastidor NOT IN (SELECT Bastidor FROM #Sima_Gen_Vehiculos_essa)


	SELECT *
	INTO #VEH_EMSA_ESSA
	FROM  #Sima_Gen_Vehiculos_essa
	UNION ALL
	SELECT *FROM  #Sima_Gen_Vehiculos_emsa


	SELECT *, 
	CASE 
	WHEN FechaVenta IS NOT NULL THEN DATEDIFF(MONTH,FechaVenta, CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, '2025-06-30') + 1, 0) AS DATE))
	WHEN FechaVenta IS NULL AND ModelYearId IS NULL THEN  DATEDIFF(MONTH,FechaMatriculacion, CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, '2025-06-30') + 1, 0) AS DATE))
	ELSE 9999
	END Antiguedad_meses,
	CASE 
	WHEN FechaVenta IS NOT NULL THEN FechaVenta
	WHEN FechaVenta IS NULL AND ModelYearId IS NULL THEN FechaMatriculacion ELSE NULL END FechaVenta_consolidado
	INTO  #VEH_EMSA_ESSA_2
	FROM  #VEH_EMSA_ESSA
	
	

	SELECT 
	CASE
	WHEN Antiguedad_meses >=0 AND Antiguedad_meses <=4 THEN 'SEGMENTO I'
	WHEN Antiguedad_meses >=5 AND Antiguedad_meses <=7 THEN 'SEGMENTO II'
	WHEN Antiguedad_meses >=8 AND Antiguedad_meses <=15 THEN 'SEGMENTO III'
	ELSE 'CLÁSICO'
	END Segmento_Antiguedad,
	CASE
	WHEN Antiguedad_meses >=0 AND Antiguedad_meses <=2 THEN 'SEGMENTO IA'
	WHEN Antiguedad_meses >=3 AND Antiguedad_meses <=4 THEN 'SEGMENTO IB'
	WHEN Antiguedad_meses >=5 AND Antiguedad_meses <=7 THEN ''
	WHEN Antiguedad_meses >=8 AND Antiguedad_meses <=10 THEN 'SEGMENTO IIIA'
	WHEN Antiguedad_meses >=11 AND Antiguedad_meses <=15 THEN 'SEGMENTO IIIB'
	ELSE ''
	END SubSegmento_Antiguedad
	,*
	INTO #GEN_VEHICULOS   ---GEN VEHICULOS
	FROM #VEH_EMSA_ESSA_2


	-------------------------------------
    -- 0. REPORTE DESPACHOS VN
	-------------------------------------

	SELECT
	Empresa, Marca,Bastidor, MAX(CONVERT(DATE, [Fecha Despacho])) Ult_FechaDespacho
	INTO  #MAX_DESPACHO
	FROM SIMA_DESPACHOS
	WHERE Empresa IN ('EUROSHOP')
	AND MARCA = 'Audi' 
	AND [Fecha Despacho] IS NOT NULL 
	AND AbonadoRectificado ='No' 
	--AND Centro NOT IN ('Seat Arequipa','Cupra Arequipa')
	GROUP BY Empresa, Marca,Bastidor,MY


	SELECT
	d.Empresa,
	d.[Fecha Despacho],
	d.Bastidor,
	d.Marca,
	d.ModeloDn,
	d.MY,
	d.Matricula, 
	d.TipoIdentificacionFiscal,
	d.IdentificacionFiscal, 
	d.ReceptorTerceroNombre,
	d.Centro
	INTO #Tabla_intermedia_despachos
	FROM #MAX_DESPACHO b LEFT JOIN 
	(SELECT *fROM SIMA_DESPACHOS WHERE Empresa IN ('EUROSHOP')
	AND MARCA = 'Audi' 
	AND AbonadoRectificado ='No' 
	AND [Fecha Despacho] IS NOT NULL 
	--AND Centro NOT IN ('Seat Arequipa')
	) d 
	ON b.Bastidor=d.Bastidor AND b.Ult_FechaDespacho=d.[Fecha Despacho]


	SELECT
	t.*,
	g.Antiguedad_meses,
	g.Segmento_Antiguedad,
	g.SubSegmento_Antiguedad,
	g.FechaVenta_consolidado
	INTO #SIMA_DESPACHOS   --- SIMA_DESPACHOS
	FROM #Tabla_intermedia_despachos t LEFT JOIN #GEN_VEHICULOS g ON t.Bastidor=g.Bastidor AND t.empresa=g.empresa


	--SELECT*
	--INTO #MAESTRO_DESPACHOS_1ER_MANTENIMIENTO
	--FROM #SIMA_DESPACHOS WHERE CONVERT(DATE, [Fecha Despacho]) LIKE '2024-06-%' 

	-------------------------------------------------------------------
    -- 1. REPORTE DE ENTREGAS TALLER SIMA: Total de OTs
	-------------------------------------------------------------------

	SELECT DISTINCT 
	Empresa,
	Marca,
	Modelo,
	Bastidor,
	Matricula,
	AñoModelo,
	Taller, 
	TipoDocDepositario,
	DocumentoDepositario,
	Depositario,
	TipoDocPropietario,
	DocumentoPropietario,
	Propietario,
	UsuarioCreador,
	Asesor,
	CONVERT(DATE,Creada) FechaCreacion,
	CONVERT(DATE,FechaCita) FechaCita,
	CONVERT(DATE,Entregado) Fecha_Entrega,
	CONVERT(DATE,Apertura) Apertura,
	Tipo,
	Centro,
	Orden,
	KMS, 
	Estado, 
	Anulacion
	INTO #REPORTE_ENTREGAS_
	FROM [dbo].[SIMA_CITAS_PASOS_TALLER]
	WHERE Empresa IN ('EUROSHOP')
	AND Centro IN ('ABA','ADB','ALM','ASQ','EJP','ESQ','PLM','POM','POS','PSB','SEA','RSA','DUC','LSQ')  -- ABA CERRÓ EN EL 2022
	AND Marca = 'Audi'
	AND (Estado <> ('Anulada') OR Anulacion IS NOT NULL)
	--AND Tipo <> 'POSPUESTA'
	AND Bastidor NOT IN 
	('11111111111111111','12345677777777777','33333333333333333','66666666666666666','77777777777777777','88888888888888800',
	'88888888888888888','99999999999999900','99999999999999999','WAUZ1111111111110','WAUZ1111111111111','000000000P0045732','10308762','77777777777777700') -- BASTIDOR DE USO INTERNO
	AND LEN(Bastidor) > 0


	SELECT DISTINCT 
	r.Empresa,
	r.Marca,
	r.Modelo,
	r.Bastidor,
	r.Matricula,
	r.AñoModelo,
	r.Taller, 
	r.TipoDocDepositario,
	r.DocumentoDepositario,
	r.Depositario,
	r.TipoDocPropietario,
	r.DocumentoPropietario,
	r.Propietario,
	r.UsuarioCreador,
	r.Asesor,
	r.FechaCreacion,
	r.FechaCita,
	r.Fecha_Entrega,
	r.Apertura,
	r.Tipo,
	r.Centro,
	r.Orden,
	r.KMS, 
	r.Estado, 
	r.Anulacion,
	v.Antiguedad_meses Antiguedad,
	v.Segmento_Antiguedad, 
	v.SubSegmento_Antiguedad, 
	v.FechaVenta_consolidado , 
	d.[Fecha Despacho]
	INTO #REPORTE_ENTREGAS
	FROM #REPORTE_ENTREGAS_ r
	LEFT JOIN #GEN_VEHICULOS v ON r.Bastidor=v.Bastidor
	LEFT JOIN #SIMA_DESPACHOS d ON r.Bastidor=d.Bastidor 

    ---------------------------------------------------------------------
	--- VEHÍCULOS QUE YA TIENEN CITA Y SE DEBEN QUITAR DE LA BOLSA
	---------------------------------------------------------------------
	
	SELECT DISTINCT 
	CONVERT(DATE,Creada) FechaCreacion,
	CONVERT(DATE,FechaCita) FechaCita,
	CONVERT(DATE,Apertura) Apertura, 
	DATEDIFF(MONTH, Apertura, '2025-06-30') DateDiff_Apertura,
	Empresa,
	Marca,
	Modelo,
	Bastidor,
	Matricula,
	AñoModelo,
	Taller, 
	DocumentoDepositario,
	Depositario,
	UsuarioCreador,
	CONVERT(DATE,Entregado) Fecha_Entrega,
	Tipo,
	Centro,
	Orden,
	KMS, Estado
	INTO #BASE_QUITAR
	FROM [dbo].[SIMA_CITAS_PASOS_TALLER]
	WHERE 
	Empresa  IN ('EUROSHOP')
	AND Centro IN ('ABA','ADB','ALM','ASQ','EJP','ESQ','PLM','POM','POS','PSB','SEA','RSA','DUC','LSQ','-')  -- ABA CERRÓ EN EL 2022
	AND Taller NOT LIKE '%PLANCHADO%'
	AND Marca = 'Audi'
	AND Estado <> ('Anulada')
	AND Apertura IS NULL
	AND Tipo IN ('PREVIA','PRESENCIAL','POSPUESTA')
	AND Bastidor NOT IN 
	('11111111111111111','12345677777777777','33333333333333333','66666666666666666',
	'77777777777777777','88888888888888800','88888888888888888','99999999999999900','99999999999999999','WAUZ1111111111110','WAUZ1111111111111','000000000P0045732','10308762','77777777777777700') -- BASTIDOR DE USO INTERNO
	AND LEN(Bastidor) >0
	AND CONVERT(DATE,FechaCita) >= CONVERT(DATE,'2025-06-30')

	----------------------------------------------------------------
	-- 2. REPORTE DE IMPUTACIONES DE OTs FACTURADAS Y SIN FACTURAR
	----------------------------------------------------------------

	-- A. REPORTE DE OTs FACTURADAS
    SELECT DISTINCT 
	Empresa, 
	MarcaDn,
	ModeloDn,
	VIN,
	Placa,
	AñoModelo,
	TallerDn, 
	Serie, 
	DepositarioTerceroId,
	DepositarioDn,
	Asesor,
	CONVERT(DATE,Fecha_Entrega) Fecha_Entrega,
	CONVERT(DATE,Fecha_Apertura) Fecha_Apertura,
	kms,
	CONCAT(orden, serie, año) OT,
	ServicioDn,
	Canal
	INTO  #SIMA_REPORTE_IMPUTACIONES
	FROM [dbo].[SIMA_FACTURACION_IMPUTACIONES] 
	WHERE Empresa IN ('EUROSHOP')
	AND ( (ServicioDn = 'PREVENTIVO') OR (ServicioDn = 'CORRECTIVO' AND Actividad LIKE '%FILTRO ACEITE%') )
	AND Serie IN ('ABA','ADB','ALM','ASQ','EJP','ESQ','PLM','POM','POS','PSB','SEA','RSA','DUC','LSQ')  -- ABA CERRÓ EN EL 2022)
	AND VIN NOT IN 
	('11111111111111111','12345677777777777','33333333333333333','66666666666666666',
	'77777777777777777','88888888888888800','88888888888888888','99999999999999900','99999999999999999','WAUZ1111111111110','WAUZ1111111111111','000000000P0045732','10308762','77777777777777700')  -- BASTIDOR DE USO INTERNO
	AND LEN(VIN) >0
	AND Canal ='Cliente'
	AND MarcaDn = 'Audi'


	UNION ALL
	-- B. REPORTE DE OTs SIN FACTURAR

	SELECT DISTINCT 
	Empresa, 
	MarcaDn,
	ModeloDn,
	VIN,
	Placa,
	AñoModelo,
	TallerDn, 
	Serie, 
	DepositarioTerceroId,
	DepositarioDn,
	Asesor,
	CONVERT(DATE,Fecha_Entrega) Fecha_Entrega,
	CONVERT(DATE,Fecha_Apertura) Fecha_Apertura,
	kms,
	CONCAT(orden, serie, año) OT,
	ServicioDn,
	Canal
	FROM SIMA_TAL_SIN_FACTURAR_IMPUTACIONES
	WHERE Empresa IN ('EUROSHOP')
	AND ( (ServicioDn = 'PREVENTIVO') OR (ServicioDn = 'CORRECTIVO' AND Actividad LIKE '%FILTRO ACEITE%') )
	AND Serie IN ('ABA','ADB','ALM','ASQ','EJP','ESQ','PLM','POM','POS','PSB','SEA','RSA','DUC','LSQ')   -- ABA CERRÓ EN EL 2022
	AND VIN NOT IN 
	('11111111111111111','12345677777777777','33333333333333333','66666666666666666',
	'77777777777777777','88888888888888800','88888888888888888','99999999999999900','99999999999999999','WAUZ1111111111110','WAUZ1111111111111','000000000P0045732','10308762','77777777777777700') -- BASTIDOR DE USO INTERNO
	AND LEN(VIN) >0
	AND Canal ='Cliente'
	AND MarcaDn = 'Audi'


	-------------------------------------------------------------
	-- CRUCE DEL REPORTE DE ENTREGAS VS REPORTE DE IMPUTACIONES 
	-------------------------------------------------------------

	SELECT DISTINCT 
	r.*,
	s.ServicioDn,
	s.Canal
	INTO  #REPORTE_ENTREGAS_FINAL
	FROM #REPORTE_ENTREGAS r 
	LEFT JOIN #SIMA_REPORTE_IMPUTACIONES s ON r.Orden=s.OT 

	SELECT DISTINCT 
	Empresa,
	Marca,
	Modelo,
	Bastidor,
	Matricula,
	AñoModelo,
	Taller,
	TipoDocDepositario,
	DocumentoDepositario,
	Depositario,
	TipoDocPropietario,
	DocumentoPropietario,
	Propietario,
	UsuarioCreador,
	Asesor,
	FechaCreacion,
	FechaCita,
	Fecha_Entrega,
	Apertura,
	Tipo,
	Centro,
	Orden,
	KMS,
	Estado,
	'PREVENTIVO'  ServicioDn,  -- se corrigen las averías de PREVENTIVO que fueron creadas incorrectamente como CORRECTIVO
	Canal,
	Antiguedad,
	Segmento_Antiguedad,
	SubSegmento_Antiguedad,
	FechaVenta_consolidado
	INTO #TABLA
	fROM #REPORTE_ENTREGAS_FINAL  WHERE ServicioDn IN ('PREVENTIVO')



	--**************************************************************
	--0. TABLA INTERMEDIA DE REPORTE DE ENTREGAS SOLO PREVENTIVO
	--**************************************************************

	SELECT Bastidor, MAX(Apertura) Ult_visita, COUNT (DISTINCT Orden) n_preventivos
	INTO #MAX_APERTURA
	FROM #TABLA GROUP BY Bastidor


	SELECT DISTINCT
	DATEDIFF(MONTH,Apertura, CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, '2025-06-30') + 1, 0) AS DATE)) Ult_visita_meses,
	m.*, t.n_preventivos
	INTO #MAESTRO_REPORTE_ENTREGAS_PREVENTIVO
	FROM #TABLA m 
	INNER JOIN #MAX_APERTURA t ON  t.Bastidor=m.Bastidor AND m.Apertura=t.Ult_visita



	---- VALIDACIÓN

	---SELECT *fROM #TABLA WHERE Bastidor ='ZHWEF5ZF7LLA14676'
	

    --- INICIO DE LÓGICA DE VA


    SELECT *,
	COUNT(*) OVER (PARTITION BY Bastidor) as Ingresos,
		
	CASE 
	WHEN VarianzaMeses = MesesAlineamiento AND VarianzaKM = KMAlineamiento THEN 'Ingreso por Tiempo y KM'
	WHEN Marca = 'Audi' AND VarianzaMeses <= MesesAlineamiento + 1 AND VarianzaMeses >= MesesAlineamiento - 1 THEN 'Ingreso por tiempo'
	WHEN VarianzaKM <= KMAlineamiento + 1000 AND VarianzaKM >= KMAlineamiento - 1000 THEN 'Ingreso por KM'
	ELSE 'No cumple por KM o Tiempo'
	END as EtiquetaDetallada
	INTO  #TABLA_APOYO
	FROM (SELECT *, 
	LAG(Apertura) OVER (PARTITION BY Bastidor ORDER BY Apertura asc) as AnteriorIngreso, --SACAMOS LA ENTRADA ANTERIOR A LA DE LA FILA
	LAG(KMS) OVER (PARTITION BY Bastidor ORDER BY Apertura asc) as AnteriorKM, --SACAMOS EL KM ANTERIOR AL DEL KM ACTUAL
	CASE 
	WHEN LAG(Apertura) OVER (PARTITION BY Bastidor ORDER BY Apertura asc) IS NULL THEN 'FALSE'
	ELSE 'TRUE'
	END as ValidoAnalisis,
	--EL ALINEAMIENTO QUE DICE FABRICA, CADA CUANTOS MESES DEBE ENTRAR
	CASE
	WHEN Marca = 'Audi' AND AñoModelo >=2000 THEN 12
	ELSE 10 
	END AS MesesAlineamiento,
	--EL ALINEAMIENTO QUE DICE FABRICA, CADA CUANTOS KM DEBE ENTRAR
	CASE
	WHEN AñoModelo IS NULL THEN NULL
	--WHEN Marca IN ('VW Pasajeros') AND Modelo LIKE '%Nivus%' AND AñoModelo = 2021 THEN 10000
	--WHEN Marca IN ('VW Pasajeros') AND Modelo LIKE '%Teramont%' AND AñoModelo = 2021 THEN 10000
	--WHEN Marca IN ('VW Pasajeros') AND Modelo LIKE '%Taos%' AND AñoModelo = 2021 THEN 10000
	--WHEN Marca IN ('VW Pasajeros') AND Modelo LIKE '%TCross 1.0 TSI%' AND AñoModelo = 2021 THEN 10000
	--WHEN Marca IN ('VW Pasajeros') AND Modelo LIKE '%Tiguan Allspace 2.0 TSI%' AND AñoModelo = 2021 THEN 10000
	--WHEN Marca IN ('VW Pasajeros') AND AñoModelo < 2010 THEN 5000
	--WHEN Marca IN ('VW Pasajeros') AND AñoModelo >= 2010 AND AñoModelo <=2021 THEN 7500
	--WHEN Marca IN ('VW Pasajeros') AND AñoModelo >= 2022 THEN 10000
	WHEN Marca = 'Audi' THEN 7500
	ELSE 7500
	END AS KMAlineamiento,
		
	--LA RESTA ENTRE ENTRADA ACTUAL Y ANTERIOR
	CASE
	WHEN LAG(Apertura) OVER (PARTITION BY Bastidor ORDER BY Apertura asc) IS NULL THEN NULL
	WHEN 
	CASE 
	WHEN LAG(Apertura) OVER (PARTITION BY Bastidor ORDER BY Apertura asc) IS NULL THEN 'FALSE'
	ELSE 'TRUE'
	END = 'TRUE' THEN DATEDIFF(DAY, LAG(Apertura) OVER (PARTITION BY Bastidor ORDER BY Apertura asc), Apertura)/30 --ESTA ES LA UNICA LINEA DE LOGICA, LO DE ATRAS ES SOLO VERIFICACION APTO O NO APTOP
	END as VarianzaMeses,
		
	CASE
	WHEN LAG(Apertura) OVER (PARTITION BY Bastidor ORDER BY Apertura asc) IS NULL THEN NULL
	WHEN 
	CASE 
	WHEN LAG(Apertura) OVER (PARTITION BY Bastidor ORDER BY Apertura asc) IS NULL THEN 'FALSE'
	ELSE 'TRUE'
	END = 'TRUE' THEN KMS - LAG(KMS) OVER (PARTITION BY Bastidor ORDER BY Apertura asc)  --ESTA ES LA UNICA LINEA DE LOGICA, LO DE ATRAS ES SOLO VERIFICACION APTO O NO APTOP
	END as VarianzaKM
	FROM #TABLA) AS SUBCONSULTA 


	---ETIQUETA MAS REPETIDA POR BASTIDOR
	
	SELECT * 
	INTO #ETIQUETA_REPETIDA
	FROM (
	SELECT *,
	ROW_NUMBER() OVER (PARTITION BY Bastidor ORDER BY Maximo desc) as Colu -- Aca es donde se enumera
	FROM (
	SELECT DISTINCT  Bastidor, EtiquetaDetallada,
	COUNT(EtiquetaDetallada) OVER (PARTITION BY Bastidor, EtiquetaDetallada) as Maximo	 -- Aca es donde se enumera cual es la etiqueta mas repetida
	FROM (
	SELECT * FROM #TABLA_APOYO ) as sub ) AS suba) as Suba2 WHERE Colu = 1  

	--SELECT * FROM #ETIQUETA_REPETIDA

	----------------------------------------------------------
	---ESTIMACIÓN DEL INGRESO
	----------------------------------------------------------
      
	SELECT a.*, b.EtiquetaDetallada as EtiquetaGeneral,
	CASE 
	WHEN b.EtiquetaDetallada = 'Ingreso por tiempo' OR b.EtiquetaDetallada = 'Ingreso por Tiempo y KM' THEN DATEADD(MONTH, 12, a.Apertura)
	WHEN b.EtiquetaDetallada = 'Ingreso por KM' THEN DATEADD(DAY, a.MesXKilometraje*30, a.Apertura)
	WHEN a.PromedioMeses IS NOT NULL AND b.EtiquetaDetallada = 'No cumple por KM o Tiempo' THEN DATEADD(DAY, a.PromedioMeses*30, a.Apertura) 
	WHEN a.PromedioMeses IS NULL AND b.EtiquetaDetallada = 'No cumple por KM o Tiempo' THEN DATEADD(DAY, 180, a.Apertura)
	END AS FechaPrediccion,
			
	ROW_NUMBER() OVER (PARTITION BY a.Bastidor ORDER BY a.Apertura DESC) as OrdenCitas
	INTO #BASE_VENTA_ACTIVA
	FROM (
	SELECT *, 
	KMAlineamiento/(PromedioKM/PromedioMeses) as MesXKilometraje
	FROM (
	SELECT *,
	COUNT(*) OVER (PARTITION BY Bastidor) as Ingresos,
	--ETIQUETADO DE ENTRADA A TIEMPO 
	CASE 
	WHEN VarianzaMeses = MesesAlineamiento AND VarianzaKM = KMAlineamiento THEN 'Ingreso por Tiempo y KM'
	WHEN Marca = 'Audi' AND VarianzaMeses <= MesesAlineamiento + 1 AND VarianzaMeses >= MesesAlineamiento - 1 THEN 'Ingreso por tiempo'
	WHEN VarianzaKM <= KMAlineamiento + 1000 AND VarianzaKM >= KMAlineamiento - 1000 THEN 'Ingreso por KM'
	ELSE 'No cumple por KM o Tiempo'
	END as EtiquetaDetallada,
	CASE 
	WHEN AVG(VarianzaMeses*1.0) OVER (PARTITION BY Bastidor) = 0 THEN 1
	ELSE AVG(VarianzaMeses*1.0) OVER (PARTITION BY Bastidor)
	END as PromedioMeses,
	CASE 
	WHEN AVG(VarianzaKM*1.0) OVER (PARTITION BY Bastidor) = 0 THEN 1
	ELSE AVG(VarianzaKM*1.0) OVER (PARTITION BY Bastidor)
	END as PromedioKM				
	FROM (SELECT *, 
	LAG(Apertura) OVER (PARTITION BY Bastidor ORDER BY Apertura asc) as AnteriorIngreso, --SACAMOS LA ENTRADA ANTERIOR A LA DE LA FILA
	LAG(KMS) OVER (PARTITION BY Bastidor ORDER BY Apertura asc) as AnteriorKM, --SACAMOS EL KM ANTERIOR AL DEL KM ACTUAL
	CASE 
	WHEN LAG(Apertura) OVER (PARTITION BY Bastidor ORDER BY Apertura asc) IS NULL THEN 'FALSE'
	ELSE 'TRUE'
	END as ValidoAnalisis,
	--EL ALINEAMIENTO QUE DICE FABRICA, CADA CUANTOS MESES DEBE ENTRAR
	CASE
	WHEN Marca = 'Audi' AND AñoModelo >=2000 THEN 12
	ELSE 10 
	END AS MesesAlineamiento,
	--EL ALINEAMIENTO QUE DICE FABRICA, CADA CUANTOS KM DEBE ENTRAR
	CASE
	WHEN AñoModelo IS NULL THEN NULL
	--WHEN Marca IN ('VW Pasajeros') AND Modelo LIKE '%Nivus%' AND AñoModelo = 2021 THEN 10000
	--WHEN Marca IN ('VW Pasajeros') AND Modelo LIKE '%Teramont%' AND AñoModelo = 2021 THEN 10000
	--WHEN Marca IN ('VW Pasajeros') AND Modelo LIKE '%Taos%' AND AñoModelo = 2021 THEN 10000
	--WHEN Marca IN ('VW Pasajeros') AND Modelo LIKE '%TCross 1.0 TSI%' AND AñoModelo = 2021 THEN 10000
	--WHEN Marca IN ('VW Pasajeros') AND Modelo LIKE '%Tiguan Allspace 2.0 TSI%' AND AñoModelo = 2021 THEN 10000
	--WHEN Marca IN ('VW Pasajeros') AND AñoModelo < 2010 THEN 5000
	--WHEN Marca IN ('VW Pasajeros') AND AñoModelo >= 2010 AND AñoModelo <=2021 THEN 7500
	--WHEN Marca IN ('VW Pasajeros') AND AñoModelo >= 2022 THEN 10000
	WHEN Marca = 'Audi' THEN 7500
	ELSE 7500
	END AS KMAlineamiento,
					
	--LA RESTA ENTRE ENTRADA ACTUAL Y ANTERIOR
	CASE
	WHEN LAG(Apertura) OVER (PARTITION BY Bastidor ORDER BY Apertura asc) IS NULL THEN NULL
	WHEN --ACA SOLO HACEMOS LA VERIFICACION SI EL CASO ES APTO PARA ANALISIS
		CASE 
			WHEN LAG(Apertura) OVER (PARTITION BY Bastidor ORDER BY Apertura asc) IS NULL THEN 'FALSE'
			ELSE 'TRUE'
		END = 'TRUE' THEN DATEDIFF(DAY, LAG(Apertura) OVER (PARTITION BY Bastidor ORDER BY Apertura asc), Apertura)/30 --ESTA ES LA UNICA LINEA DE LOGICA, LO DE ATRAS ES SOLO VERIFICACION APTO O NO APTOP
	END as VarianzaMeses,
					
	CASE
	WHEN LAG(Apertura) OVER (PARTITION BY Bastidor ORDER BY Apertura asc) IS NULL THEN NULL
	WHEN --ACA SOLO HACEMOS LA VERIFICACION SI EL CASO ES APTO PARA ANALISIS
		CASE 
			WHEN LAG(Apertura) OVER (PARTITION BY Bastidor ORDER BY Apertura asc) IS NULL THEN 'FALSE'
			ELSE 'TRUE'
		END = 'TRUE' THEN KMS - LAG(KMS) OVER (PARTITION BY Bastidor ORDER BY Apertura asc)  --ESTA ES LA UNICA LINEA DE LOGICA, LO DE ATRAS ES SOLO VERIFICACION APTO O NO APTOP
	END as VarianzaKM
	FROM #TABLA) AS SUBCONSULTA ) as b) AS a LEFT JOIN #ETIQUETA_REPETIDA b ON a.Bastidor = b.Bastidor 
		
    -- SELECT*FROM #TABLA WHERE BASTIDOR ='WAUZZZ8U0FR006052'
	--SELECT * FROM #BASE_VENTA_ACTIVA WHERE Bastidor = 'WAUZZZFY2N2117621'
	

	---------------------------------------------------------------------------
	---- BASE PARTE 1 - veh con 2 o más PREVENTIVOS y logica de comportamiento
	----------------------------------------------------------------------------
			
	--SELECT 
	--CASE 
	--WHEN DATEDIFF(MONTH,Apertura, CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, '2025-04-30') + 1, 0) AS DATE)) >= 0 AND DATEDIFF(MONTH,Apertura, CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, '2025-04-30') + 1, 0) AS DATE)) <= 7 THEN 'Recordatorio de Servicio'
	--WHEN DATEDIFF(MONTH,Apertura, CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, '2025-04-30') + 1, 0) AS DATE)) >= 8 AND DATEDIFF(MONTH,Apertura, CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, '2025-04-30') + 1, 0) AS DATE)) <= 14 THEN 'Recordatorio de Servicio'
	--WHEN DATEDIFF(MONTH,Apertura, CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, '2025-04-30') + 1, 0) AS DATE)) >= 15 AND DATEDIFF(MONTH,Apertura, CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, '2025-04-30') + 1, 0) AS DATE)) <= 24 THEN 'Recupero I'
	--WHEN DATEDIFF(MONTH,Apertura, CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, '2025-04-30') + 1, 0) AS DATE)) >= 25 THEN 'Recupero II'  -- AND Antiguedad <=8
	--ELSE 'Sin Etiquetar'
	--END Tipo_base,
	--Ingresos AS n_preventivos,
	--Marca, 
	--Modelo, 
	--Bastidor,
	--Matricula,
	--Apertura Ult_visita,
	--Taller Ult_Taller,
	--UsuarioCreador Ult_UsuarioCreador,
	--Asesor,
	--'' TipoDocPropietario,
	--'' DocumentoPropietario,
	--'' Propietario,
	--TipoDocDepositario,
	--CAST(DocumentoDepositario AS TEXT) AS DocumentoDepositario, 
	--Depositario, 
	--'' FechaDespacho,
	--'' DealerDespacho,
	--AñoModelo
	--INTO #BASE_PARTE1
	--FROM #BASE_VENTA_ACTIVA 
	--WHERE 
	--OrdenCitas = 1 
	--AND Ingresos >1
	--AND EtiquetaGeneral IN ('Ingreso por KM','Ingreso por tiempo','Ingreso por Tiempo y KM')
	--AND LEN (Bastidor) >=7
	--AND (
	--FechaPrediccion LIKE '2025-02%'
	--OR  FechaPrediccion LIKE '2025-03%'
	--OR  FechaPrediccion LIKE '2025-04%'
	--OR  FechaPrediccion LIKE '2025-05%')-- MES DE LA BOLSA + 2 meses de margen inferior
	
	---------------------------------------------------------------------------
	---- BASE PARTE 1 - VEHICULOS AUDI PLUS
	----------------------------------------------------------------------------
	
	
	;WITH UltimaFila AS (
		SELECT
			VIN,
			FechaInicio_Audi_Plus  AS FechaInicio,
			FechaFin_Audi_Plus     AS FechaFin,
			ROW_NUMBER() OVER (
				PARTITION BY VIN
				ORDER BY FechaInicio_Audi_Plus DESC 
			) AS rn
		FROM SIMA_AUDI_PLUS
	)

	SELECT
		VIN,
		FechaInicio,
		FechaFin
	INTO #AUDI_PLUS
	FROM UltimaFila
	WHERE rn = 1;


	-- SE VENCE EL PRÓXIMO MES
	SELECT 
		VIN
		,FechaInicio
		,FechaFin
		,DATEDIFF(YEAR,FechaInicio,FechaFin) AS AniosContrato
		,DATEDIFF(MONTH,CAST('2025-06-01' AS DATE) , CAST(FechaFin AS DATE) ) AS MesesRestantesVigencia
	INTO #VEHICULOS_AUDI_PLUS_POR_VENCER
	FROM #AUDI_PLUS AP
	WHERE 
		DATEDIFF(MONTH,GETDATE(),FechaFin) > 0 AND
		DATEDIFF(MONTH,CAST('2025-06-01' AS DATE) , CAST(FechaFin AS DATE) ) <= 1
	ORDER BY FechaFin ASC



	-------------------------------------------------------------------------
	-- BASE PASO 2 - ULTIMA VISITA PREVENTIVO
	--------------------------------------------------------------------------
	
	SELECT Bastidor,MAX(Apertura) Ult_visita, COUNT( Orden) n_preventivos 
	INTO #Ult_PREVENTIVO
	FROM #TABLA
	GROUP BY Bastidor

	SELECT
	AP.VIN
	,AP.FechaInicio AS FechaInicioContratoAudiPlus
	,AP.FechaFin AS FechaVigenciaContratoAudiPlus
	,a.n_preventivos
	,t.* 
	,CASE WHEN 
	DATEDIFF(MONTH,t.Apertura, CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, '2025-04-30') + 1, 0) AS DATE)) >= 10 
	AND DATEDIFF(MONTH,t.Apertura, CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, '2025-04-30') + 1, 0) AS DATE)) <= 25 THEN 'TRUE' ELSE 'FALSE'
	END Caso
	INTO #BASE_BOLSA_VA_INTERM_1
	FROM #VEHICULOS_AUDI_PLUS_POR_VENCER AP 
	LEFT JOIN #Ult_PREVENTIVO a ON a.Bastidor=AP.VIN
	LEFT JOIN #TABLA t ON AP.VIN=t.Bastidor AND a.Ult_visita=t.Apertura


	-----------------------------------------
	--- BOLSA DE VENTA ACTIVA AUDI PLUS PRÓXIMO A VENCER MES SIGUIENTE, SIN CITAS AGENDADAS
	-----------------------------------------

	SELECT 
		FechaInicioContratoAudiPlus,
		FechaVigenciaContratoAudiPlus,
	CASE 
		WHEN DATEDIFF(MONTH,Apertura, CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, '2025-06-30') + 1, 0) AS DATE)) >= 0 AND DATEDIFF(MONTH,Apertura, CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, '2025-06-30') + 1, 0) AS DATE)) <= 7 THEN 'Recordatorio de Servicio'
		WHEN DATEDIFF(MONTH,Apertura, CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, '2025-06-30') + 1, 0) AS DATE)) >= 8 AND DATEDIFF(MONTH,Apertura, CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, '2025-06-30') + 1, 0) AS DATE)) <= 14 THEN 'Recordatorio de Servicio'
		WHEN DATEDIFF(MONTH,Apertura, CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, '2025-06-30') + 1, 0) AS DATE)) >= 15 AND DATEDIFF(MONTH,Apertura, CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, '2025-06-30') + 1, 0) AS DATE)) <= 24 THEN 'Recupero I'
		WHEN DATEDIFF(MONTH,Apertura, CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, '2025-06-30') + 1, 0) AS DATE)) >= 25 THEN 'Recupero II'  -- AND Antiguedad <=8
		ELSE 'Sin Etiquetar'
	END AS TipoVA,
	CASE
		WHEN Taller IN ('Audi Derby','Ducati','TALLER AUDI DERBY','TALLER DUCATI','FLOTAS AUDI') THEN 'TALLER AUDI DERBY'
		WHEN Taller IN ('Audi Surquillo','TALLER AUDI SURQUILLO') THEN 'TALLER AUDI SURQUILLO'
		ELSE Taller
	END Ult_Taller,
	UsuarioCreador AS Ult_UsuarioCreador,
	Asesor AS Ult_Asesor,
	Marca,
	Modelo,
	Bastidor,
	VIN AS VIN_AudiPlus,
	Matricula,
	AñoModelo,
	CASE WHEN YEAR(FechaVenta_consolidado)=1900 THEN NULL ELSE FechaVenta_consolidado END FechaDespacho,
	Apertura AS Ult_visita,
	n_preventivos,
	DATEDIFF(MONTH,Apertura, CAST(DATEADD(MONTH, DATEDIFF(MONTH, 0, '2025-06-30') + 1, 0) AS DATE)) Ult_visita_meses,  --- revisar esto si la bolsa se genera antes del Mes-Bolsa !!!
	TipoDocDepositario, 
	DocumentoDepositario,
	Depositario,
	TipoDocPropietario,
	DocumentoPropietario,
	Propietario
	INTO #BASE_BOLSA_VA_INTERM_2
	FROM #BASE_BOLSA_VA_INTERM_1
	WHERE VIN NOT IN (SELECT Bastidor FROM #BASE_QUITAR) 

	SELECT
		CASE 
			WHEN Marca IN ('AUDI') AND Ult_Taller IN ('TALLER AUDI DERBY') AND  Ult_visita_meses >= 4 AND Ult_visita_meses <= 21  THEN 'BDC'
			WHEN Marca IN ('AUDI') AND Ult_Taller IN ('TALLER AUDI SURQUILLO') AND Ult_visita_meses >= 4 AND Ult_visita_meses <= 16 THEN 'BDC'
			WHEN Ult_visita_meses >= 3 AND Ult_Taller IN ('TALLER ESSA SURQUILLO') THEN 'BDC'
			ELSE 'TALLER'
		END Asignación,*
	INTO #BASE_BOLSA_VA_INTERM_3
	FROM #BASE_BOLSA_VA_INTERM_2

	-----------------------------------------
	--- CASTEO DE CAMPOS
	-----------------------------------------
	
	SELECT DISTINCT 	
	CAST(Asignación AS VARCHAR(MAX)) Asignación,
	CAST(TipoVA AS VARCHAR(MAX)) TipoVA,
	CAST(Ult_Taller AS VARCHAR(MAX)) Ult_Taller,
	CAST(Ult_UsuarioCreador AS VARCHAR(MAX)) Ult_UsuarioCreador,
	CAST(Ult_Asesor AS VARCHAR(MAX)) Ult_Asesor,
	CAST(Marca AS VARCHAR(MAX)) Marca,
	CAST(Modelo AS VARCHAR(MAX)) Modelo,
	CAST(VIN_AudiPlus AS VARCHAR(MAX)) Bastidor,
	CAST(Matricula AS VARCHAR(MAX)) Matricula,
	CAST(AñoModelo AS VARCHAR(MAX)) AñoModelo,
	Ult_visita,
	FechaInicioContratoAudiPlus,
	FechaVigenciaContratoAudiPlus,
	n_preventivos,
	Ult_visita_meses,
	CAST(TipoDocPropietario AS VARCHAR(MAX)) TipoDocCliente, -- El cliente es el propietario
	CASE 
	WHEN TipoDocPropietario='DNI' THEN '01'
	WHEN TipoDocPropietario='RUC' THEN '06'
	WHEN TipoDocPropietario='Pasaporte' THEN '07'
	WHEN TipoDocPropietario='Carnet extranjería' THEN '04'
	WHEN TipoDocPropietario='Cédula Diplomática' THEN '20'
	ELSE '00'
	END CodTipoSIMA,
	CAST(DocumentoPropietario AS VARCHAR(MAX)) DocumentoCliente,
	CAST(Propietario AS VARCHAR(MAX)) Cliente
	INTO #BASE_BOLSA_VA_INTERM_4
	FROM #BASE_BOLSA_VA_INTERM_3

	SELECT 
	Asignación,
	TipoVA,
	Ult_Taller,
	Ult_UsuarioCreador,
	Ult_Asesor,
	Marca,
	Modelo,
	Bastidor,
	Matricula,
	AñoModelo,
	Ult_visita,
	FechaInicioContratoAudiPlus,
	FechaVigenciaContratoAudiPlus,
	n_preventivos,
	Ult_visita_meses,
	TipoDocCliente,
	CodTipoSIMA,
	DocumentoCliente,
	Cliente,
	CASE
		WHEN DocumentoCliente IS NULL THEN NULL
		ELSE CONCAT(CodTipoSIMA,'_',DocumentoCliente)
	END AS Partynumber
	INTO #BASE_BOLSA_VA_INTERM_5
	fROM #BASE_BOLSA_VA_INTERM_4


	-----------------------------------------
	-- CRUCE DE BOLSA DE VA Y ORACLE 
	-----------------------------------------

	SELECT DISTINCT 
	'Euroshop' Empresa,
	a.Asignación,
	CASE 
	WHEN  a.Bastidor=q.AssetNumber AND a.Partynumber = r.IdentificadorClientes AND a.Matricula=q.XUM_Placa_c AND a.Marca IN ('VW Pasajeros','VW Comerciales','AUDI') THEN 'TRUE' ELSE 'FALSE' END Migrado_oracle,
	CASE 
	WHEN  a.Bastidor=q.AssetNumber AND a.Partynumber = r.IdentificadorClientes AND a.Matricula=q.XUM_Placa_c AND a.Marca IN ('VW Pasajeros','VW Comerciales','AUDI')  THEN 'SR ORACLE' ELSE 'DRIVE' END Distribucion,
	a.TipoVA,
	a.Ult_Taller,
	a.Ult_UsuarioCreador,
	a.Ult_Asesor,
	a.Marca,
	CONVERT(DATE,a.FechaVigenciaContratoAudiPlus) FechaVigenciaContratoAudiPlus,
	CASE WHEN a.Marca IN ('VW Pasajeros','VW Comerciales') THEN 'VOLKSWAGEN' ELSE a.Marca  END Marca_Agrupada,
	a.Modelo,
	a.Bastidor,
	a.Matricula,
	a.AñoModelo,
    CONVERT(DATE,a.Ult_visita) Ult_visita,
	a.n_preventivos,
	a.Ult_visita_meses,
	a.TipoDocCliente,
	a.CodTipoSIMA,
	a.DocumentoCliente,
	a.Cliente,
	q.AssetNumber AS Asset_Oracle,
	r.IdentificadorClientes AS Partynumber_Oracle,
	q.XUM_Placa_c Matricula_Oracle
	INTO  #BOLSA_VA_AUDI_PLUS
	FROM #BASE_BOLSA_VA_INTERM_5 a 
	LEFT JOIN #BASE_BOLSA_VA_INTERM_1 p ON a.Bastidor=p.VIN
	LEFT JOIN (SELECT DISTINCT AssetNumber, XUM_Placa_c FROM STG_ClienteUnico..Carga_Asset_Diario ) q ON a.Bastidor=q.AssetNumber
	LEFT JOIN (SELECT DISTINCT IdentificadorClientes FROM STG_ClienteUnico..Carga_Account_Diario) r ON a.Partynumber = r.IdentificadorClientes
	WHERE a.DocumentoCliente NOT IN ('20520549740') -- CLIENTES QUE SON EMPRESAS DEL GRUPO

	--- ORDEN DE CREACIÓN DE SRs POR PRIOIZACIÓN
	SELECT
	CASE 
	WHEN  Marca ='Audi' AND TipoVA ='Recordatorio de 1er Mantenimiento' AND Ult_visita_meses =12 THEN 1
	WHEN  Marca ='Audi' AND TipoVA ='Recordatorio de 1er Mantenimiento' AND Ult_visita_meses =11 THEN 2
	WHEN  Marca ='Audi' AND TipoVA ='Recordatorio de Servicio' AND Ult_visita_meses =12 THEN 3
	WHEN  Marca ='Audi' AND TipoVA ='Recordatorio de Servicio' AND Ult_visita_meses =11 AND n_preventivos = 2 THEN 4
	WHEN  Marca ='Audi' AND TipoVA ='Recordatorio de Servicio' AND Ult_visita_meses =10 AND n_preventivos = 2 THEN 5
	WHEN  Marca ='Audi' AND TipoVA ='Recordatorio de Servicio' AND Ult_visita_meses =9 AND n_preventivos = 2 THEN 6
	WHEN  Marca ='Audi' AND TipoVA ='Recordatorio de Servicio' AND Ult_visita_meses =11 AND n_preventivos <> 2 THEN 7
	WHEN  Marca ='Audi' AND TipoVA ='Recordatorio de 1er Mantenimiento' AND Ult_visita_meses =13 THEN 8
	WHEN  Marca ='Audi' AND TipoVA ='Recordatorio de Servicio' AND Ult_visita_meses =13 THEN 9
	WHEN  Marca ='Audi' AND TipoVA ='Recordatorio de Servicio' AND Ult_visita_meses =14 THEN 10
	WHEN  Marca ='Audi' AND TipoVA ='Recordatorio de Servicio' AND Ult_visita_meses =10 AND n_preventivos <> 2 THEN 11
	WHEN  Marca ='Audi' AND TipoVA ='Recordatorio de Servicio' AND Ult_visita_meses =9 AND n_preventivos <> 2 THEN 12
	WHEN  Marca ='Audi' AND TipoVA ='Recordatorio de Servicio' AND Ult_visita_meses =8 THEN 13
	WHEN  Marca ='Audi' AND TipoVA ='Recordatorio de Servicio' AND Ult_visita_meses =7 THEN 14
	WHEN  Marca ='Audi' AND TipoVA ='Recordatorio de Servicio' AND Ult_visita_meses =6 THEN 15
	WHEN  Marca ='Audi' AND TipoVA ='Recordatorio de Servicio' AND Ult_visita_meses =5 THEN 16
	WHEN  Marca ='Audi' AND TipoVA ='Recordatorio de Servicio' AND Ult_visita_meses =4 THEN 17
	WHEN  Marca ='Audi' AND TipoVA ='Recupero I' THEN 18
	WHEN  Marca ='Audi' AND TipoVA ='Recupero II' THEN 19 

	ELSE 9999
	END Orden_Creacion_SR,
	*
	INTO BOLSA_VA_AUDI_PLUS_JULIO_CM  -- FOTOGRAFÍA JULIO AUDI PLUS
	FROM #BOLSA_VA_AUDI_PLUS