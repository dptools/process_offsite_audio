#!/usr/bin/env python

import os
import sys
import glob
import pandas as pd
import numpy as np

def get_email_summary_stats(data_root, study, lab_email_path, interview_type):
	# get paths of interest for all patients in this study
	os.chdir(os.path.join(data_root, "PROTECTED", study))
	# first get paths to main folders for all patients that have them
	path_of_interest1 = "processed/*/interviews/" + interview_type + "/temp_audio"
	path_of_interest2 = "processed/*/interviews/" + interview_type + "/audio_to_send"
	path_of_interest3 = "processed/*/interviews/" + interview_type + "/pending_audio"
	temp_folders_list = glob.glob(path_of_interest1)
	send_folders_list = glob.glob(path_of_interest2)
	pending_folders_list = glob.glob(path_of_interest3)
	# then expand the lists to contain the contents of those folders (filtered when appropriate, see below)
	temp_paths_list = []
	send_paths_list = []
	pending_paths_list_all = []
	for folder in temp_folders_list:
		temp_paths_list.extend(os.listdir(folder))
	for folder in send_folders_list:
		send_paths_list.extend(os.listdir(folder))
	for folder in pending_folders_list:
		pending_paths_list_all.extend(os.listdir(folder))
	# get only the newly uploaded pending files, in case still waiting on prior transcript orders as well
	pending_paths_list = [x for x in pending_paths_list_all if x.split("/")[-1][0:4]=="new+"] 
	# don't need to worry about a similar thing for the other two folders though - 
	# pipeline is the only script involved in this repo that created temp_audio subfolder, and it always deletes it at the end
	# similarly, main pipeline will exit if there are any prior files in to_send when auto transcription is on (and email is only expected to be sent in that case)

	# determine numbers in each category from the above lists
	num_pushed = len(pending_paths_list)
	num_failed = len(send_paths_list)
	num_rejected = len(temp_paths_list)
	num_selected = num_pushed + num_failed
	num_audios = num_selected + num_rejected
	num_secondary = len([x for x in temp_paths_list if x[0] == "0"]) # see error code guide
	num_short = len([x for x in temp_paths_list if x[0] == "1"])
	num_quiet = len([x for x in temp_paths_list if x[0] == "2"])

	# loop through all NEW pending (i.e. successfully pushed this run) audio paths, load DPDash audio QC CSV for each patient to count up the total length in minutes
	num_minutes = 0.0
	for filep in pending_paths_list:
		# find dpdash path from file path
		filen = filep.split("/")[-1]
		ptID = filen.split("_")[1]
		os.chdir(os.path.join(data_root, "GENERAL", study, "processed", ptID, "interviews", interview_type))
		# for this project the DPDash CSV name only uses avlqc identifier
		dpdash_name_format = "avlqc" + "-" + ptID + "-interviewMonoAudioQC_" + interview_type + "-day*.csv"
		dpdash_name = glob.glob(dpdash_name_format)[0] # DPDash script deletes any older days in this subfolder, so should only get 1 match each time
		dpdash_qc = pd.read_csv(dpdash_name) 
		# technically reloading this CSV for each file instead of for each patient, but should be a fast operation because CSV is small
		# also shouldn't be repeated that much in a normal run, as there cannot be more new uploads for a single patient than the number of days since the last run of the pipeline

		# get day number from file name, to assist in lookup of df
		day_num = int(filen.split("day")[1].split("_")[0])
		int_num = int(filen.split("session")[1].split(".")[0])
		# should always be exactly one matching entry, as only allowing one file into DPDash per day (first submitted)
		cur_row = dpdash_qc[(dpdash_qc["day"]==day_num) & (dpdash_qc["interview_number"]==int_num)] 
		# then get total time of that particular recording (in minutes)
		cur_count = float(cur_row["length_minutes"].tolist()[0])

		# update total count across the entire study
		num_minutes = num_minutes + cur_count

	# also get total length of files not sent
	num_minutes_unsent = 0.0
	for filep in send_paths_list:
		# find dpdash path from file path
		filen = filep.split("/")[-1]
		ptID = filen.split("_")[1]
		os.chdir(os.path.join(data_root, "GENERAL", study, "processed", ptID, "interviews", interview_type))
		# for this project the DPDash CSV name only uses avlqc identifier
		dpdash_name_format = "avlqc" + "-" + ptID + "-interviewMonoAudioQC_" + interview_type + "-day*.csv"
		dpdash_name = glob.glob(dpdash_name_format)[0] # DPDash script deletes any older days in this subfolder, so should only get 1 match each time
		dpdash_qc = pd.read_csv(dpdash_name) 
		# technically reloading this CSV for each file instead of for each patient, but should be a fast operation because CSV is small
		# also shouldn't be repeated that much in a normal run, as there cannot be more new uploads for a single patient than the number of days since the last run of the pipeline

		# get day number from file name, to assist in lookup of df
		day_num = int(filen.split("day")[1].split("_")[0])
		int_num = int(filen.split("session")[1].split(".")[0])
		# should always be exactly one matching entry, as only allowing one file into DPDash per day (first submitted)
		cur_row = dpdash_qc[(dpdash_qc["day"]==day_num) & (dpdash_qc["interview_number"]==int_num)] 
		# then get total time of that particular recording (in minutes)
		cur_count = float(cur_row["length_minutes"].tolist()[0])

		# update total count across the entire study
		num_minutes_unsent = num_minutes_unsent + cur_count

	# and get total length of bad files
	num_minutes_bad = 0.0
	for filep in temp_paths_list:
		# find dpdash path from file path
		filen = filep.split("/")[-1]
		ptID = filen.split("_")[1]
		os.chdir(os.path.join(data_root, "GENERAL", study, "processed", ptID, "interviews", interview_type))
		# for this project the DPDash CSV name only uses avlqc identifier
		dpdash_name_format = "avlqc" + "-" + ptID + "-interviewMonoAudioQC_" + interview_type + "-day*.csv"
		dpdash_name = glob.glob(dpdash_name_format)[0] # DPDash script deletes any older days in this subfolder, so should only get 1 match each time
		dpdash_qc = pd.read_csv(dpdash_name) 
		# technically reloading this CSV for each file instead of for each patient, but should be a fast operation because CSV is small
		# also shouldn't be repeated that much in a normal run, as there cannot be more new uploads for a single patient than the number of days since the last run of the pipeline

		# get day number from file name, to assist in lookup of df
		day_num = int(filen.split("day")[1].split("_")[0])
		int_num = int(filen.split("session")[1].split(".")[0])
		# should always be exactly one matching entry, as only allowing one file into DPDash per day (first submitted)
		cur_row = dpdash_qc[(dpdash_qc["day"]==day_num) & (dpdash_qc["interview_number"]==int_num)] 
		# then get total time of that particular recording (in minutes)
		cur_count = float(cur_row["length_minutes"].tolist()[0])

		# update total count across the entire study
		num_minutes_bad = num_minutes_bad + cur_count

	# round the number of minutes when done, for email purposes
	# note int rounds towards 0, and since our number will always be positive it is equivalent to taking the floor
	num_minutes = int(num_minutes)
	# just make sure taking the floor never results in an email saying we have 0 minutes, unless there are also 0 audios uploaded
	if num_minutes == 0 and num_pushed > 0:
		num_minutes = 1 
	# now get corresponding cost - we pay $1.75 per minute
	est_cost = round(1.75 * num_minutes, 2) # round to have units of cents

	# do the same for the unsent minutes if there are any
	if num_minutes_unsent > 0:
		num_minutes_unsent = int(num_minutes_unsent)
		# just make sure taking the floor never results in an email saying we have 0 minutes, unless there are also 0 audios uploaded
		if num_minutes_unsent == 0 and num_failed > 0:
			num_minutes_unsent = 1 
		# now get corresponding cost - we pay $1.75 per minute
		est_cost_unsent = round(1.75 * num_minutes_unsent, 2) # round to have units of cents

	# actually add to the email bodies now, first the lab email
	with open(lab_email_path, 'a') as f: # a for append mode, so doesn't erase any info already included
		f.write("Stats for interview type " + interview_type + ":")
		f.write("\n")

		# prep main sentence text
		lab_email_intro = str(num_audios) + " total interviews were newly processed for " + study + ". Of those, " + str(num_selected) + " were identified to be suitable for transcription, and " + str(num_pushed) + " successfully uploaded to TranscribeMe."
		lab_email_cost = "The uploaded audios totalled ~" + str(num_minutes) + " minutes, for an estimated transcription cost of $" + str(est_cost) + "."
		if num_minutes_unsent > 0:
			lab_email_unsent_cost = "Audio files that were found to be transcribable but were NOT successfully uploaded to TranscribeMe totalled ~" + str(num_minutes_unsent) + " minutes, for a potential future transcription cost of ~$" + str(est_cost_unsent) + "."
		lab_email_problems = "For the " + str(num_rejected) + " rejected audios (~" + str(round(num_minutes_bad,1)) + " total minutes), " + str(num_secondary) + " were rejected because of file naming issues, " + str(num_short) + " were rejected due to short length, and " + str(num_quiet) + " were rejected due to low volume."
		
		# actually do the file writes, end line with each of the 3 lines specified above
		# (python file.write() does not automatically add a trailing new line, while echo used in the bash script will add a trailing new line by default)
		f.write(lab_email_intro)
		f.write("\n")
		f.write(lab_email_cost)
		f.write("\n")
		if num_minutes_unsent > 0:
			f.write(lab_email_unsent_cost)
			f.write("\n")
		f.write(lab_email_problems)
		f.write("\n")

		# if any files weren't pushed as a result of SFTP error, will want to ensure user is aware of that - pipeline currently has no option to "try again later" automatically
		# (if this turns out to be a common occurence, can improve SFTP script and/or update pipeline to handle resend attempts automatically in the future. but suspect it will be rare)
		if num_failed > 0:
			lab_email_warning = "Because " + str(num_failed) + " audio files were intended to be sent but were not successfully pushed, it will be important to investigate the files remaining in the audio_to_send subfolders of this study - the pipeline will NOT automatically reattempt the upload."
			f.write(lab_email_warning)
			f.write("\n")

		# add one extra new line at end to space out if this is the first interview type
		if interview_type == "open":
			f.write("\n")

	return num_pushed, num_minutes

if __name__ == '__main__':
	# Map command line arguments to function arguments.
	o_pushed_num, o_pushed_minutes = get_email_summary_stats(sys.argv[1], sys.argv[2], sys.argv[3], "open")
	p_pushed_num, p_pushed_minutes = get_email_summary_stats(sys.argv[1], sys.argv[2], sys.argv[3], "psychs")
	print("Total audio files successfully pushed to TranscribeMe for this site today = " + str(o_pushed_num + p_pushed_num))
	print("Total minutes of audio successfully pushed for this site today = " + str(o_pushed_minutes + p_pushed_minutes))
