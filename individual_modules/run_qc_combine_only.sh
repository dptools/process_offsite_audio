#!/bin/bash

# will call this module with arguments in main pipeline, root then study
data_root="$1"
study="$2"

echo "Beginning QC stats combination for study ${study}"

# allow module to be called stand alone as well as from main pipeline
if [[ -z "${repo_root}" ]]; then
	# get path current script is being run from, in order to get path of repo for calling functions used
	full_path=$(realpath $0)
	module_root=$(dirname $full_path)
	func_root="$module_root"/functions_called
else
	func_root="$repo_root"/individual_modules/functions_called
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