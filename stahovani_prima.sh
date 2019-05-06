#!/bin/bash

export DOWNLOADS_DIR_LOCAL=/srv/data/$(basename $0 .sh)/
export DOWNLOADS_DIR_VIDEO=/mnt/prima_video/
export TMP_FILE=/tmp/$(basename $0 .sh)
export TMP_FILE_PORAD=/tmp/$(basename $0 .sh)_porad
PID_FILE=$0"_pid"
SITE="https://raw.githubusercontent.com/Zaspik/doc/master/prima.txt"

export PREFIX="http://"
export POSTFIX=""
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
	PORAD_URL=$1$POSTFIX
	FORMAT=mp4
	PORAD_NAME=$2
	DOWNLOADS_DIR=${DOWNLOADS_DIR_VIDEO}${PORAD_NAME}/
	echo ${DOWNLOADS_DIR}

	if [ ! -e ${DOWNLOADS_DIR}${STAZENE} ]
	then
		touch ${DOWNLOADS_DIR}${STAZENE}
	fi	

	if [ -e ${DOWNLOADS_DIR}${NESTAZENE} ]
	then
		rm ${DOWNLOADS_DIR}${NESTAZENE}
	fi
	
	loguj 1 "Stahuji informace pro porad ${PORAD_NAME} (${PORAD_URL})"
	wget ${PORAD_URL} -O ${TMP_FILE_PORAD} > /dev/null 2>&1

	loguj 1 "Parsuji odkazy pro porad ${PORAD_NAME} "
	URLS=$(grep -E  'hover-preview' ${TMP_FILE_PORAD} | sed 's;^.*//;;g' | sed 's;\".*$;;g' | uniq)
	POCET_V_PORADU=$(echo ${URLS[*]} | wc -w)
	
	
	loguj 1 "Prochazim seznam odkazu v poradu ${PORAD_NAME} (${PORAD_URL}) pro ${POCET_V_PORADU} videa (${URLS[*]})"
	for URL in ${URLS[*]}
	do
		loguj 1 "Parsuji kod videa (${URL}) v poradu ${PORAD_NAME}"
		CODE=$(echo ${URL} | sed 's;^.*/;;g')
		loguj 1 "Kontroluji zda kod videa (${CODE}) poradu ${PORAD} jiz nebyl stazen"
		if [ $(grep -c "${CODE}" ${DOWNLOADS_DIR}${STAZENE}) = 0 ]
		then
			URL=${PREFIX}${URL}
			loguj 1 "Pro kod videa (${CODE}) url ${URL} v poradu ${PORAD_NAME} bude zahajeno stahovani"
			youtubedl ${DOWNLOADS_DIR} ${URL} ${FORMAT} ${CODE}
		else
			loguj 1 "Kod videa (${CODE}) v poradu ${PORAD_NAME} jiz byl stazen"
		fi
	done

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
	KVALITA_VSTUP=$5
	CODE=$4

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
		echo ${CODE} >> ${CESTA}${STAZENE}
		loguj 1 "Kod videa (${CODE}) v poradu ${PORAD_NAME} byl pridan na seznam stazenych ${CESTA}${STAZENE}"
	else
		SOUBOR=$(ls ${DOWNLOADS_DIR_LOCAL})
		echo ${URL} >> ${CESTA}${NESTAZENE}
		loguj 3 "Kod videa (${CODE}) v poradu ${PORAD_NAME} nebyl stazen z duvodu chyby youtube-dl"
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

loguj 1 "Stahuji seznam odkazu (${SITE})"
wget ${SITE} -O ${TMP_FILE} > /dev/null 2>&1


loguj 1 "Zacinam prochazet seznam poradu"
for PORAD in $(cat ${TMP_FILE} )
do
	PORAD_NAME=$(echo ${PORAD} |  sed 's;^.*/;;g')

	mkdir_dir ${DOWNLOADS_DIR_VIDEO}${PORAD_NAME}
	parse_playlist_links ${PORAD} ${PORAD_NAME} 	
done

loguj 1 "Mazu zamek spusteneho skriptu"
rm ${PID_FILE}
exit 0
