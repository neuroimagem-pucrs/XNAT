#!/bin/bash
 
# downloadCNDASessions.sh expects 2 params
# CNDA user id
# input file containing list of session ids, one per line
# example:  ./downloadCNDASessions.sh userID ./myListOfSessions.txt
 
INPUT_FILE=$2
USER=$1
SITE=http://xnat.portoalegre.pucrsnet.br
CURR_DIR=`pwd`
 
JSESSION=`curl -u ${USER} "${SITE}/data/JSESSION"`

echo $JSESSION 

echo $INPUT_FILE
 
#!! Update this with directory where sessions should be stored.
SESSIONS_DIR=./CNDA_Sessions
if [ ! -d ${SESSIONS_DIR} ]; then
   mkdir ${SESSIONS_DIR}
fi


let i=0
while read line 
do
    let i=$i+1
    echo Downloading ${i} ${line}
    
    
    # Option 1: Download all files in the session
  #curl -b JSESSIONID=${JSESSION} "${SITE}/data/archive/experiments/${line}/scans/*/files?format=zip" > ${SESSIONS_DIR}/${line}.zip

  curl -v -b JSESSIONID=${JSESSION} "${SITE}/data/archive/projects/VIVA/scans/*/files?format=zip" > ${SESSIONS_DIR}/${line}.zip
								#	   /data/archive/projects/TEST/subjects/1/experiments/MR1/scans/1/resources/DICOM/files
   
   exit
    # Option 2: Download specific scans by name (be sure to encode spaces as %20)
    # curl -b JSESSIONID=${JSESSION} "${SITE}/data/archive/experiments/${line}/scans/MPRAGE%20GRAPPA2/files?format=zip" > ${SESSIONS_DIR}/${line}.zip
#    curl -b JSESSIONID=${JSESSION} "${SITE}/data/archive/experiments/${line}/scans/CHANGE/files?format=zip" > ${SESSIONS_DIR}/${line}.zip
    # Option 3: Download specific scans by number (comma-separated for multiple scans)
 	# curl -b JSESSIONID=${JSESSION} "${SITE}/data/archive/experiments/${line}/scans/2,3/files?format=zip" > ${SESSIONS_DIR}/${line}.zip
    #!! If you don't want script to unzip sessions and remove zip file for you, comment lines below
#    cd ${SESSIONS_DIR}
#    unzip ${line}.zip
#    rm ${line}.zip
#    cd ${CURR_DIR}
    #!! End commentable block
    
    echo blah
    
done < $INPUT_FILE
 
#curl -b JSESSIONID=${JSESSION} -X DELETE "${SITE}/data/JSESSION"


