#!/bin/bash
# Only mysql is supported at the moment.
# using ssh port forwarding, remember to launch first
# - $ ssh host-that-can-access-mysql -L 13306:mysql-real-host:3306 -v -N
# in another shell, and set REMOTE_DB_HOST to "localhost" and "REMOTE_DB_PORT" to "13306"
set -e

# ## Set these variables either here or in the script including this one
# REMOTE_DB_HOST="mysql-remote-host"
# REMOTE_DB_PORT="3306"
# REMOTE_DB_USER="remote_db_user"
# REMOTE_DB_PASSWORD="remote_db_password"
# REMOTE_DB_SCHEMA="schema"
# 
# LOCAL_DB_HOST="localhost"
# LOCAL_DB_PORT="3306"
# LOCAL_DB_USER="local_user"
# LOCAL_DB_PASSWORD="local_password"
# LOCAL_DB_SCHEMA="schema"
OTHER_DATABASE_CONNECTION="-h $REMOTE_DB_HOST --port=$REMOTE_DB_PORT --protocol=TCP -u$REMOTE_DB_USER -p$REMOTE_DB_PASSWORD $REMOTE_DB_SCHEMA"
MY_DATABASE_CONNECTION="-h $LOCAL_DB_HOST --port=$LOCAL_DB_PORT -u$LOCAL_DB_USER -p$LOCAL_DB_PASSWORD $LOCAL_DB_SCHEMA"

# --add-drop-table means we want to destroy and recreate our local database. Remove it if you just want to append data.
EXPORT_DROPTABLE_OPTS="--add-drop-table"
EXPORT_NODROPTABLE_OPTS="--skip-add-drop-table --no-create-info --insert-ignore"
EXPORT_COMMON_OPTS="--skip-add-locks --complete-insert --skip-comments $EXPORT_CUSTOM_OPTS"

function importTable() {
  TABLE="$1"
  CONDITION="$2"
  exportToSqlCommands "$TABLE" "$CONDITION" | exportToFile "$TABLE" | exportToLocalMysql
}

function exportToSqlCommands() {
  TABLE="$1"
  CONDITION="$2"
  printf "\timport table %-30s" "$TABLE" >&2
  mysqldump $OTHER_DATABASE_CONNECTION $EXPORT_OPTS $EXPORT_COMMON_OPTS "$TABLE" -w "$CONDITION"
  echo -e "ok." >&2  
}


function createExportDir() {
  test "x$SKIP_EXPORT" == "xtrue" && return
  [ -d "$EXPORT_DIRNAME" ] && test "x$SKIP_CLEAN_EXPORT_DIR" != "xtrue" && rm -rf "$EXPORT_DIRNAME"
  mkdir -p "$EXPORT_DIRNAME"
}

function create_import_sql_script() {
  import_sql_script="$EXPORT_DIRNAME/import_sql_$LOCAL_DB_SCHEMA.sh"
  if ! [ -x "$import_sql_script" ]; then
    echo '#!/bin/bash' > "$import_sql_script"
    echo "mysql $MY_DATABASE_CONNECTION" >> "$import_sql_script"
    chmod +x "$import_sql_script"
  fi
}


function append_table_to_generate_sql_script() {
  export_filename="$1"
  generate_sql_script="$( dirname "$export_filename")/generate_sql_$LOCAL_DB_SCHEMA.sh"
  if ! [ -x "$generate_sql_script" ]; then
cat > "$generate_sql_script" <<EOF
#!/bin/bash
function read_file() {
  file="\$1"
  [ -r "\${file}" ] && cat "\${file}"
  [ -r "\${file}.gz" ] && zcat "\${file}.gz"
  [ -r "\${file}.bz2" ] && bzcat "\${file}.bz2"
}
EOF
    chmod +x "$generate_sql_script"
  fi
  cat >>"$generate_sql_script" <<EOF
read_file "\$(dirname "\$( readlink -f "\$0")" )/$(basename "$export_filename" )"
EOF
}

function exportToFile() {
  test "x$SKIP_EXPORT" == "xtrue" && return
  TABLE="$1"
  export_filename="$EXPORT_DIRNAME/$TABLE.sql"

  if ! [ -r "$export_filename" ]; then
    create_import_sql_script
    append_table_to_generate_sql_script "$export_filename"
  fi
  tee -a "$export_filename"
}

function compress_exported_files() {
  test "x$SKIP_EXPORT" == "xtrue" && return
  find "$EXPORT_DIRNAME" -type f -iname "*.sql" -exec $COMPRESSION_COMMAND {} \;
}

function exportToLocalMysql() {
  mysql $MY_DATABASE_CONNECTION
}

function read_column_values {
  TABLE="$1"
  COLUMN="$2"
  CONDITIONS="$3"
  DECORATE_VALUE="$4"
  DB_CONNECTION="${5-$MY_DATABASE_CONNECTION}"
  VALUES_SEPARATOR="${6-,}"
  SEPARATOR=""
  OUTPUT=""
  QUERY="select $COLUMN from $TABLE $CONDITIONS;"
  #echo "query: \"$QUERY\"" >&2
  echo "$QUERY" | mysql $DB_CONNECTION -r -N -B | while read VALUE; do
    echo -n "${SEPARATOR}${DECORATE_VALUE}${VALUE}${DECORATE_VALUE}"
    SEPARATOR="$VALUES_SEPARATOR"
  done
}

function helpMessage() {
  echo "Usage: $0 [options] [seed_output_directory]"
  echo "If output directory is omitted it will be autogenerated (seed-<date>)"
  echo "Options: "
  echo -e "\t-g | --gzip\t\t\tCompress seed files as gzip"
  echo -e "\t-b | --bzip2\t\t\tCompress seed files as bzip2"
  echo -e "\t-k | --keep-export-directory\tDon't delete output directory"
  echo -e "\t-n | --no-export\t\tDon't export seed file, just populate local database."
  echo ""
  echo "Supported database: mysql only at the moment."
  echo -e "Edit this script to change connection parameters.\n"
  exit 0
}


EXPORT_DIRNAME="seed-$( date +%Y-%m-%d )"
SKIP_EXPORT="false"
COMPRESSION_COMMAND="true"
DECOMPRESSION_COMMAND="true"

### Parse command line arguments
while test "x$1" != "x"; do
  case "$1" in
    "--help"|"-h")
      helpMessage
      ;;
    "-g"|"--gzip")
      COMPRESSION_COMMAND="gzip -9"
      DECOMPRESSION_COMMAND="gunzip"
      ;;
    "-b"|"--bzip2")
      COMPRESSION_COMMAND="bzip2 -9"
      DECOMPRESSION_COMMAND="bunzip2"
      ;;
    "--keep-export-directory"|"-k")
      SKIP_CLEAN_EXPORT_DIR="true"
      ;;
    "--no-export"|"-n")
      SKIP_EXPORT="true"
      ;;
    *)
      EXPORT_DIRNAME="$1"
      ;;
  esac
  shift
done

test "x$SKIP_EXPORT" != "xtrue" && createExportDir

# ## Domain specific import function
# ## Suggestion: declare your own import_main_table function, based on main_table_primarykey, then loop on the desired primary keys you want to import
# ## example below (supposing the table name is "maintable" and primary key is "maintableID"
#
# function import_maintable() {
#   record_id="$1"
#   echo -e "Import maintable id=$record_id $( read_column_values "maintable" "name_column" "WHERE maintableID=$record_id" "" "$OTHER_DATABASE_CONNECTION" )" >&2
#   importTable "maintable" "maintableID=$record_id"
#   #import secondary table, having a foreign key pointing to maintable
#   importTable "subtable1" "maintableID=$record_id"
#   #find imported id for subtable1
#   SUBTABLE1_IDS="$( read_column_values "subtable1" "subtable1Id" )"
#   #import a third table, having a foreign key pointing to subtable1
#   importTable "third_table" "subtable1ID in (${SUBTABLE1_IDS})"
# }
# 
# MAINTABLE_IDS_TO_IMPORT="1 2 3 10 100 1000"
# 
# EXPORT_OPTS="$EXPORT_DROPTABLE_OPTS"
# for maintable_id in $( echo $MAINTABLE_IDS_TO_IMPORT); do
#   import_maintable $maintable_id
#   EXPORT_OPTS="$EXPORT_NODROPTABLE_OPTS"
# done
# 
# ## always use "compress_exported_files" at the end, since it defaults to doing nothing if no compression method was specified
# compress_exported_files



