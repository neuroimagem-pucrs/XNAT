#!/bin/bash

AET=LAD_MARFIM
AET_PORT=11112
AEC=PIXSERVERINSCER
PACS_PORT=4200
PACS=marfim.lad.pucrs.br
LOG_CFG=/home/zeosmar/log2file.cfg
DIR=$(pwd)

echo "###################################################"
echo "## Aviso: Recomenda-se utilizar o 'screen' para  ##"
echo "## fazer o download de imagens devido ao tempo   ##"
echo "## que pode levar. As imagens serão baixadas no  ##"
echo "## diretório dicom criado automaticamente no     ##"
echo "## mesmo local onde o script for executado.      ##"
echo "## Aviso 2: Envio para o XNAT diponível apenas   ##"
echo "## para download de exames completos e com       ##"
echo "## projeto pré-existente.                        ##"
echo "###################################################"


printf "\nO que deseja fazer?\n"
PS3='Escolha uma opção: '
options=("Pesquisar por nome." "Pesquisar por data." "Pesquisar por número." "Encerrar.")
#ESSAS OPÇÕES PRECISAM SER IGUAIS ÁS DE BAIXO PRA FUNCIONAR DIREITO.
select opt in "${options[@]}"
do
    case $opt in
        "Pesquisar por nome.")
        echo -n "Digite o nome: "
		read paciente
		findscu -S -aec $AEC -aet $AET $PACS $PACS_PORT -k QueryRetrieveLevel=PATIENT -k PatientName="$paciente" \
		-k StudyDate -k StudyDescription -k AccessionNumber -k StudyInstanceUID --log-config $LOG_CFG
		break
            ;;
        "Pesquisar por data.")
		echo -n "Digite a data (DD/MM/YYYY): "
		read data
		data_formatada=`echo $data | awk 'BEGIN{FS=OFS="/"}{print $3,$2,$1}'`
		findscu -S -aec $AEC -aet $AET $PACS $PACS_PORT -k QueryRetrieveLevel=PATIENT -k PatientName \
		-k StudyDate=${data_formatada///} -k StudyDescription -k AccessionNumber -k StudyInstanceUID --log-config $LOG_CFG
		break
            ;;
        "Pesquisar por número.")
        echo -n "Digite o número: "
		read acc_number
		findscu -S -aec $AEC -aet $AET $PACS $PACS_PORT -k QueryRetrieveLevel=PATIENT -k PatientName \
		-k StudyDate -k StudyDescription -k AccessionNumber=$acc_number -k StudyInstanceUID --log-config $LOG_CFG
		break
            ;;
        "Encerrar.")
        exit 0
            ;;
        *) echo Opção inválida;;
    esac
done

printf "\nPesquisando...\n"

#OS COMANDOS "findscu" USADOS NESSE SCRIPT LEVAM A FLAG "--log-config" QUE INDICA O CAMINHO ATÉ O ARQUIVO
#"log2file.cfg" QUE FOI EDITADO PARA FAZER COM QUE AO INVÉS DO COMANDO MOSTRAR NO TERMINAL OS RESULTADOS,
#ELE COSPE TUDO DENTRO DE UM ARQUIVO CHAMADO "dcmtk.log" GERADO NO LOCAL ONDE O SCRIPT FOR EXECUTADO.
#ESSA FOI A SOLUÇÃO QUE ENCONTREI JÁ QUE O "findscu" NÃO FUNCIONA DESSA FORMA: "findscu ... >> log.txt" 


OLDIFS=$IFS	#ISSO AQUI É NECESSÁRIO SEMPRE QUE EU PRETENDO ATUALIZAR OS ELEMENTOS DE UM ARRAY
IFS=$'\n'	#QUE JÁ CONTEM VALORES NELE... COISA DO BASH, NÃO ME PERGUNTE. NO CASO, O ARRAY "numero"
		#É O QUE PRETENDO ATUALIZAR EM BREVE.

#COLETA DE DADOS DO "dcmtk.log" GERADO
lista_pacientes=($(cat dcmtk.log | sed -n '/(0010,0010)/p' | cut -f 2 -d '[' | cut -f 1 -d ']' | sed 1d))
ano_aquisicao=($(cat dcmtk.log | sed -n '/(0008,0020)/p' | cut -f 2 -d '[' | cut -f 1 -d ']' | sed 1d | cut -c 1-4))
mes_aquisicao=($(cat dcmtk.log | sed -n '/(0008,0020)/p' | cut -f 2 -d '[' | cut -f 1 -d ']' | sed 1d | cut -c 5-6))
dia_aquisicao=($(cat dcmtk.log | sed -n '/(0008,0020)/p' | cut -f 2 -d '[' | cut -f 1 -d ']' | sed 1d | cut -c 7-8))
estudo=($(cat dcmtk.log | sed -n '/(0008,1030)/p' | cut -f 2 -d '[' | cut -f 1 -d ']' | sed 1d))
#"numero" COLETA OS ACCESSION NUMBERS DOS PACIENTES ENCONTRADOS (SE HOUVER)
numero=($(cat dcmtk.log | sed -n '/(0008,0050)/p' | cut -f 2 -d '[' | cut -f 1 -d ']' | sed 1d))
#"UID" COLETA OS "StudyInstanceUID" DOS PACIENTES ENCONTRADOS (ESSE SEMPRE TEM!)
uid=($(cat dcmtk.log | sed -n '/(0020,000d)/p' | cut -f 2 -d '[' | cut -f 1 -d ']' | sed 1d))

#PEGA O NÚMERO TOTAL DE PACIENTES ENCONTRADOS
total_pacientes=${#lista_pacientes[@]}


if [[ $total_pacientes == 0 ]]; then
	printf "\nNenhum resultado foi encontrado.\n Verifique se os dados informados estão corretos.\n"
	exit 0
fi

#FUNÇÃO QUE PREENCHE O ARRAY "numero" (QUE DEVERIA CONTER O ACCESSION NUMBER DO PACIENTE) COM "#"
#CASO "numero" ESTEJA VAZIO (ISSO QUER DIZER QUE NÃO FOI REGISTRADO UM ACCESSION NUMBER PARA O
#PACIENTE NO MOMENTO DO EXAME). PEGUEI ESSA FUNÇÃO DO GOOGLE, NÃO ME PERGUNTE.
IFS=$OLDIFS
update_array() {
	x=0
	variavel=$1[@]
	a=("${!variavel}")
	for i in "${a[@]}" ; do
		if [[ $i =~ "value" ]]; then
			declare -g $1[$x]="#######"
		fi
	((x++))
	done
}

update_array numero


#PRINTAÇÃO DE TERMINAL
printf "\n\n%d resultado(s) encontrado(s).\n" "${total_pacientes}"
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' - #PREENCHE O TERMINAL COM -------
printf "N° %-21s%-12s%-22s%s\n" "NOME" "DATA" "ESTUDO" "NÚMERO"
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
#COMO EM BASH OS ARRAYS INICIAM DA POSIÇÃO 0, AQUI EU ENGANO O USUÁRIO PRA PRINTAR
#NO TERMINAL COMO SE INICIASSE COM 1 (O LOOP SÓ SERVE PRA SHIFTAR OS RESULTADOS EM 1)
for (( i=0; i<${total_pacientes}; i++ ));
do
  printf "%-3d%-20.20s%3.2s/%2.2s/%-6.4s%-21.21s%8.7s\n" "$((i+1))" "${lista_pacientes[$i]}" "${dia_aquisicao[$i]}" "${mes_aquisicao[$i]}" "${ano_aquisicao[$i]}" "${estudo[$i]}" "${numero[$i]}"
done


printf "\nEscolha um resultado: "
read resultado
((resultado--))	#AQUI EU DESFAÇO A ENGANAÇÃO SE NÃO PEGO O RESULTADO
		#ERRADO. DIMINUO 1 DO RESULTADO ESCOLHIDO PELO USUÁRIO

OLDIFS=$IFS	#COISA DO BASH, É NECESSÁRIO PARA ATUALIZAR ARRAYS COM NOVOS VALORES,
IFS=$'\n'	#NÃO ME PERGUNTE O MOTIVO DO PORQUE ISSO É NECESSÁRIO SEMPRE.

#ESSE IF SÓ SERVE PRA GERAR UM NOVO "dcmtk.log" CONTENDO AS SÉRIES DO PACIENTE ESCOLHIDO.
#E SE O ACCESSION NUMBER CONTEM "#", ELE UTILIZA A OPÇÃO "StudyInstanceUID" PRA IDENTIFICAR
#O EXAME SUJEITO. AMBOS CONTEM A FLAG "SeriesInstanceUID" QUE VAI CUSPIR OUTRO TIPO DE UID
#RESPONSÁVEL POR IDENTIFICAR AS RESPECTIVAS SÉRIES QUE FORAM FEITAS NO EXAME. ISSO VAI SER
#ÚTIL CASO O USUÁRIO DESEJE BAIXAR APENAS UMA SÉRIE EM ESPECÍFICO.

if [[ ${numero[$resultado]} =~ "#" ]]; then
	findscu -S -aec $AEC -aet $AET $PACS $PACS_PORT -k QueryRetrieveLevel=SERIES -k StudyDate -k StudyDescription -k StudyInstanceUID=${uid[$resultado]} -k SeriesDescription -k SeriesNumber -k SeriesInstanceUID -k SeriesTime --log-config $LOG_CFG
	numero_paciente=${uid[$resultado]}
else
	findscu -S -aec $AEC -aet $AET $PACS $PACS_PORT -k QueryRetrieveLevel=SERIES -k StudyDate -k StudyDescription -k AccessionNumber=${numero[$resultado]} -k SeriesDescription -k SeriesNumber -k SeriesInstanceUID -k SeriesTime --log-config $LOG_CFG
	numero_paciente=${numero[$resultado]}
fi

#COLETA DE DADOS DO "dcmtk.log" GERADO
ano=`cat dcmtk.log | sed -n '/(0008,0020)/p' | cut -f 2 -d '[' | cut -f 1 -d ']' | sed 1d | cut -c 1-4 | tail -1`
mes=`cat dcmtk.log | sed -n '/(0008,0020)/p' | cut -f 2 -d '[' | cut -f 1 -d ']' | sed 1d | cut -c 5-6 | tail -1`
dia=`cat dcmtk.log | sed -n '/(0008,0020)/p' | cut -f 2 -d '[' | cut -f 1 -d ']' | sed 1d | cut -c 7-8 | tail -1`
lista_series=($(cat dcmtk.log | sed -n '/(0008,103e)/p' | cut -f 2 -d '[' | cut -f 1 -d ']' | sed 1d))
numero_series=($(cat dcmtk.log | sed -n '/(0020,0011)/p' | cut -f 2 -d '[' | cut -f 1 -d ']' | sed 1d))
uid_series=($(cat dcmtk.log | sed -n '/(0020,000e)/p' | cut -f 2 -d '[' | cut -f 1 -d ']' | sed 1d))
series_time=($(cat dcmtk.log | sed -n '/(0008,0031)/p' | cut -f 2 -d '[' | cut -f 1 -d ']' | sed 1d))
IFS=$OLDIFS #OLHA ELE DE NOVO, NÃO ME PERGUNTE.
IFS=$'\n' series_time_com_ponto=($(sed 's/..\B/&:/g' <<<"${series_time[*]}")) #COLOCO OS ":" NAS HORAS

#ESSA PARTE VAI GERAR O ARRAY "lista_series_completo", CONCATENANDO "numero_series" E
#"lista_series". O RESULTADO DISSO É UM ARRAY NESSE MODELO:
# 3  MOTOR
# 1  LOC
# 5  AXI 3D
#SIM, ELE CRIA FORA DE ORDEM, PORQUE NO dcmtk.log ESTÁ FORA DE ORDEM, DEPOIS EU ORDENO.
total_lista_series=${#lista_series[@]}
for ((i=0;i<total_lista_series;i++)); do
    movescu -O -lc $LOG_CFG -aec $AEC -aet $AET $PACS $PACS_PORT -k QueryRetrieveLevel=SERIES -k SeriesInstanceUID=${uid_series[i]}
    lista_imgs[i]=`grep -oP "Remaining Suboperations       :\s+\K\w+"  dcmtk.log`
    lista_imgs_completo[i]="${numero_series[i]}:${lista_imgs[i]} ${series_time_com_ponto[i]}"
    lista_series_completo[i]="${numero_series[i]}:${lista_series[i]} ${series_time_com_ponto[i]}"
    lista_series_time_sem_ponto[i]="${numero_series[i]}:${series_time[i]}"
    lista_series_time_completo[i]="${numero_series[i]}:${series_time_com_ponto[i]}"
    lista_uid[i]="${numero_series[i]}:${uid_series[i]} ${series_time_com_ponto[i]}"
done

IFS=$'\n' lista_numero_series_ordenado=($(sort -n <<<"${numero_series[*]}"))
IFS=$'\n' lista_uid_ordenado=($(sort -n -k 1,1 -k 3,3 <<<"${lista_uid[*]}"))
IFS=$'\n' lista_uid_ordenado_sem_hora=($(sed 's/.\{8\}$//' <<<"${lista_uid_ordenado[*]}")) #REMOVO HORA
IFS=$'\n' lista_uid_ordenado_sem_nada=($(sed 's/^[^:]*://g' <<<"${lista_uid_ordenado_sem_hora[*]}")) #REMOVO NUMERAÇÃO DE SERIE

IFS=$'\n' lista_imgs_ordenado=($(sort -k 1,1 -n -k 3,3 <<<"${lista_imgs_completo[*]}")) #ORDENO O "lista_imgs_completo"
IFS=$'\n' lista_imgs_ordenado_sem_horas=($(sed 's/.\{8\}$//' <<<"${lista_imgs_ordenado[*]}")) #ORDENO O "lista_imgs_completo"
IFS=$'\n' lista_imgs_ordenado_sem_nada=($(sed 's/^[^:]*://g' <<<"${lista_imgs_ordenado_sem_horas[*]}"))

IFS=$'\n' lista_series_time_ordenado=($(sort -n -k 1,1 -k 2,2 <<<"${lista_series_time_completo[*]}")) #ORDENO O lista_serie com ponto
IFS=$'\n' lista_series_time=($(sed 's/^[^:]*://g' <<<"${lista_series_time_ordenado[*]}"))

IFS=$'\n' lista_series_time_sem_ponto_ordenado=($(sort -n -k 1,1 -k 2,2 <<<"${lista_series_time_sem_ponto[*]}"))
IFS=$'\n' lista_series_time_sem_nada=($(sed 's/^[^:]*://g' <<<"${lista_series_time_sem_ponto_ordenado[*]}"))

#PRINTAÇÃO DE TERMINAL
line='----------------------------------------'
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
printf "%s - Nº %s\n" "${lista_pacientes[$resultado]}" "${numero_paciente}"
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
printf "%-4s %-4s %-34s %-20s %-15s\n" "Nº" "SEQ." "DESCRIÇÃO" "HORA" "TOTAL DE IMAGENS"
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
#ORDENO O "lista_series_completo" AGORA
IFS=$'\n' lista_series_completo_ordenado=($(sort -n -k 1,1 -k 3,3 <<<"${lista_series_completo[*]}"))
IFS=$'\n' lista_series_completo_ordenado_sem_hora=($(sed 's/.\{8\}$//' <<<"${lista_series_completo_ordenado[*]}"))
IFS=$'\n' lista_series_completo_ordenado_sem_num=($(sed 's/^[^:]*://g' <<<"${lista_series_completo_ordenado_sem_hora[*]}"))
IFS=$'\n' lista_series_completo_ordenado_sem_nada=($(sed -e 's/^\(.\{30\}\).*/\1/' <<<"${lista_series_completo_ordenado_sem_num[*]}"))

#printf "%s\n" "${lista_series_completo_ordenado[@]}"
for i in "${!lista_series_completo_ordenado[@]}"; do
    printf "%-4s%-4s %-32s %-20s %s\n" "$((i+1))" "${lista_numero_series_ordenado[$i]}" "${lista_series_completo_ordenado_sem_nada[$i]}"  "${lista_series_time[$i]}" "${lista_imgs_ordenado_sem_nada[$i]}"
done

printf "\nO que deseja fazer?\n"
PS3='Escolha uma opção: '
options=("Baixar tudo." "Baixar uma série." "Refazer pesquisa." "Encerrar.")
#ESSAS OPÇÕES PRECISAM SER IGUAIS ÁS DE BAIXO PRA FUNCIONAR DIREITO.
select opt in "${options[@]}"
do
    case $opt in
        "Baixar tudo.")
	while true; do
		read -p "Deseja importar para o XNAT?(sim/nao):" importopt
		case $importopt in
			sim )   xnatimport=1 ;
				read -p "Usuário do XNAT:" USER;
				read -s -p "Senha:" PASSWORD;
				read -p "Nome do projeto:" PROJECT;
				read -p "Subject:" SUBJECT;
			 	break;;
			nao ) xnatimport=0 ;break;;
			* ) echo "Por favor, entre com 'sim' ou 'nao'.";;
		esac
		done

        dicom_dir=dicom
        if [ -d "dicom" ]; then #ESSE IF SERVE PRA CRIAR DIFERENTES DIRETÓRIOS DICOM'S CASO JÁ EXISTAM
        num=1
        	if [ -d dicom$num ]; then
        		while [[ -d dicom$num ]] ; do
    				let num++
    				dicom_dir=dicom$num
				done
			else
				dicom_dir=dicom$num
			fi
		fi
		mkdir -p $dicom_dir
		for i in "${!lista_series_completo_ordenado[@]}"; do
			nome_serie=${lista_series_completo_ordenado_sem_nada[$i]}
			mkdir -p ${dicom_dir}/${nome_serie//[[:blank:]]/}_${dia}-${mes}-${ano}_${lista_series_time_sem_nada[$i]}
			movescu --log-config $LOG_CFG  -O -aec $AEC -aet $AET --port $AET_PORT \
			-od ${dicom_dir}/${nome_serie//[[:blank:]]/}_${dia}-${mes}-${ano}_${lista_series_time_sem_nada[$i]} \
			$PACS $PACS_PORT -k QueryRetrieveLevel=SERIES -k SeriesInstanceUID=${lista_uid_ordenado_sem_nada[$i]}
		done
		printf "\nDownload Completo\n"

		case $xnatimport in
			1 ) echo "Importando para o XNAT..."; bash export-xnat $USER $PASSWORD $PROJECT $SUBJECT $DIR;exit;;
			0 ) echo "Operação concluída.";exit;;
			* ) exit;;
		esac

            ;;
        "Baixar uma série.")
		echo -n "Número da série: "
		read numero_serie
		((numero_serie--))
		dicom_dir=dicom
        if [ -d "dicom" ]; then #ESSE IF SERVE PRA CRIAR DIFERENTES DIRETÓRIOS DICOM'S CASO JÁ EXISTAM
        num=1
        	if [ -d dicom$num ]; then
        		while [[ -d dicom$num ]] ; do
    				let num++
    				dicom_dir=dicom$num
				done
			else
				dicom_dir=dicom$num
			fi
		fi
		nome_serie=${lista_series_completo_ordenado_sem_nada[$numero_serie]}
		mkdir -p ${dicom_dir}/${nome_serie//[[:blank:]]/}_${dia}-${mes}-${ano}_${lista_series_time_sem_nada[$numero_serie]}
		movescu --log-config $LOG_CFG -O -aec $AEC -aet $AET --port $AET_PORT \
		-od ${dicom_dir}/${nome_serie//[[:blank:]]/}_${dia}-${mes}-${ano}_${lista_series_time_sem_nada[$numero_serie]} \
		$PACS $PACS_PORT -k QueryRetrieveLevel=SERIES -k SeriesInstanceUID=${lista_uid_ordenado_sem_nada[$numero_serie]}
            ;;
        "Refazer pesquisa.")
		bash dcmget.sh
            ;;
        "Encerrar.")
		rm dcmtk.log
		exit 0
            ;;
        *) echo Opção inválida;;
    esac
done
