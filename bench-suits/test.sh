# ...existing code...

YCSB="../bin/ycsb.sh"
GCP_USER="shen.li@airwallex.com"

PROJECT=risk-nonprod-87a1e6c5
INSTANCE=test-evaluation
FAMILY=cf
SPLITS=$(echo 'num_splits = 200; puts (1..num_splits).map {|i| "user#{1000+i*(9999-1000)/num_splits}"}.join(",")' | ruby)

# Install cbt component
gcloud components install cbt
# Prompt user to log in to GCP
echo "Please log in to your GCP account:"
gcloud auth login --no-browser
echo "Please copy the URL above and open it in your browser to complete the login process."

# ...existing code...
export GOOGLE_APPLICATION_CREDENTIALS=~/.config/gcloud/legacy_credentials/$GCP_USER/adc.json

cbt -project $PROJECT -instance=$INSTANCE createtable usertable families=$FAMILY:maxversions=1 splits=$SPLITS

THREADS=1000
WORKSPACE=./MyWorkspace

declare -a TESTS
TESTS=(
    "workload-insert.ini"
    "workload-read.ini"
    "workload-real.ini"
)

for WORKLOAD in "${TESTS[@]}"; do
    TEST=$(basename "$WORKLOAD" .ini)
    $YCSB load googlebigtable2 -P $WORKLOAD \
        -threads $THREADS \
        -p googlebigtable2.project=$PROJECT \
        -p googlebigtable2.instance=$INSTANCE \
        -p googlebigtable2.family=$FAMILY > $WORKSPACE/${TEST}-bt-load.log

    $YCSB run googlebigtable2 -P $WORKLOAD \
        -threads $THREADS \
        -p googlebigtable2.project=$PROJECT \
        -p googlebigtable2.instance=$INSTANCE \
        -p googlebigtable2.family=$FAMILY > $WORKSPACE/${TEST}-bt-run.log
done

# before bench scylla, running 
: '
cqlsh 127.0.0.1:9042 -u cassandra -p cassandra -e "
CREATE KEYSPACE IF NOT EXISTS ycsb WITH REPLICATION = {'class': 'SimpleStrategy', 'replication_factor': 1};
USE ycsb;
CREATE TABLE IF NOT EXISTS usertable (
  y_id varchar PRIMARY KEY,
  field0 varchar,
  field1 varchar,
  field2 varchar,
  field3 varchar,
  field4 varchar,
  field5 varchar,
  field6 varchar,
  field7 varchar,
  field8 varchar,
  field9 varchar
);
"
'
# running this in local machine to init the table

# then find the service of scylla
SCYLLAHOST="scylla-client.scylla.svc.cluster.local"

for WORKLOAD in "${TESTS[@]}"; do

    $YCSB load scylla -s -P $WORKLOAD \
        -threads $THREADS \
        -p cassandra.username=cassandra \
        -p cassandra.password=cassandra \
        -p scylla.hosts=$SCYLLAHOST > $WORKSPACE/${TEST}-scylla-load.log

    $YCSB run scylla -s -P $WORKLOAD \
        -threads $THREADS \
        -p cassandra.username=cassandra \
        -p cassandra.password=cassandra \
        -p scylla.hosts=$SCYLLAHOST > $WORKSPACE/${TEST}-scylla-run.log
done