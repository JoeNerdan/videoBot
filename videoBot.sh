#!/bin/bash

preview_mode=false

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -preview)
            preview_mode=true
            shift
            ;;
        *)
            input_file="$1"
            shift
            ;;
    esac
done

if [ -z "$input_file" ]; then
    echo "Please provide a video file as an argument."
    exit 1
fi

filename=$(basename -- "$input_file")
filename_noext="${filename%.*}"

if [ "$preview_mode" = true ]; then
    echo "Running in preview mode..."
    whisper_model="tiny"
    ffmpeg_preset="ultrafast"
    crf_value="48"
    output_suffix=".preview.mp4"
else
    echo "Running in high-quality mode..."
    whisper_model="medium"
    ffmpeg_preset="slow"
    crf_value="18"
    output_suffix=".mp4"
fi

echo "Generating subtitles..."
whisper-ctranslate2 "$input_file" --model $whisper_model --output_format srt --word_timestamps true --highlight_words true --max_words_per_line 5 

add_subtitles() {
    local input_file="$1"
    local output_file="$2"
    local subtitle_file="$3"
    local is_portrait="$4"

    # Get video dimensions
    width=$(ffprobe -v error -select_streams v:0 -show_entries stream=width -of default:noprint_wrappers=1 "$input_file")
    height=$(ffprobe -v error -select_streams v:0 -show_entries stream=height -of default:noprint_wrappers=1 "$input_file")

    if [ "$width" -gt "$height" ]; then
        # Landscape video
        ffmpeg -i "$input_file" -vf "subtitles=$subtitle_file:force_style='Fontname=Roboto,FontSize=28,PrimaryColour=&HFFFFFF&,OutlineColour=&H000000&,BorderStyle=2,ShadowColour=&H000000&,ShadowYOffset=2'" -c:v h264 -preset $ffmpeg_preset -crf $crf_value -c:a copy "$output_file"
    else
        # Portrait video (YouTube Shorts/TikTok style)
        ffmpeg -i "$input_file" -vf "subtitles=$subtitle_file:force_style='Fontname=Roboto,Fontsize=20,Bold=1,Alignment=2,MarginV=40,PrimaryColour=&H00FFFFFF&,OutlineColour=&H00000000&,BorderStyle=2,Outline=2,Shadow=0'" -c:v h264 -preset $ffmpeg_preset -crf $crf_value -c:a copy "$output_file"
    fi
}

echo "Adding subtitles to original video..."
add_subtitles "$input_file" "${filename_noext}_subtitled${output_suffix}" "${filename_noext}.srt"

echo "Creating portrait version with subtitles..."
ffmpeg -i "$input_file" -vf "scale=3840:2160,crop=1216:2160:1312:0,scale=608:1080,subtitles=${filename_noext}.srt:force_style='Fontname=Roboto,Fontsize=24,Bold=1,Alignment=2,MarginV=40,PrimaryColour=&H00FFFFFF&,OutlineColour=&H00000000&,BorderStyle=2,Outline=2,Shadow=0'" -c:v h264 -preset $ffmpeg_preset -crf $crf_value -c:a copy "${filename_noext}_portrait_subtitled${output_suffix}"

echo "All tasks completed!"
