#!/bin/bash

# Wait 60 seconds for SQL Server to start up by ensuring that 
# calling SQLCMD does not return an error code, which will ensure that sqlcmd is accessible
# and that system and user databases return "0" which means all databases are in an "online" state
# https://docs.microsoft.com/en-us/sql/relational-databases/system-catalog-views/sys-databases-transact-sql?view=sql-server-2017 

DBSTATUS=1
ERRCODE=1
i=0

while [[ $DBSTATUS -ne 0 ]] && [[ $i -lt 60 ]] && [[ $ERRCODE -ne 0 ]]; do
	i=$i+1
	DBSTATUS=$(/opt/mssql-tools18/bin/sqlcmd -h -1 -t 1 -U sa -P $SA_PASSWORD -No -Q "SET NOCOUNT ON; Select SUM(state) from sys.databases")
	ERRCODE=$?
	sleep 1
done

if [ $DBSTATUS -ne 0 ] OR [ $ERRCODE -ne 0 ]; then 
	echo "SQL Server took more than 60 seconds to start up or one or more databases are not in an ONLINE state"
	exit 1
fi

# Run the setup script to create the DB and the schema in the DB
/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P $SA_PASSWORD -d master -i setup.sql

# Check if the database exists
DBNAME="ferah"
EXIST=$(/opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P $SA_PASSWORD -d master -h -1 -W -No -Q "SET NOCOUNT ON; SELECT COUNT(*) FROM sys.databases WHERE name = '$DBNAME'")

if [[ $EXIST -eq 1 ]]; then
    # Backup the database
    /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P $SA_PASSWORD -No -No -Q "BACKUP DATABASE $DBNAME TO DISK = N'/var/opt/mssql/data/backup.bak' WITH NOFORMAT, NOINIT, NAME = '$DBNAME', SKIP, NOREWIND, NOUNLOAD, STATS = 10"

else
    # Create and restore the database
    /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P $SA_PASSWORD -No -Q "CREATE DATABASE $DBNAME"
    /opt/mssql-tools18/bin/sqlcmd -S localhost -U sa -P $SA_PASSWORD -No -Q "RESTORE DATABASE $DBNAME FROM DISK = N'/var/opt/mssql/data/backup.bak' WITH FILE = 1, MOVE '$DBNAME' TO '/var/opt/mssql/data/$DBNAME.mdf', MOVE '$DBNAME' TO '/var/opt/mssql/data/$DBNAME.ldf', NOUNLOAD, REPLACE, STATS = 10"
fi


