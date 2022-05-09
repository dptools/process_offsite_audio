#!/bin/bash

# will call this module with arguments in main pipeline, root then study
data_root="$1"
study="$2"

echo "Beginning QC stats computation for study ${study}"

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

# for this script actually going to run as a single python function study-wide! to better facilitate the email part

echo "Processing new open interviews"
# compute patient summary stats for each modality using DPDash CSVs, add to some historical log
# within each patient's historical log CSV, also include site wide summary stats at current date
if [[ $pipeline = "Y" ]]; then 
	# if in pipeline, write the most key site-wide summary stats for the current date in human-readable format to the summary email body as part of fxn, so give that path
	python "$func_root"/interview_qc_statistics.py "open" "$data_root" "$study" "$repo_root"/summary_lab_email_body.txt
else
	python "$func_root"/interview_qc_statistics.py "open" "$data_root" "$study" 
fi

echo "Processing new psychs interviews"
# compute patient summary stats for each modality using DPDash CSVs, add to some historical log
# within each patient's historical log CSV, also include site wide summary stats at current date
if [[ $pipeline = "Y" ]]; then 
	# if in pipeline, write the most key site-wide summary stats for the current date in human-readable format to the summary email body as part of fxn, so give that path
	python "$func_root"/interview_qc_statistics.py "psychs" "$data_root" "$study" "$repo_root"/summary_lab_email_body.txt
else
	python "$func_root"/interview_qc_statistics.py "psychs" "$data_root" "$study"
fi
