#!/bin/bash

# will call this module with arguments in main pipeline, root then study
data_root="$1"
study="$2"

echo "Beginning transcript redaction script for study ${study}"

# allow module to be called stand alone as well as from main pipeline
if [[ -z "${repo_root}" ]]; then
	# get path current script is being run from, in order to get path of repo for calling functions used
	full_path=$(realpath $0)
	module_root=$(dirname $full_path)
	func_root="$module_root"/functions_called
else
	func_root="$repo_root"/individual_modules/functions_called
fi

# move to study folder to loop over patients
cd "$data_root"/PROTECTED/"$study"/processed
# will do one loop for open and another for psychs
echo "Processing new open interview transcripts"
for p in *; do
	# first check that it is truly a patient ID, that has a transcripts folder for the open interviews
	if [[ ! -d $p/interviews/open/transcripts ]]; then
		continue
	fi
	cd "$p"/interviews/open/transcripts


	# then check that there are some top level PROTECTED transcript files available for this patient
	if [ -z "$(ls -A *.txt 2> /dev/null)" ]; then 
		cd "$data_root"/PROTECTED/"$study"/processed # back out of folder before skipping over patient
		continue
	fi

	# now get started
	echo "On patient ${p}"

	# make GENERAL side transcript folder for the patient if needed
	if [[ ! -d "$data_root"/GENERAL/"$study"/processed/"$p"/interviews/open/transcripts ]]; then
		# up to open should already exist here per main pipeline
		mkdir "$data_root"/GENERAL/"$study"/processed/"$p"/interviews/open/transcripts
	fi

	# look only for txt files on the top level of this folder, indicating they've already made it past the review step (if selected)
	for file in *.txt; do
		name=$(echo "$file" | awk -F '.txt' '{print $1}')
		# create the redacted copy for this transcript if it does not already exist
		if [[ ! -e "$data_root"/GENERAL/"$study"/processed/"$p"/interviews/open/transcripts/"$name"_REDACTED.txt ]]; then
			python "$func_root"/redact_transcripts_func.py "$file" "$data_root"/GENERAL/"$study"/processed/"$p"/interviews/open/transcripts/"$name"_REDACTED.txt
		fi
	done

	# back out of folder before continuing to next patient
	cd "$data_root"/PROTECTED/"$study"/processed
done

# repeat same process for psychs interviews
cd "$data_root"/PROTECTED/"$study"/processed
echo "Processing new psychs interview transcripts"
for p in *; do
	# first check that it is truly a patient ID, that has a transcripts folder for the psychs interviews
	if [[ ! -d $p/interviews/psychs/transcripts ]]; then
		continue
	fi
	cd "$p"/interviews/psychs/transcripts

	# then check that there are some top level PROTECTED transcript files available for this patient
	if [ -z "$(ls -A *.txt 2> /dev/null)" ]; then
		cd "$data_root"/PROTECTED/"$study"/processed # back out of folder before skipping over patient
		continue
	fi

	# now get started
	echo "On patient ${p}"

	# make GENERAL side transcript folder for the patient if needed
	if [[ ! -d "$data_root"/GENERAL/"$study"/processed/"$p"/interviews/psychs/transcripts ]]; then
		# up to psychs should already exist here per main pipeline
		mkdir "$data_root"/GENERAL/"$study"/processed/"$p"/interviews/psychs/transcripts
	fi

	# look only for txt files on the top level of this folder, indicating they've already made it past the review step (if selected)
	for file in *.txt; do
		name=$(echo "$file" | awk -F '.txt' '{print $1}')
		# create the redacted copy for this transcript if it does not already exist
		if [[ ! -e "$data_root"/GENERAL/"$study"/processed/"$p"/interviews/psychs/transcripts/"$name"_REDACTED.txt ]]; then
			python "$func_root"/redact_transcripts_func.py "$file" "$data_root"/GENERAL/"$study"/processed/"$p"/interviews/psychs/transcripts/"$name"_REDACTED.txt
		fi
	done

	# back out of folder before continuing to next patient
	cd "$data_root"/PROTECTED/"$study"/processed
done