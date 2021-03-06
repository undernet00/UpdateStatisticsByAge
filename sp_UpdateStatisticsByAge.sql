USE [DBTools]
GO
 
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

-- =============================================
-- Author:		Martìn Rivero
-- Create date: 16/01/2022
-- Description:	Allows index and columns statistics. 
--				Based on a fixed time windows.  
-- =============================================
--EXEC DBTools.dbo.[sp_UpdateStatisticsByAge] 'Mosca', 7
ALTER PROCEDURE [dbo].[sp_UpdateStatisticsByAge] @Base AS VARCHAR(256)
	,@DiasDeAntiguedad AS INT
AS
BEGIN
	SET NOCOUNT ON;

	EXEC (
		'USE ' + @Base + ';
		IF OBJECT_ID(N''tempdb..##StatsToUpdate'') IS NOT NULL 
		DROP TABLE ##StatsToUpdate


		SELECT sp.stats_id, 
		   stat.name, 
		   STATS_DATE(t.object_id, stat.stats_id) AS last_updated  ,
		   DB_NAME() [Base],
		   s.name [Esquema],
		   Object_Name(stat.object_id) [Tabla]
		INTO ##StatsToUpdate
		FROM sys.stats AS stat 
			CROSS APPLY sys.dm_db_stats_properties(stat.object_id, stat.stats_id) AS sp
			INNER JOIN sys.tables t on stat.object_id = t.object_id
			INNER JOIN sys.schemas s on t.schema_id = s.schema_id
		
		WHERE stat.object_id = OBJECT_ID(s.name + ''.'' + Object_Name(stat.object_id))
			and last_updated < getdate()- ' + @DiasDeAntiguedad + ' ORDER BY 3;'
			)

	SELECT *
	FROM ##StatsToUpdate
	ORDER BY 3

	DECLARE @StatName VARCHAR(1024)
	DECLARE @SQL VARCHAR(1024)
	DECLARE @BaseDatos VARCHAR(1024)
	DECLARE @Esquema VARCHAR(1024)
	DECLARE @Tabla VARCHAR(1024)

	INSERT INTO DBTools.mon.LogMonitoreo (
		Mensaje
		,[SQL]
		,Fecha
		,InvocadoDesde
		,Error
		,ErrorNumero
		)
	VALUES (
		'Iniciando mantenimiento de Estadísticas en base ' + @BaseDatos + ' con ' + CONVERT(VARCHAR, (
				SELECT COUNT(*)
				FROM ##StatsToUpdate
				)) + ' pendientes de actualización.'
		,@SQL
		,GETDATE()
		,(
			SELECT OBJECT_NAME(@@PROCID)
			)
		,'N'
		,NULL
		)

	WHILE (
			SELECT COUNT(*)
			FROM ##StatsToUpdate
			) > 0
	BEGIN
		SELECT TOP 1 @StatName = name
			,@BaseDatos = Base
			,@Esquema = Esquema
			,@Tabla = Tabla
		FROM ##StatsToUpdate
		ORDER BY 3

		SELECT @SQL = 'UPDATE STATISTICS ' + @BaseDatos + '.' + @Esquema + '.' + @Tabla + ' [' + @StatName + '] WITH FULLSCAN;'

		INSERT INTO DBTools.mon.LogMonitoreo (
			Mensaje
			,[SQL]
			,Fecha
			,InvocadoDesde
			,Error
			,ErrorNumero
			)
		VALUES (
			'Iniciando mantenimiento de Estadística ' + @StatName + '.'
			,@SQL
			,GETDATE()
			,(
				SELECT OBJECT_NAME(@@PROCID)
				)
			,'N'
			,NULL
			)

		BEGIN TRY
			EXEC (@SQL)

			--SELECT @SQL
			INSERT INTO DBTools.mon.LogMonitoreo (
				Mensaje
				,[SQL]
				,Fecha
				,InvocadoDesde
				,Error
				,ErrorNumero
				)
			VALUES (
				'Finalizado mantenimiento de Estadística ' + @StatName + '.'
				,@SQL
				,GETDATE()
				,(
					SELECT OBJECT_NAME(@@PROCID)
					)
				,'N'
				,NULL
				)
		END TRY

		BEGIN CATCH
			INSERT INTO DBTools.mon.LogMonitoreo (
				Mensaje
				,[SQL]
				,Fecha
				,InvocadoDesde
				,Error
				,ErrorNumero
				)
			VALUES (
				'Error al actualizar Estadística ' + @StatName + '.'
				,@SQL
				,GETDATE()
				,(
					SELECT OBJECT_NAME(@@PROCID)
					)
				,'S'
				,ERROR_NUMBER()
				)
		END CATCH

		DELETE
		FROM ##StatsToUpdate
		WHERE Base = @BaseDatos
			AND Esquema = @Esquema
			AND Tabla = @Tabla
			AND name = @StatName
	END

	INSERT INTO DBTools.mon.LogMonitoreo (
		Mensaje
		,[SQL]
		,Fecha
		,InvocadoDesde
		,Error
		,ErrorNumero
		)
	VALUES (
		'Fin de mantenimiento de Estadísticas en base ' + + ' .'
		,@SQL
		,GETDATE()
		,(
			SELECT OBJECT_NAME(@@PROCID)
			)
		,'N'
		,NULL
		)

	DROP TABLE ##StatsToUpdate
END