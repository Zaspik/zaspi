#!/bin/bash
#mount -a
export DOWNLOADS_DIR_LOCAL=/srv/data/$(basename $0 .sh)/
export DOWNLOADS_DIR_VIDEO=/mnt/youtube_video/
export DOWNLOADS_DIR_MUSIC=/mnt/youtube_music/
export TMP_FILE=/tmp/$(basename $0 .sh)
export TMP_FILE_PLAYLIST=/tmp/$(basename $0 .sh)_playlist
PID_FILE=$0"_pid"
SEZNAM_PLAYLIST_VIDEO=("videa_5" )
SEZNAM_PLAYLIST_MUSIC=("hudba_5" "slovo_5" )
YOUTUBE_SITE="https://www.youtube.com/user/MrZaspik"
export PREFIX="https://www.youtube.com"
export STAZENE=stazene.txt
export NESTAZENE=nestazene.txt
export LOG_LEVEL=0
loguj()
{
	LEVEL=$1
	ZPRAVA=$2
	if [ ${LOG_LEVEL} -le ${LEVEL} ]
	then
		case ${LEVEL} in
			0) LEVEL=[DEBUG];;
			1) LEVEL=[INFO];;
			2) LEVEL=[WARN];;
			3) LEVEL=[ERROR];;
		esac
	
	echo $(date +%Y-%m-%d\ %T) ${LEVEL} $USER $$ - ${ZPRAVA}
	fi
	
}

mkdir_dir()
{
	DIR=$1
	if [ ! -d ${DIR} ]
	then
		loguj 1 "Zakladam adresar ${DIR}"
		mkdir ${DIR}
	fi
	
}


parse_playlist_links()
{
	PLAYLIST=$1
	FORMAT=$2
	
	case ${FORMAT} in
		mp3) DOWNLOADS_DIR=${DOWNLOADS_DIR_MUSIC}${PLAYLIST}/;;
		mp4) DOWNLOADS_DIR=${DOWNLOADS_DIR_VIDEO}${PLAYLIST}/;;
	esac
	
	if [ ! -e ${DOWNLOADS_DIR}${STAZENE} ]
	then
		touch ${DOWNLOADS_DIR}${STAZENE}
	fi	

	if [ -e ${DOWNLOADS_DIR}${NESTAZENE} ]
	then
		rm ${DOWNLOADS_DIR}${NESTAZENE}
	fi
		
	loguj 1 "Parsuji url pro playlist ${PLAYLIST}"
	PLAYLIST_URL=$(grep ${PLAYLIST} ${TMP_FILE} | grep href= | sed 's;^.*href=";;g' | sed 's;".*$;;g')
	if [ ${PLAYLIST_URL} ]
	then
		loguj 1 "Stahuji informace playlistu ${PLAYLIST} (${PREFIX}${PLAYLIST_URL})"
		wget ${PREFIX}${PLAYLIST_URL} -O ${TMP_FILE_PLAYLIST}  > /dev/null 2>&1
		loguj 1 "Parsuji kod playlistu ${PLAYLIST}"
		PLAYLIST_CODE=$(echo $PLAYLIST_URL | sed 's;.*=;;g')
		loguj 1 "Parsuji odkazy pro playlist ${PLAYLIST} (${PLAYLIST_CODE})"
		URLS=$(grep -E "<a[^>]*href=\"[^>]*list=${PLAYLIST_CODE}[^>]*>" ${TMP_FILE_PLAYLIST} | sed 's;.*<a[^<]*href=\";;g' | sed 's;&.*;;g' | uniq)
		POCET_V_PLAYLISTU=$(echo ${URLS[*]} | wc -w)
		loguj 1 "Prochazim seznam odkazu v playlistu ${PLAYLIST} (${PLAYLIST_CODE}) pro ${POCET_V_PLAYLISTU} videa (${URLS[*]})"
		for URL in ${URLS[*]}
		do
			loguj 1 "Parsuji kod videa (${URL}) v playlistu ${PLAYLIST}"
			YOUTUBE_CODE=$(echo ${URL} | sed 's;.*=;;g')
			loguj 1 "Kontroluji zda kod videa (${YOUTUBE_CODE}) v playlistu ${PLAYLIST} jiz nebyl stazen"
			if [ $(grep -c "${YOUTUBE_CODE}" ${DOWNLOADS_DIR}${STAZENE}) = 0 ]
			then
				URL=${PREFIX}${URL}				
				KVALITA=$(echo ${PLAYLIST} | awk -F_ '{print $2}')
				loguj 1 "Pro kod videa (${YOUTUBE_CODE}) url ${URL} v playlistu ${PLAYLIST} bude zahajeno stahovani v kvalite ${KVALITA}"
				youtubedl ${DOWNLOADS_DIR} ${URL} ${FORMAT} ${KVALITA} ${YOUTUBE_CODE}
			else
				loguj 1 "Kod videa (${YOUTUBE_CODE}) v playlistu ${PLAYLIST} jiz byl stazen"
			fi
		done
	fi

}


youtubedl()
{
	YOUTUBEDL='/usr/local/bin/youtube-dl --add-metadata' 
	#--restrict-filenames
	MP3='-x --audio-format mp3'
	MP4='--all-subs --sub-format srt --prefer-free-formats'
	CESTA=$1
	ZDROJ=$2
	FORMAT_VSTUP=$(echo $3 | tr '[:upper:]' '[:lower:]')
	KVALITA_VSTUP=$4
	YOUTUBE_CODE=$5

	cd ${DOWNLOADS_DIR_LOCAL}; \
	loguj 1 "Zmena adresare na $PWD"
	case ${KVALITA_VSTUP} in
		[0-9]) KVALITA="--audio-quality ${KVALITA_VSTUP}";;
		*) unset KVALITA;;
	esac
	
	case ${FORMAT_VSTUP} in
		mp3) ${YOUTUBEDL} ${KVALITA} ${MP3} ${ZDROJ};;
		mp4) ${YOUTUBEDL} ${KVALITA} ${MP4} ${ZDROJ};;
		*) loguj 3 "Chyba povolene parametry jsou pouze MP3 nebo MP4";; 
	esac
	
	if [ $PIPESTATUS = 0 ]
	then
		SOUBOR=$(ls ${DOWNLOADS_DIR_LOCAL})
		loguj 1 "Kopiruji ${SOUBOR[*]} z ${DOWNLOADS_DIR_LOCAL} do ${CESTA}"
		mv ${DOWNLOADS_DIR_LOCAL}* ${CESTA}
		echo ${YOUTUBE_CODE} >> ${CESTA}${STAZENE}
		loguj 1 "Kod videa (${YOUTUBE_CODE}) v playlistu ${PLAYLIST} byl pridan na seznam stazenych ${CESTA}${STAZENE}"
	else
		SOUBOR=$(ls ${DOWNLOADS_DIR_LOCAL})
		echo ${URL} >> ${CESTA}${NESTAZENE}
		loguj 3 "Kod videa (${YOUTUBE_CODE}) v playlistu ${PLAYLIST} nebyl stazen z duvodu chyby youtube-dl"
		loguj 1 "Mazu ${SOUBOR[*]} z ${DOWNLOADS_DIR_LOCAL}"
		rm -f ${DOWNLOADS_DIR_LOCAL}*
		
	fi
}

if [ -e ${PID_FILE} ]
then
	PID=$(cat ${PID_FILE})
	if [ $(ps -p ${PID} | grep -c ${PID}) = 0 ]
	then
		echo $$ > ${PID_FILE}
	else
		loguj 2 "Program jiz bezi jako PID ${PID}"
		exit 1
	fi
else
	echo $$ > ${PID_FILE}
fi

rm -f ${DOWNLOADS_DIR_LOCAL}/*

loguj 1 "Stahuji informace site uzivatele (${YOUTUBE_SITE})"
wget ${YOUTUBE_SITE} -O ${TMP_FILE}  > /dev/null 2>&1


loguj 1 "Zacinam prochazet seznam playlistu pro videa (${SEZNAM_PLAYLIST_VIDEO[*]})"
for PLAYLIST in ${SEZNAM_PLAYLIST_VIDEO[*]}
do
	mkdir_dir ${DOWNLOADS_DIR_VIDEO}${PLAYLIST}
	parse_playlist_links ${PLAYLIST} mp4 	
done

loguj 1 "Zacinam prochazet seznam playlistu pro hudbu (${SEZNAM_PLAYLIST_MUSIC[*]})"
for PLAYLIST in ${SEZNAM_PLAYLIST_MUSIC[*]}
do
	mkdir_dir ${DOWNLOADS_DIR_MUSIC}${PLAYLIST}
	parse_playlist_links ${PLAYLIST} mp3
done

loguj 1 "Mazu zamek spusteneho skriptu"
rm ${PID_FILE}
exit 0
