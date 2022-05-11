#!/usr/bin/env python

import os
import sys
import datetime
import pandas as pd

# final step of video pipeline is to do various file accounting! will merge wtih what was done as part of audio pipeline (on interview date and time variables)
def interview_video_account(interview_type, data_root, study, ptID):
	# start with looking up existing video
	os.chdir(os.path.join(data_root, "PROTECTED", study, "processed", ptID, "interviews", interview_type))
	try:
		prev_account = pd.read_csv(study + "_" + ptID + "_" + interview_type + "InterviewVideoProcessAccountingTable.csv")
		processed_list = prev_account["processed_video_filename"].tolist()
	except:
		processed_list = []	

	# column names list to be used
	column_names = ["interview_date", "interview_time", "processed_video_filename", "video_day", "video_interview_number", "video_process_date"]
	# initialize lists to track all these variables
	interview_date_list = []
	interview_time_list = []
	processed_video_filename_list = []
	video_day_list = []
	video_interview_number_list = []
	video_process_date_list = []

	# there must already be this folder with subfolders in it for wrapping bash script to call the function
	os.chdir(os.path.join(data_root,"PROTECTED", study, "processed", ptID, "interviews", interview_type, "video_frames"))
	cur_folders = os.listdir(".")

	# loop through filename maps now to update records for any newly processed videos
	for foldername in cur_folders:
		if not os.path.exists(foldername + "/" + foldername + ".txt"): # confirm there is an accounting .txt for this video
			print("Missing accounting file for " + foldername + " under " + ptID + " " + interview_type + " - ignoring")
			continue
	
		# line 1 (only line) is renamed file name
		with open(foldername + "/" + foldername + ".txt", 'r') as cur_f:
			line_list = cur_f.readlines()
		video_rename = line_list[0].rstrip()
		# check that this hasn't already been processed using the raw path before proceeding, otherwise skip
		if video_rename in processed_list:
			continue

		# title is date + time
		interview_date = foldername.split("+")[0]
		interview_time = foldername.split("+")[1]
		# get day and interview numbers from within the renamed file name
		day_num = int(video_rename.split("_day")[1].split("_")[0])
		sess_num = int(video_rename.split("_session")[1].split(".")[0])

		# get last modified date of the accounting file too
		last_modified_date = datetime.datetime.fromtimestamp(os.path.getmtime(foldername + "/" + foldername + ".txt")).date().strftime("%Y-%m-%d")

		# now just append to list
		interview_date_list.append(interview_date)
		interview_time_list.append(interview_time)
		processed_video_filename_list.append(video_rename)
		video_day_list.append(day_num)
		video_interview_number_list.append(sess_num)
		video_process_date_list.append(last_modified_date)

	# construct CSV now
	values_list = [interview_date_list, interview_time_list, processed_video_filename_list, video_day_list, video_interview_number_list, video_process_date_list]
	new_df = pd.DataFrame()
	for header,value in zip(column_names, values_list):
		new_df[header] = value

	# can just exit if there is no new info to concat
	if new_df.empty:
		return

	# concat if one already exists, otherwise just save
	output_path = "../" + study + "_" + ptID + "_" + interview_type + "InterviewVideoProcessAccountingTable.csv"
	if len(processed_list) > 0:
		join_df = pd.concat([prev_account, new_df])
		join_df.reset_index(drop=True, inplace=True)
		join_df.to_csv(output_path, index=False)
	else:
		new_df.to_csv(output_path, index=False)

if __name__ == '__main__':
	# Map command line arguments to function arguments.
	interview_video_account(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])
