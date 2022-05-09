#!/bin/bash

# will call this module with arguments in main pipeline, root then study
data_root="$1"
study="$2"

echo "Beginning raw interview folder accounting script for study ${study}"
# will make one raw accounting sheet per patient and interview type for this site
# looks for raw SOP violations, focuses just on that

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
cd "$data_root"/PROTECTED/"$study"/raw
# will do one loop for open and another for psychs
echo "Processing new open interviews for all patients"
for p in *; do
	# first check that it is truly a patient ID, that has raw interview data
	if [[ ! -d $p/interviews/open ]]; then
		continue
	fi
	cd "$p"/interviews
	# also check that said folder is not empty
	if [ -z "$(ls -A open)" ]; then
		cd "$data_root"/PROTECTED/"$study"/raw # back out of folder before skipping over patient
		continue
	fi

	python "$func_root"/raw_interview_sop_check.py "open" "$data_root" "$study" "$p"

	# back out of folder before continuing to next patient
	cd "$data_root"/PROTECTED/"$study"/raw
done

echo "Processing new psychs interviews for all patients"
for p in *; do
	# first check that it is truly a patient ID, that has raw interview data
	if [[ ! -d $p/interviews/psychs ]]; then
		continue
	fi
	cd "$p"/interviews
	# also check that said folder is not empty
	if [ -z "$(ls -A psychs)" ]; then
		cd "$data_root"/PROTECTED/"$study"/raw # back out of folder before skipping over patient
		continue
	fi

	python "$func_root"/raw_interview_sop_check.py "psychs" "$data_root" "$study" "$p"

	# back out of folder before continuing to next patient
	cd "$data_root"/PROTECTED/"$study"/raw
done