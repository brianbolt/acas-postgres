db_exists(){
	DB_NAME=$1
	DBEXISTS=`gosu postgres postgres --single -jE <<- EOSQL
	   SELECT 1 FROM pg_database WHERE datname='$DB_NAME'
	EOSQL`
	if [[ $DBEXISTS =~ "?column? = \"1\"" ]]; then
		echo 1
	else
		echo 0
	fi
}
create_db(){
	DB_NAME=$1
	gosu postgres postgres --single -jE <<- EOSQL
	   CREATE DATABASE $DB_NAME;
	EOSQL
}
user_exists(){
	USER=$1
	USEREXISTS=`gosu postgres postgres --single -jE <<- EOSQL
		SELECT 1 FROM pg_catalog.pg_user WHERE usename = '$USER'
	EOSQL`
	if [[ $USEREXISTS =~ "?column? = \"1\"" ]]; then
		echo 1
	else
		echo 0
	fi
}
create_or_alter_user(){
	USER=$1
	PASSWORD=$2
	PASSWORD=$2
	gosu postgres postgres --single -jE $DB_NAME <<- EOSQL
	   CREATE USER $USER WITH PASSWORD '$PASSWORD'
	EOSQL
}
grant(){
	grant=$1
	gosu postgres postgres --single -jE $DB_NAME <<- EOSQL
		 grant $grant
	EOSQL
}
alter(){
	ALTER=$1
	gosu postgres postgres --single -jE $DB_NAME <<- EOSQL
		 alter $ALTER
	EOSQL
}
schema_exists(){
	SCHEMA=$1
	SCHEMAEXISTS=`gosu postgres postgres --single -jE $DB_NAME <<- EOSQL
		SELECT 1 FROM information_schema.schemata WHERE schema_name = '$SCHEMA'
	EOSQL`
	if [[ $SCHEMA =~ "?column? = \"1\"" ]]; then
		echo 1
	else
		echo 0
	fi
}
create_schema(){
	SCHEMA=$1
	AUTHORIZATION=$2
	gosu postgres postgres --single -jE $DB_NAME <<- EOSQL
	   CREATE SCHEMA $SCHEMA AUTHORIZATION $AUTHORIZATION
	EOSQL
}
run(){
	run=$1
	gosu postgres postgres --single -jE $DB_NAME <<- EOSQL
		$run
	EOSQL
}

echo "******CHECKING IF $DB_NAME DATABASE EXISTS******"
DBEXISTS=$(db_exists $DB_NAME)
if [[ $DBEXISTS == "1" ]]; then
	echo true
	echo "$DB_NAME DATABASE ALREADY EXISTS"
else
	echo false
	echo "******CREATING $DB_NAME DATABASE******"
	create_db $DB_NAME
	echo
fi

echo "******CHECKING IF $DB_USER USER EXISTS******"
USEREXISTS=$(user_exists $DB_USER)
if [[ $USEREXISTS == "1" ]]; then
	echo true
	echo "******$DB_USER USER ALREADY EXISTS******"
	OP=ALTER
else
	echo false
	OP=CREATE
fi
echo "******${OP}ing $DB_USER USER******"
create_or_alter_user $DB_USER $DB_PASSWORD $OP
grant "ALL PRIVILEGES ON DATABASE $DB_NAME to $DB_USER"
echo

echo "******CHECKING IF ACAS NEEDED******"
ACAS=$ACAS
ACAS=${ACAS:-false}
if [[ $ACAS == "true" ]]; then
	echo true
	echo "******CHECKING IF $ACAS_USERNAME USER EXISTS******"
	USEREXISTS=$(user_exists $ACAS_USERNAME)
	if [[ $USEREXISTS == "1" ]]; then
		echo true
		echo "******$ACAS_USERNAME USER ALREADY EXISTS******"
		OP=ALTER
	else
		echo false
		OP=CREATE
	fi
	echo "******${OP}ing $ACAS_USERNAME USER******"
	create_or_alter_user $ACAS_USERNAME $ACAS_PASSWORD $OP
	echo

	echo "******CHECKING IF $ACAS_SCHEMA SCHEMA EXISTS******"
	SCHEMAEXISTS=$(schema_exists $ACAS_SCHEMA)
	if [[ $SCHEMAEXISTS == "1" ]]; then
		echo true
		echo "******$ACAS_SCHEMA SCHEMA ALREADY EXISTS******"
	else
		echo false
		echo "******CREATING $ACAS_SCHEMA schema******"
		create_schema $ACAS_SCHEMA $ACAS_USERNAME
		echo
	fi

fi

echo "******CHECKING IF CMPDREG NEEDED******"
CMPDREG=$CMPDREG
CMPDREG=${CMPDREG:-false}
if [[ $CMPDREG == "true" ]]; then
	echo true
	echo "******CHECKING IF $CMPDREG_ADMIN_USERNAME USER EXISTS******"
	USEREXISTS=$(user_exists $CMPDREG_ADMIN_USERNAME)
	if [[ $USEREXISTS == "1" ]]; then
		echo true
		echo "******$CMPDREG_ADMIN_USERNAME USER ALREADY EXISTS******"
		OP=ALTER
	else
		echo false
		OP=CREATE
	fi
	echo "******${OP}ing $CMPDREG_ADMIN_USERNAME USER******"
	create_or_alter_user $CMPDREG_ADMIN_USERNAME $CMPDREG_ADMIN_PASSWORD $OP
	echo

	echo "******CHECKING IF $CMPDREG_USER_USERNAME USER EXISTS******"
	USEREXISTS=$(user_exists $CMPDREG_USER_USERNAME)
	if [[ $USEREXISTS == "1" ]]; then
		echo true
		echo "******$CMPDREG_USER_USERNAME USER ALREADY EXISTS******"
		OP=ALTER
	else
		echo false
		OP=ALTER
	fi
	echo "******${OP}ing $CMPDREG_USER_USERNAME USER******"
	create_or_alter_user $CMPDREG_USER_USERNAME $CMPDREG_USER_PASSWORD $OP
	echo

	echo "******CHECKING IF $CMPDREG_SCHEMA SCHEMA EXISTS******"
	SCHEMAEXISTS=$(schema_exists $CMPDREG_SCHEMA)
	if [[ $SCHEMAEXISTS == "1" ]]; then
		echo true
		echo "******$CMPDREG_SCHEMA SCHEMA ALREADY EXISTS******"
	else
		echo false
		echo "******CREATING $CMPDREG_SCHEMA schema******"
		create_schema $CMPDREG_SCHEMA $CMPDREG_ADMIN_USERNAME
		echo
	fi
	alter "ROLE $CMPDREG_ADMIN_USERNAME SET search_path = $CMPDREG_SCHEMA"
	grant "CREATE ON database $DB_NAME to $CMPDREG_ADMIN_USERNAME"
	grant "USAGE ON SCHEMA $CMPDREG_SCHEMA to $CMPDREG_USER_USERNAME"
	run "CREATE EXTENSION plperl"
else
	echo false
fi

echo "******CHECKING IF SEURAT NEEDED******"
SEURAT=$SEURAT
SEURAT=${SEURAT:-false}
if [[ $SEURAT == "true" ]]; then
	echo true
	echo "******CHECKING IF $SEURAT_USERNAME USER EXISTS******"
	USEREXISTS=$(user_exists $SEURAT_USERNAME)
	if [[ $USEREXISTS == "1" ]]; then
		echo true
		echo "******$SEURAT_USERNAME USER ALREADY EXISTS******"
		OP=ALTER
	else
		echo false
		OP=CREATE
	fi
	echo "******CREATING $SEURAT_USERNAME USER******"
	create_or_alter_user $SEURAT_USERNAME $SEURAT_PASSWORD $OP
	searchPath=()
	searchPath+=($SEURAT_SCHEMA)
	if [[ $ACAS == "true" ]]; then
		searchPath+=($ACAS_SCHEMA)
		grant "USAGE ON SCHEMA $ACAS_SCHEMA to seurat"
		grant "SELECT ON ALL TABLES in SCHEMA $ACAS_SCHEMA to seurat"
	fi
	if [[ $CMPDREG == "true" ]]; then
		searchPath+=($CMPDREG_SCHEMA)
		grant "USAGE ON SCHEMA $CMPDREG_SCHEMA to seurat"
		grant "SELECT ON ALL TABLES in SCHEMA $CMPDREG_SCHEMA to seurat"
	fi
	searchPath=$(IFS=,; echo "${searchPath[*]}")
	alter "USER $SEURAT_USERNAME SET search_path to $searchPath"
	echo "******CHECKING IF $SEURAT_SCHEMA SCHEMA EXISTS******"
	SCHEMAEXISTS=$(schema_exists $SEURAT_SCHEMA)
	if [[ $SCHEMAEXISTS == "1" ]]; then
		echo true
		echo "******$SEURAT_SCHEMA SCHEMA ALREADY EXISTS******"
	else
		echo false
		echo "******CREATING $SEURAT_SCHEMA schema******"
		create_schema $SEURAT_SCHEMA $SEURAT_USERNAME
		echo
	fi
fi
