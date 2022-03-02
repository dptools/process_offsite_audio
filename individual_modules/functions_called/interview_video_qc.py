#!/usr/bin/env python

import os
import sys
import datetime
import pandas as pd
import numpy as np
import glob

# new imports for video
import cv2
from feat import Detector

# run video QC on the newly extracted frames, also handling the file name map for videos here
def interview_video_qc(interview_type, data_root, study, ptID):
	# if can't find valid metadata info for the patient, can't move forward here
	try:
		study_metadata_path = os.path.join(data_root,"GENERAL",study,study + "_metadata.csv")
		study_metadata = pd.read_csv(study_metadata_path)
		patient_metadata = study_metadata[study_metadata["Subject ID"] == ptID]
		consent_date_str = patient_metadata["Consent"].tolist()[0]
		consent_date = datetime.datetime.strptime(consent_date_str,"%Y-%m-%d")
	except:
		# occasionally we encounter issues with the study metadata file, so adding a check here
		print("No consent date information in the study metadata CSV for input patient " + ptID + ", or problem with input arguments")
		return

	# start by looking for new files to process
	try:
		os.chdir(os.path.join(data_root,"PROTECTED", study, "processed", ptID, "interviews", interview_type, "video_frames"))
	except:
		# should generally not reach this error if calling from main pipeline bash script
		print("Haven't extracted any video frames yet for input patient " + ptID + " " + interview_type + ", or problem with input arguments") 
		return

	cur_folders = os.listdir(".")
	if len(cur_folders) == 0:
		# should generally not reach this error if calling from main pipeline bash script
		print("Haven't extracted any video frames yet for input patient " + ptID + " " + interview_type + ", or problem with input arguments") 
		return

	# get any the folders that don't have PyFeat outputs for their frames yet
	cur_folders_unprocessed = [x for x in cur_folders if not os.path.isdir(x + "/PyFeatOutputs")]
	if len(cur_folders_unprocessed) == 0:
		print("No new videos for input patient " + ptID + " " + interview_type)
		return
	# go in chronological order
	cur_folders_unprocessed.sort()

	# set up PyFeat
	detector = Detector() # ok to use default models for this

	# loop through folders to actually process, keeping track of bare bones features for now
	num_frames = []
	min_faces_in_frame = []
	max_faces_in_frame = []
	mean_faces_in_frame = []
	mean_face_confidence = []
	for folder in cur_folders_unprocessed:
		os.chdir(folder)
		os.mkdir("PyFeatOutputs")
		# set up lists for tracking within this interview
		frames_count = 0
		face_nums_list = []
		face_conf_list = []
		for file in os.listdir("."):
			if not file.endswith(".jpg"):
				# only process images
				continue
			try:
				# actually load in the image
				cur_image = cv2.imread(file)
				# run PyFeat
				image_results = detector.detect_image(cur_image)
			except:
				print("Problem running PyFeat on frame " + file + " - it will be excluded from stats for " + folder)
				continue
			# save only the most relevant features for QC for right now
			image_core_faces = image_results.facebox()
			image_core_faces["face_number"] = range(image_core_faces.shape[0])
			# one file per image
			image_core_faces.to_csv("PyFeatOutputs/" + file.split(".")[0] + ".csv", index=False)
			# increment stats now
			frames_count = frames_count + 1
			face_nums_list.append(image_core_faces.shape[0])
			face_conf_list.extend(image_core_faces["FaceScore"].tolist())
		# add to overall list for this interivew
		num_frames.append(frames_count)
		min_faces_in_frame.append(np.min(face_nums_list))
		max_faces_in_frame.append(np.max(face_nums_list))
		mean_faces_in_frame.append(np.mean(face_nums_list))
		mean_face_confidence.append(np.mean(face_conf_list))
		# back out of folder before continuing loop
		os.chdir("..") 

	# initialize DF with current stats
	new_df = pd.DataFrame()
	new_df["raw_filename"] = cur_folders_unprocessed
	new_df["number_extracted_frames"] = num_frames
	new_df["minimum_faces_detected_in_frame"] = min_faces_in_frame
	new_df["maximum_faces_detected_in_frame"] = max_faces_in_frame
	new_df["mean_faces_detected_in_frame"] = mean_faces_in_frame
	new_df["mean_face_confidence_score"] = mean_face_confidence

	# now need to add metadata columns to the csv using the raw filename parameter
	# first specify column headers for final DPDash CSV
	headers=["reftime","day","timeofday","weekday","study","patient","interview_number",
			 "number_extracted_frames","minimum_faces_detected_in_frame","maximum_faces_detected_in_frame","mean_faces_detected_in_frame", "mean_face_confidence_score"]
	# initialize lists to fill in df
	# reftime column will leave blank so can just make it np.nan at the end
	study_days = []
	times = []
	week_days = []
	# study and patient list will be same thing n times, so just do at end
	int_nums=[]

	# if reach this point, there should definitely be corresponding raw audio folders - need that list to find the interview number
	raw_folder_paths = os.listdir(os.path.join(data_root, "PROTECTED", study, "raw", ptID, "interviews", interview_type))
	raw_folder_names_int = [x.split("/")[-1] for x in raw_folder_paths]
	# keep only files that seem to meet the convention, also know they will always be Zoom to have video
	raw_folder_names = [x for x in raw_folder_names_int if (os.path.isdir(os.path.join(data_root, "PROTECTED", study, "raw", ptID, "interviews", interview_type, x)) and len(x.split(" ")) > 1 and len(x.split(" ")[0]) == 10 and len(x.split(" ")[1]) == 8)] 
	raw_folder_names.sort() # the way zoom puts date/time in text in the folder name means it will always sort in chronological order
	raw_video_formatted = [x.split(" ")[0] + "+" + x.split(" ")[1] for x in raw_folder_names]

	# now use compiled info to get the metadata needed
	for folder in cur_folders_unprocessed:
		# interview number
		session_num = raw_video_formatted.index(folder) + 1
		int_nums.append(session_num)

		# day number
		date_str = folder.split("+")[0]
		cur_date = datetime.datetime.strptime(date_str,"%Y-%m-%d")
		day_num = (cur_date - consent_date).days + 1 # study day starts at 1 on day of consent
		study_days.append(day_num)

		# weekday encoding
		cur_weekday = datetime.datetime.strptime(date_str,"%Y-%m-%d").weekday()
		dpdash_weekday = ((cur_weekday + 2) % 7) + 1 # dpdash requires 1 through 7, with 1 being Saturday, so it is different than standard datetime convention
		week_days.append(dpdash_weekday)

		# time of day
		time_str = cur_name.split(" ")[1]
		final_time = ":".join(time_str.split("."))
		times.append(final_time)
	# final static columns
	studies = [study for x in range(len(study_days))]
	patients = [ptID for x in range(len(study_days))]
	ref_times = [np.nan for x in range(len(study_days))]

	# add the columns to the df
	new_df["reftime"] = ref_times
	new_df["day"] = study_days
	new_df["timeofday"] = times
	new_df["weekday"] = week_days
	new_df["study"] = studies
	new_df["patient"] = patients
	new_df["interview_number"] = int_nums
	# make sure columns in right order and drop the PII date column
	new_df = new_df[headers]

	# now prepare to save new CSV for this patient (or update existing CSV if there is one)
	os.chdir(os.path.join(data_root, "GENERAL", study, "processed", ptID, "interviews", interview_type))
	# find if there are existing CSVs for this particular subject/type videos
	output_path_format = study+"-"+ptID+"-interviewVideoQC_" + interview_type + "-day*.csv"
	output_paths = glob.glob(output_path_format)
	# single existing DPDash file is expected - do concatenation and then delete old version (since naming convention will not overwrite)
	if len(output_paths) == 1:
		old_df = pd.read_csv(output_paths[0])
		join_csv=pd.concat([old_df, new_csv])
		join_csv.reset_index(drop=True, inplace=True)
		# drop any duplicates in case audio got decrypted a second time - shouldn't happen via pipeline
		join_csv.drop_duplicates(subset=["patient", "day", "timeofday"],inplace=True)
		join_csv.sort_values(by=["day","timeofday"],inplace=True) # make sure concatenated CSV is still sorted primarily by day number and secondarily by time
		output_path_cur = study + "-" + ptID + "-interviewVideoQC_" + interview_type + "-day" + str(join_csv["day"].tolist()[0]) + "to" + str(join_csv["day"].tolist()[-1]) + '.csv'
		join_csv.to_csv(output_path_cur,index=False)
		return # function is now done if we are in the single existing dp dash case
	# print warning if more than 1 for this patient
	if len(output_paths) > 1:
		print("Warning - multiple DPDash CSVs exist for patient " + ptID + ". Saving current CSV separately for now")
	# with 0 or more than 1, just save this as is
	output_path_cur = study + "-" + ptID + "-interviewVideoQC_" + interview_type + "-day" + str(study_days[0]) + "to" + str(study_days[-1]) + '.csv'
	new_csv.to_csv(output_path_cur,index=False)

if __name__ == '__main__':
    # Map command line arguments to function arguments.
    interview_video_qc(sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4])