#!/bin/bash

# will call this module with arguments in main pipeline, root then study
data_root="$1"
study="$2"

echo "Beginning warnings compilation for study ${study}"

# allow module to be called stand alone as well as from main pipeline
if [[ -z "${repo_root}" ]]; then
	# get path current script is being run from, in order to get path of repo for calling functions used
	full_path=$(realpath $0)
	module_root=$(dirname $full_path)
	func_root="$module_root"/functions_called
else
	func_root="$repo_root"/individual_modules/functions_called
	pipeline="Y" # track when in pipeline for contributing email portion
fi

# move to study folder to loop over patients - python function defined per patient
cd "$data_root"/PROTECTED/"$study"/processed
# will do one loop for open and another for psychs
echo "Processing new open interviews"
for p in *; do
	# first check that it is truly a patient ID, that has an interviews folder ready (under PROTECTED and GENERAL)
	if [[ ! -d $p/interviews/open ]]; then
		continue
	fi
	if [[ ! -d ${data_root}/GENERAL/${study}/processed/${p}/interviews/open ]]; then
		continue
	fi
	
	# check if any new processing done, if so merge together any existing processed accounting CSVs to save new merged version
	# use DPDash QC info to check for any warnings on these newly processed files, if so add to process warning accounting table
	# if calling from pipeline also give email output paths to add any new warnings from this and from the raw accounting CSV, also init a summary if any newly processed at all
	if [[ $pipeline = "Y" ]]; then 
		python "$func_root"/interview_warnings_detection.py "open" "$data_root" "$study" "$p" "$repo_root"/warning_lab_email_body.txt "$repo_root"/summary_lab_email_body.txt
	else
		python "$func_root"/interview_warnings_detection.py "open" "$data_root" "$study" "$p"
	fi
done

echo "Processing new psychs interviews"
for p in *; do
	# first check that it is truly a patient ID, that has an interviews folder ready (under PROTECTED and GENERAL)
	if [[ ! -d $p/interviews/psychs ]]; then
		continue
	fi
	if [[ ! -d ${data_root}/GENERAL/${study}/processed/${p}/interviews/psychs ]]; then
		continue
	fi
	
	# check if any new processing done, if so merge together any existing processed accounting CSVs to save new merged version
	# use DPDash QC info to check for any warnings on these newly processed files, if so add to process warning accounting table
	# if calling from pipeline also give email output paths to add any new warnings from this and from the raw accounting CSV, also init a summary if any newly processed at all
	if [[ $pipeline = "Y" ]]; then 
		python "$func_root"/interview_warnings_detection.py "psychs" "$data_root" "$study" "$p" "$repo_root"/warning_lab_email_body.txt "$repo_root"/summary_lab_email_body.txt
	else
		python "$func_root"/interview_warnings_detection.py "psychs" "$data_root" "$study" "$p"
	fi
done