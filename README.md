# AdventureWorksDW2017Big
The purpose of this project is to have scripts that can enlarge the tables in the Microsoft AdventureWorksDW2017 database.

By default dbo.FactInternetSales contains 60.398 rows which is not much if you want to test performance with Analysis Services and Power BI Desktop.

This first version of the script made here duplicates the original records in dbo.FactInternetSales a number of times to reach the desired number of records.

##Prerequisites
Restore a copy of the original AdventureWorksDW2017 database available [here](https://github.com/microsoft/sql-server-samples/tree/master/samples/databases/adventure-works).

##Scripts to enlarge the database
###001-ModifyDatabase
###002-spGenerateCalendar
###100-IncreaseFactInternetSales
