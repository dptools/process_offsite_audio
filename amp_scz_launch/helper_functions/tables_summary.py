import os
import sys
import pandas as pd
import numpy as np
from datetime import date

def html_df_helper(df,df_header):
	df_html = df.to_html()
	render = "<html><head><style>h3 {text-align: center;}</style></head><body class=\"rendered_html\"> <link rel=\"stylesheet\" href=\"https://cdn.jupyter.org/notebook/5.1.0/style/style.min.css\">" + "<h3>" + df_header + "</h3>" + df_html + "</body></html>"
	return render

def run_summary_operation_tables(input_csv,output_folder,cur_server):
	input_df = pd.read_csv(input_csv)
	input_df["total_words"] = input_df["num_words_S1"] + input_df["num_words_S2"] + input_df["num_words_S3"] # note if num subjects > 3 this will be off though
	input_df["total_turns"] = input_df["num_turns_S1"] + input_df["num_turns_S2"] + input_df["num_turns_S3"] # note if num subjects > 3 this will be off though
	input_df["inaudible_per_word"] = input_df["num_inaudible"]/input_df["total_words"]
	input_df["redacted_per_word"] = input_df["num_redacted"]/input_df["total_words"]

	cur_date = date.today().strftime("%m/%d/%Y")

	final_table_counts = input_df[["study","interview_type","patient","overall_db","mean_face_area","total_words"]].groupby([pd.Categorical(input_df.study),"interview_type"]).count().fillna(0).astype(int)
	final_table_counts.rename(columns={"patient":"processed_interviews_count-any_modality","overall_db":"processed_audio_count","mean_face_area":"processed_video_count","total_words":"processed_transcript_count"},inplace=True)
	
	inaud_filt = input_df[input_df["inaudible_per_word"]<0.01]
	good_qual_count = inaud_filt[["study", "interview_type", "inaudible_per_word"]].groupby([pd.Categorical(inaud_filt.study),"interview_type"]).count().rename(columns={"inaudible_per_word":"good_transcript_quality_count"})

	inaud_filt_partial = input_df[(input_df["inaudible_per_word"]>=0.01)&(input_df["inaudible_per_word"]<0.05)]
	partial_qual_count = inaud_filt_partial[["study", "interview_type", "inaudible_per_word"]].groupby([pd.Categorical(inaud_filt_partial.study),"interview_type"]).count().rename(columns={"inaudible_per_word":"partial_transcript_quality_count"})

	faces_filt = input_df[(input_df["mean_faces_detected_in_frame"]>1.8) & (input_df["mean_faces_detected_in_frame"]<2.3)]
	good_face_count = faces_filt[["study", "interview_type", "mean_faces_detected_in_frame"]].groupby([pd.Categorical(faces_filt.study),"interview_type"]).count().rename(columns={"mean_faces_detected_in_frame":"good_video_quality_count"})

	faces_filt_partial = input_df[((input_df["mean_faces_detected_in_frame"]>1.1) & (input_df["mean_faces_detected_in_frame"]<=1.8)) | (input_df["mean_faces_detected_in_frame"]>=2.3)]
	partial_face_count = faces_filt_partial[["study", "interview_type", "mean_faces_detected_in_frame"]].groupby([pd.Categorical(faces_filt_partial.study),"interview_type"]).count().rename(columns={"mean_faces_detected_in_frame":"partial_video_quality_count"})

	all_counts = final_table_counts.merge(good_qual_count, how="outer", left_index=True, right_index=True).merge(good_face_count, how="outer", left_index=True, right_index=True).merge(partial_qual_count, how="outer", left_index=True, right_index=True).merge(partial_face_count, how="outer", left_index=True, right_index=True)
	formatted_table = all_counts[["processed_interviews_count-any_modality","processed_video_count","good_video_quality_count","partial_video_quality_count","processed_audio_count","processed_transcript_count","good_transcript_quality_count","partial_transcript_quality_count"]].fillna(0).astype(int)

	mean_lengths = input_df[["study","interview_type","length_minutes"]].groupby([pd.Categorical(input_df.study),"interview_type"]).mean()
	mean_lengths["mean_interview_audio_minutes"] = [round(x,2) for x in mean_lengths["length_minutes"].tolist()]
	mean_lengths.drop(columns=["length_minutes"],inplace=True)
	table_addendum = formatted_table.merge(mean_lengths, how="outer", left_index=True, right_index=True)

	abbrev_table = table_addendum[["processed_interviews_count-any_modality","good_video_quality_count","partial_video_quality_count","good_transcript_quality_count","partial_transcript_quality_count","mean_interview_audio_minutes"]]
	abbrev_table = abbrev_table.rename(columns={"processed_interviews_count-any_modality":"processed_interviews_count"})

	full_header = cur_server + " Expanded AVL QC Counts (Data as of " + cur_date + ")"
	abbrev_header = cur_server + " Key AVL QC Stats (Data as of " + cur_date + ")"
	full_txt = html_df_helper(table_addendum,full_header)
	abbrev_txt = html_df_helper(abbrev_table,abbrev_header)

	my_file = open(os.path.join(output_folder,'extended-counts-table.html'), 'w')
	my_file.write(full_txt)
	my_file.close()

	my_file = open(os.path.join(output_folder,'key-stats-table-by-site-and-type.html'), 'w')
	my_file.write(abbrev_txt)
	my_file.close()

if __name__ == '__main__':
	# Map command line arguments to function arguments
	run_summary_operation_tables(sys.argv[1], sys.argv[2], sys.argv[3])