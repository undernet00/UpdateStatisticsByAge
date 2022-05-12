USE [DBTools]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

CREATE TABLE [mon].[LogMonitoreo](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[Mensaje] [varchar](max) NULL,
	[SQL] [varchar](max) NULL,
	[Fecha] [smalldatetime] NULL,
	[InvocadoDesde] [varchar](256) NULL,
	[Error] [char](1) NULL,
	[ErrorNumero] [int] NULL
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO
