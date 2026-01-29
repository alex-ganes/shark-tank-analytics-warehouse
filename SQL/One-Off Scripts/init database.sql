-- create database
IF DB_ID('SharkTankDWH') IS NULL
BEGIN
    CREATE DATABASE SharkTankDWH;
END;
GO

USE SharkTankDWH;
GO

-- create schemas
IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'stage')
    EXEC('CREATE SCHEMA stage');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'dwh')
    EXEC('CREATE SCHEMA dwh');
GO

IF NOT EXISTS (SELECT 1 FROM sys.schemas WHERE name = 'analytics')
    EXEC('CREATE SCHEMA analytics');
GO