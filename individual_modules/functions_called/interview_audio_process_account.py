#!/usr/bin/env python

import os
import sys
import datetime
import glob
import string
import pandas as pd
import numpy as np

# final step of audio pipeline is to do various file accounting!
def interview_raw_audio_account(interview_type, data_root, study, ptID):
	# start with looking up existing audio
	os.chdir(os.path.join(data_root, "PROTECTED", study, "processed", ptID, "interviews", interview_type))
	try:
		prev_account = pd.read_csv(study + "_" + ptID + "_" + interview_type + "InterviewAudioProcessAccountingTable.csv")
		processed_list = prev_account["raw_audio_path"].tolist()
	except:
		processed_list = []	

	# column names list to be used
	column_names = ["day", "interview_number", "interview_date", "interview_time", "raw_audio_path", "processed_audio_filename", 
					"audio_process_date", "accounting_date", "consent_date_at_accounting", 
					"audio_success_bool", "audio_rejected_bool", "auto_upload_failed_bool",
					"single_file_bool", "video_raw_path", "top_level_m4a_count", "top_level_mp4_count", 
					"speaker_specific_file_count", "speaker_specific_valid_m4a_count", "speaker_specific_unique_ID_count"]
	# initialize lists to track all these variables
	day_list = []
	interview_number_list = []
	interview_date_list = []
	interview_time_list = []
	raw_audio_path_list = []
	processed_audio_filename_list = []
	audio_process_date_list = []
	accounting_date_list = []
	consent_date_at_accounting_list = []
	audio_success_bool_list = []
	audio_rejected_bool_list = []
	auto_upload_failed_bool_list = []
	single_file_bool_list = []
	video_raw_path_list = []
	top_level_m4a_count_list = []
	top_level_mp4_count_list = []
	speaker_specific_file_count_list = []
	speaker_specific_valid_m4a_count_list = []
	speaker_specific_unique_ID_count_list = []

	# get current consent date string for accounting purposes, as well as today's date
	today_str = datetime.date.today().strftime("%Y-%m-%d")
	# there must be a valid consent date for the patient already in order for there to be files in the filename map folder, which is checked by wrapper before calling
	study_metadata_path = os.path.join(data_root,"GENERAL",study,study + "_metadata.csv")
	study_metadata = pd.read_csv(study_metadata_path)
	patient_metadata = study_metadata[study_metadata["Subject ID"] == ptID]
	consent_date_str = patient_metadata["Consent"].tolist()[0]
	# there also must already be this folder with files in it for wrapping bash script to call the function
	os.chdir(os.path.join(data_root, "PROTECTED", study, "processed", ptID, "interviews", interview_type, "audio_filename_maps"))
	cur_files = os.listdir(".")

	# loop through filename maps now to update records for any newly processed audios
	for filename in cur_files:
		if not filename.endswith(".txt"): # confirm we only have text files, skip any non
			print("Unexpected file (" + filename + ") in folder for " + ptID + " " + interview_type + " - ignoring")
			continue
	
		# line 1 is full raw path , line 2 is renamed file name
		with open(filename, 'r') as cur_f:
			line_list = cur_f.readlines()
		raw_audio_path = line_list[0]
		# check that this hasn't already been processed using the raw path before proceeding, otherwise skip
		if raw_audio_path in processed_list:
			continue
		audio_rename = line_list[1]
		# title is date + time
		interview_date = filename.split("+")[0]
		interview_time = filename.split("+")[1].split(".txt")[0]
		# get day and interview numbers from within the renamed file name
		day_num = int(audio_rename.split("_day")[1].split("_")[0])
		sess_num = int(audio_rename.split("_session")[1].split(".")[0])
		# get last modified date of the sliding qc for this file too, in case today's date is not reflective of the audio processing date
		sliding_qc_path = "../sliding_window_audio_qc/" + filename.split(".txt")[0] + ".csv"
		last_modified_date = datetime.datetime.fromtimestamp(os.path.getmtime(sliding_qc_path)).date().strftime("%Y-%m-%d")

		# check for which folder the final audio is under to log what happened to it
		if os.path.exists("../pending_audio/" + audio_rename) or os.path.exists("../completed_audio/" + audio_rename):
			success_bool = 1
		else:
			success_bool = 0
		if os.path.exists("../rejected_audio/" + audio_rename):
			reject_bool = 1
		else:
			reject_bool = 0
		if os.path.exists("../audio_to_send/" + audio_rename):
			upload_failed_bool = 1
		else:
			upload_failed_bool = 0

		# at this point start appending to lists!
		day_list.append(day_num)
		interview_number_list.append(sess_num)
		interview_date_list.append(interview_date)
		interview_time_list.append(interview_time)
		raw_audio_path_list.append(raw_audio_path)
		processed_audio_filename_list.append(audio_rename)
		audio_process_date_list.append(last_modified_date)
		accounting_date_list.append(today_str)
		consent_date_at_accounting_list.append(consent_date_str)
		audio_success_bool_list.append(success_bool)
		audio_rejected_bool_list.append(reject_bool)
		auto_upload_failed_bool_list.append(upload_failed_bool)

		# looks up the raw folder associated (when it is a folder) to confirm properly named video mp4 exists as expected (take down path) and how many other top level .mp4s are found
		# after that will also do speaker specific file accounting
		interview_folder_name = raw_audio_path.split("/")[-2]
		if interview_folder_name == interview_type:
			# this is the case where it is just a single file, so all the rest of these stats will be meaningless, can just continue
			single_file_bool_list.append(1)
			video_raw_path_list.append(np.nan)
			top_level_m4a_count_list.append(np.nan)
			top_level_mp4_count_list.append(np.nan)
			speaker_specific_file_count_list.append(np.nan)
			speaker_specific_valid_m4a_count_list.append(np.nan)
			speaker_specific_unique_ID_count_list.append(np.nan)
			continue
		single_file_bool_list.append(0)
		
		# now go to the relevant folder to do all the rest of the accounting
		os.chdir(os.path.join(data_root,"PROTECTED", study, "raw", ptID, "interviews", interview_type, interview_folder_name))
		# get video raw path checking for both possible zoom conventions
		old_video_match = glob.glob("zoom*.mp4")
		new_video_match = glob.glob("video*mp4")
		if len(new_video_match) + len(old_video_match) != 1:
			video_raw_path = ""
		else:
			try:
				raw_video_name = new_video_match[0]
			except:
				raw_video_name = old_video_match[0]
			video_raw_path = os.path.join(data_root,"PROTECTED", study, "raw", ptID, "interviews", interview_type, interview_folder_name, raw_video_name)
		num_top_level_m4a = len(glob.glob("*.m4a"))
		num_top_level_mp4 = len(glob.glob("*.mp4"))
		num_audio_record_files = len(glob.glob("Audio Record/*"))
		num_speaker_files_valid = len(glob.glob("Audio Record/audio*.m4a")) # new and old both start with audio and end with m4a under Audio Record, so just check for that
		# for getting the IDs need to accomodate new and old formats
		if len(glob.glob("Audio Record/audio_only*.m4a")) > 0:
			speaker_IDs_list = []
			for sp_file in glob.glob("Audio Record/audio_only*.m4a"):
				sp_comps = sp_file.split("_")
				cur_index = 0
				for comp in range(len(sp_comps)):
					if len(sp_comps[comp]) > 4 and sp_comps[comp].isdigit():
						cur_index = comp + 1
						break # find index of the id number, everything after this is unique speaker ID
				cur_ID = '_'.join(sp_comps[cur_index:])
				speaker_IDs_list.append(cur_ID)
			num_speaker_IDs_found = len(set(speaker_IDs_list))
		else:
			# we must be in new format if we reach here
			speaker_IDs_list = []
			for sp_file in glob.glob("Audio Record/audio*.m4a"):
				# first split up text so should only be left with display name and number
				sp_filename = sp_file.split("/")[-1].split(".m4a")[0].split("audio")[-1]
				cur_ID = sp_filename.rstrip(string.digits)
				speaker_IDs_list.append(cur_ID)
			num_speaker_IDs_found = len(set(speaker_IDs_list))

		# now append new values found
		video_raw_path_list.append(video_raw_path)
		top_level_m4a_count_list.append(num_top_level_m4a)
		top_level_mp4_count_list.append(num_top_level_mp4)
		speaker_specific_file_count_list.append(num_audio_record_files)
		speaker_specific_valid_m4a_count_list.append(num_speaker_files_valid)
		speaker_specific_unique_ID_count_list.append(num_speaker_IDs_found)

		# before looping to next file return to filemap folder
		os.chdir(os.path.join(data_root,"PROTECTED", study, "processed", ptID, "interviews", interview_type, "audio_filename_maps"))

	# construct CSV now
	values_list = [day_list, interview_number_list, interview_date_list, interview_time_list, raw_audio_path_list, processed_audio_filename_list, 
				   audio_process_date_list, accounting_date_list, consent_date_at_accounting_list, 
				   audio_success_bool_list, audio_rejected_bool_list, auto_upload_failed_bool_list, 
				   single_file_bool_list, video_raw_path_list, top_level_m4a_count_list, top_level_mp4_count_list, 
				   speaker_specific_file_count_list, speaker_specific_valid_m4a_count_list, speaker_specific_unique_ID_count_list]
	new_df = pd.DataFrame()
	for header,value in zip(column_names, values_list):
		new_df[header] = value

	# can just exit if there is no new info to concat
	if new_df.empty:
		return

	# concat if one already exists, otherwise just save
	output_path = "../" + study + "_" + ptID + "_" + interview_type + "InterviewAudioProcessAccountingTable.csv"
	if len(processed_list) > 0:
		join_df = pd.concat([prev_account, new_df])
		join_df.reset_index(drop=True, inplace=True)
		join_df.to_csv(output_path, index=False)
	else:
		new_df.to_csv(output_path, index=False)

if __name__ == '__main__':
	# Map command line arguments to function arguments.
	interview_raw_audio_account(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])
