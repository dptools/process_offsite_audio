#!/bin/bash

# will call this module with arguments in main pipeline, root then study
data_root="$1"
study="$2"

echo "Beginning transcript QC script for study ${study}"

# allow module to be called stand alone as well as from main pipeline
if [[ -z "${repo_root}" ]]; then
	# get path current script is being run from, in order to get path of repo for calling functions used
	full_path=$(realpath $0)
	module_root=$(dirname $full_path)
	func_root="$module_root"/functions_called
else
	func_root="$repo_root"/individual_modules/functions_called
fi

# move to study folder to loop over patients - python function defined per patient
# redacted transcripts are in GENERAL
cd "$data_root"/GENERAL/"$study"/processed
# will do one loop for open and another for psychs
echo "Processing all final redacted open interview transcripts"
for p in *; do
	# first check that it is truly a patient ID, that has a transcript CSV folder for open interviews
	if [[ ! -d $p/interviews/open/transcripts/csv ]]; then
		continue
	fi
	cd "$p"/interviews/open/transcripts

	# then check that there are some files actually in the CSV folder
	if [ -z "$(ls -A csv)" ]; then
		cd "$data_root"/GENERAL/"$study"/processed # back out of folder before skipping over patient
		continue
	fi
	cd csv

	echo "On patient ${p}"
	
	# finally run main transcript QC script on this patient
	python "$func_root"/interview_transcript_qc.py "open" "$data_root" "$study" "$p"

	# back out of folder before continuing to next patient
	cd "$data_root"/GENERAL/"$study"/processed
done

# repeat for psychs
cd "$data_root"/GENERAL/"$study"/processed
echo "Processing all final redacted psychs interview transcripts"
for p in *; do
	# first check that it is truly a patient ID, that has a transcript CSV folder for open interviews
	if [[ ! -d $p/interviews/psychs/transcripts/csv ]]; then
		continue
	fi
	cd "$p"/interviews/psychs/transcripts

	# then check that there are some files actually in the CSV folder
	if [ -z "$(ls -A csv)" ]; then
		cd "$data_root"/GENERAL/"$study"/processed # back out of folder before skipping over patient
		continue
	fi
	cd csv

	echo "On patient ${p}"
	
	# finally run main transcript QC script on this patient
	python "$func_root"/interview_transcript_qc.py "psychs" "$data_root" "$study" "$p"

	# back out of folder before continuing to next patient
	cd "$data_root"/GENERAL/"$study"/processed
done