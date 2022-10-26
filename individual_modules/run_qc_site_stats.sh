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

# move to study folder to loop over patients - first combining python function defined per patient
cd "$data_root"/GENERAL/"$study"/processed
echo "Combining DPDash CSVs across modality"
for p in *; do
	# first check that it is truly a patient ID
	if [[ ! -d $p/interviews ]]; then
		continue
	fi

	# now confirm for open and psychs respectively that there will be a folder to move to by the python script
	if [[ -d $p/interviews/open ]]; then
		python "$func_root"/interview_qc_combine.py "open" "$data_root" "$study" "$p"
	fi
	if [[ -d $p/interviews/psychs ]]; then
		python "$func_root"/interview_qc_combine.py "psychs" "$data_root" "$study" "$p"
	fi
done

# for main part of script actually going to run as a single python function study-wide! to better facilitate the email part
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
