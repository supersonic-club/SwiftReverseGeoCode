#!/bin/bash

#DATA="cities1000.txt"
DATA="cities500.txt"
#DATA="allCountries.txt"
ADMIN1="admin1CodesASCII.txt"
COUNTRIES="countryInfo.txt"
OUTPUT="geocitydb.sqlite"

if [ ! -f "$DATA" ]; then
  echo "Downloading cities from Geonames..."
  wget "http://download.geonames.org/export/dump/cities500.zip"
  unzip "cities500.zip"

  #wget "http://download.geonames.org/export/dump/cities1000.zip"
  #unzip "cities1000.zip"
  #wget "http://download.geonames.org/export/dump/allCountries.zip"
  #unzip "allCountries.zip"

else
  echo "Using existing $DATA"
fi

if [ ! -f "$ADMIN1" ]; then
  echo "Downloading admin1 from Geonames..."
  wget "http://download.geonames.org/export/dump/admin1CodesASCII.txt"
else
  echo "Using existing $ADMIN1"
fi

if [ ! -f "$COUNTRIES" ]; then
  echo "Downloading countries from Geonames..."
  wget "http://download.geonames.org/export/dump/countryInfo.txt"
else
  echo "Using existing $COUNTRIES"
fi

if [ -f "$OUTPUT" ]; then
  echo
  echo "The file $OUTPUT already exists."
  read -p "Do you want to override it? (y/N) " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 1
  fi

  rm "$OUTPUT"
fi

echo
echo "Generating..."

awk 'BEGIN { FS="\t"; OFS=";" } { gsub("\"", "", $2); gsub(";", "", $2); print $1,$2,$9,$11 }' $DATA > features.tsv
awk 'BEGIN { FS="\t"; OFS=";" } { print $1,$5,$6 }' $DATA > coordinates.tsv
awk 'BEGIN { FS="\t"; OFS=";" } { split($1, id, "."); gsub("\"", "", $2); gsub(";", "", $2); print id[1],id[2],$2 }' $ADMIN1 > admin1.tsv
grep -vE '^#' $COUNTRIES | awk 'BEGIN { FS="\t"; OFS=";" } { print $1,$2,$5 }' > countries.tsv

echo '
CREATE TABLE coordinates(
  feature_id INTEGER,
  latitude REAL,
  longitude REAL,
  PRIMARY KEY (feature_id)
);

CREATE TABLE features(
  id INTEGER,
  name TEXT,
  country_id TEXT,
  admin1_id INTEGER,
  PRIMARY KEY (id)
);

CREATE TABLE admin1(
  country_id TEXT,
  id INTEGER,
  name TEXT,
  PRIMARY KEY (country_id, id)
);

CREATE TABLE countries(
  id TEXT,
  loc3 TEXT,
  name TEXT,
  PRIMARY KEY (id)
);

CREATE VIEW everything AS
  SELECT
    features.id,
    features.name,
    admin1.id AS admin1_id,
    admin1.name AS admin1_name,
    countries.id AS country_id,
    countries.loc3 AS country_loc3,
    countries.name AS country_name,
    coordinates.latitude AS latitude,
    coordinates.longitude AS longitude
  FROM features
    LEFT JOIN countries ON features.country_id = countries.id
    LEFT JOIN admin1 ON features.country_id = admin1.country_id AND features.admin1_id = admin1.id
    JOIN coordinates ON features.id = coordinates.feature_id;

.separator ";"
.import coordinates.tsv coordinates
.import features.tsv features
.import admin1.tsv admin1
.import countries.tsv countries

CREATE INDEX coordinates_lat_lng ON coordinates (latitude, longitude);
' | sqlite3 "$OUTPUT"

COUNT=`sqlite3 "$OUTPUT" "SELECT COUNT(*) FROM features;"`
echo "Created $OUTPUT with $COUNT features."
