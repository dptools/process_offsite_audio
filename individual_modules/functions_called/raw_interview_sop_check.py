#!/usr/bin/env python

import os
import sys
import datetime
import glob
import pandas as pd
import numpy as np

# do file accounting of raw interviews here! will only keep list of those not meeting convention
def interview_raw_account(interview_type, data_root, study, ptID):
	# start with looking up existing sop checks
	try:
		prev_account = pd.read_csv("../" + study + "_" + ptID + "_" + interview_type + "RawInterviewSOPAccountingTable.csv")
		existing_list = prev_account["raw_name"].tolist()
	except:
		existing_list = []	

	# column names list to be used
	column_names = ["raw_name", "folder_bool", "valid_folder_name_bool", "num_audio_m4a", "num_video_mp4", "num_top_level_files", "date_detected"]
	# initialize lists to track all these variables
	raw_name_list = []
	folder_bool_list = []
	valid_folder_name_bool_list = []
	num_audio_m4a_list = []
	num_video_mp4_list = []
	num_top_level_files_list = []
	date_detected_list = []

	# get current date string for accounting purposes
	today_str = datetime.date.today().strftime("%Y-%m-%d")

	# there must already be this folder with subfolders in it for wrapping bash script to call the function
	os.chdir(os.path.join(data_root,"PROTECTED", study, "raw", ptID, "interviews", interview_type))
	cur_folders = os.listdir(".")

	# loop through raw folders available now
	for foldername in cur_folders:
		if foldername in existing_list:
			continue # skip the folder if it is already listed

		# now check if it is actually a folder, start to decide if it even should be included (if fully meeting convention shouldn't!)
		if os.path.isdir(foldername):
			cur_folder_bool = 1
			if len(foldername.split(" ")) > 1 and len(foldername.split(" ")[0]) == 10 and len(foldername.split(" ")[1]) == 8:
				cur_name_bool = 1
			else:
				cur_name_bool = 0
		else:
			if interview_type == "psychs" and foldername.endswith(".WAV") and len(foldername) == 18:
				# in this case it is valid standalone wav
				continue
			# otherwise we have a standalone file that is not allowed (and not previously registered) so it should be added to list for this CSV
			raw_name_list.append(foldername)
			folder_bool_list.append(0)
			valid_folder_name_bool_list.append(np.nan)
			num_audio_m4a_list.append(np.nan)
			num_video_mp4_list.append(np.nan)
			num_top_level_files_list.append(np.nan)
			date_detected_list.append(today_str)
			# done with the file either way in this particular case now
			continue

		# now that we know it is a folder, get various counts of files underneath
		num_valid_audio = len(glob.glob(os.path.join(foldername,"audio*.m4a")))
		num_valid_video_new = len(glob.glob(os.path.join(foldername,"video*.mp4")))
		num_valid_video_old = len(glob.glob(os.path.join(foldername,"zoom*.mp4")))
		num_valid_video = num_valid_video_old + num_valid_video_new
		num_total_files = len(os.listdir(foldername))

		# if folder name is fine, should check number of video and audio files. if these both fine then can skip!
		if cur_name_bool == 1 and num_valid_audio == 1 and num_valid_video == 1:
			continue

		# otherwise we know we need to actually add the row, append values found to list
		raw_name_list.append(foldername)
		folder_bool_list.append(cur_folder_bool)
		valid_folder_name_bool_list.append(cur_name_bool)
		num_audio_m4a_list.append(num_valid_audio)
		num_video_mp4_list.append(num_valid_video)
		num_top_level_files_list.append(num_total_files)
		date_detected_list.append(today_str)

	# construct CSV now
	values_list = [raw_name_list, folder_bool_list, valid_folder_name_bool_list, num_audio_m4a_list, num_video_mp4_list, num_top_level_files_list, date_detected_list]
	new_df = pd.DataFrame()
	for header,value in zip(column_names, values_list):
		new_df[header] = value

	# can just exit if there is no new info to concat
	if new_df.empty:
		return

	# concat if one already exists, otherwise just save
	output_path = "../" + study + "_" + ptID + "_" + interview_type + "RawInterviewSOPAccountingTable.csv"
	if len(existing_list) > 0:
		join_df = pd.concat([prev_account, new_df])
		join_df.reset_index(drop=True, inplace=True)
		join_df.to_csv(output_path, index=False)
	else:
		new_df.to_csv(output_path, index=False)

if __name__ == '__main__':
	# Map command line arguments to function arguments.
	interview_raw_account(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])
